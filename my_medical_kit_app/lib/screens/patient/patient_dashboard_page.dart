// lib/screens/patient_dashboard_page.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:my_medical_kit_app/services/api/api_client.dart';

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_medical_kit_app/services/api/device_service.dart';
import 'package:my_medical_kit_app/screens/patient/smart_reminder_page.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';
import 'package:my_medical_kit_app/services/reminder_service.dart';
import 'package:my_medical_kit_app/models/patient.dart';
import 'package:my_medical_kit_app/models/prescription.dart';
import 'package:my_medical_kit_app/models/adherence_log.dart';
import 'package:my_medical_kit_app/models/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientDashboardPage extends StatefulWidget {
  const PatientDashboardPage({super.key});

  @override
  State<PatientDashboardPage> createState() => _PatientDashboardPageState();
}

class _PatientDashboardPageState extends State<PatientDashboardPage>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _isPaused = false;
  // ✅ FIXED: Get patient ID from shared preferences (login session)
  int _currentPatientId = 0;

  bool _isLoading = true;
  String _errorMessage = '';

  // Data from PostgreSQL
  Patient? _patient;
  List<Prescription> _medications = [];
  List<AdherenceLog> _recentLogs = [];
  Map<String, dynamic> _adherenceStats = {};
  List<NotificationModel> _notifications = [];

  // Weekly data: [Mon, Tue, Wed, Thu, Fri, Sat, Sun] taken count
  List<double> _weeklyTaken = [0, 0, 0, 0, 0, 0, 0];

  // Dynamic Graph State
  String _selectedPeriod = 'Week'; // Options: 'Day', 'Week', 'Month'
  List<double> _graphData = [0, 0, 0, 0, 0, 0, 0];
  List<String> _graphLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<AdherenceLog> get _missedLogs {
    final now = DateTime.now();
    return _recentLogs.where((log) {
      // Must be MISSED and have a scheduled time
      if (log.status != 'MISSED' || log.scheduledTime == null) return false;
      // Only allow retake within 30 minutes after scheduled time
      final minutesSinceScheduled = now
          .difference(log.scheduledTime!)
          .inMinutes;
      if (minutesSinceScheduled > 30) return false;

      // Do not allow retake if out of stock
      try {
        final med = _medications.firstWhere(
          (m) => m.prescriptionId == log.prescriptionId,
        );
        if (med.currentInventory <= 0) return false;
      } catch (e) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPatientId();
    _requestNotificationPermission();
    _startPeriodicRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh immediately when coming back
      _loadAll(showLoading: false);
      // Restart timer if it was stopped
      _startPeriodicRefresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isLoading && _currentPatientId != 0) {
        _loadAll(showLoading: false);
      }
    });
  }

  Future<void> _requestNotificationPermission() async {
    await ReminderService.requestNotificationPermissions();
  }

  String _formatFullTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hr12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hr12:$m $ampm';
  }

  // ✅ FIXED: Load patient ID from stored session
  Future<void> _loadPatientId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPatientId = prefs.getInt('patient_id');
      if (savedPatientId != null && savedPatientId > 0) {
        _currentPatientId = savedPatientId;
        await _loadAll();
      } else {
        // No valid session – go to login
        _redirectToLogin();
      }
    } catch (e) {
      _redirectToLogin();
    }
  }

  // Future<void> _retakeDose(AdherenceLog log) async {
  //   final success = await PatientService().retakeMissedDose(log.logId);
  //   if (!mounted) return;
  //   if (success) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('✅ Dose recorded as taken!'),
  //         backgroundColor: Colors.green,
  //       ),
  //     );
  //     await _loadAll(); // refresh dashboard
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('❌ Failed to retake. Please try again.'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  Widget _buildMissedDosesSection() {
    final missed = _missedLogs;
    if (missed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Missed Doses – You can still take them',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...missed.map((log) => _buildMissedDoseCard(log)),
      ],
    );
  }

  Widget _buildMissedDoseCard(AdherenceLog log) {
    final timeStr = log.scheduledTime != null
        ? '${log.scheduledTime!.hour.toString().padLeft(2, '0')}:${log.scheduledTime!.minute.toString().padLeft(2, '0')}'
        : 'Unknown time';
    final medicationName = log.medicationName ?? 'Unknown medication';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicationName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Scheduled at $timeStr',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _retakeDose(log),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retake'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateChartPeriod(String period) {
    setState(() {
      _selectedPeriod = period;
      final now = DateTime.now();
      Map<String, double> groupedData = {};

      if (period == 'Day') {
        final todaysLogs = _recentLogs.where((log) {
          if (log.scheduledTime == null) return false;
          return log.scheduledTime!.day == now.day &&
              log.scheduledTime!.month == now.month &&
              log.scheduledTime!.year == now.year;
        }).toList();

        todaysLogs.sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

        if (todaysLogs.isEmpty) {
          groupedData = {'8am': 0.0, '12pm': 0.0, '4pm': 0.0, '8pm': 0.0};
        } else {
          for (var log in todaysLogs) {
            String timeLabel = _formatFullTime(log.scheduledTime!);
            groupedData.putIfAbsent(timeLabel, () => 0.0);
            if (log.isTaken) {
              groupedData[timeLabel] = groupedData[timeLabel]! + 1.0;
            }
          }
          if (groupedData.length == 1) {
            String onlyKey = groupedData.keys.first;
            double val = groupedData[onlyKey]!;
            groupedData = {'12am': 0.0, onlyKey: val, '11pm': 0.0};
          }
        }
      } else if (period == 'Week') {
        const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        for (int i = 6; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          groupedData[weekDays[day.weekday - 1]] = 0.0;
        }
        final weekLogs = _recentLogs.where((log) {
          if (log.scheduledTime == null) return false;
          return now.difference(log.scheduledTime!).inDays < 7;
        });
        for (var log in weekLogs) {
          if (log.isTaken) {
            String dayLabel = weekDays[log.scheduledTime!.weekday - 1];
            if (groupedData.containsKey(dayLabel)) {
              groupedData[dayLabel] = groupedData[dayLabel]! + 1.0;
            }
          }
        }
      } else if (period == 'Month') {
        groupedData = {'Wk 1': 0.0, 'Wk 2': 0.0, 'Wk 3': 0.0, 'Wk 4': 0.0};
        final monthLogs = _recentLogs.where((log) {
          if (log.scheduledTime == null) return false;
          return now.difference(log.scheduledTime!).inDays < 28;
        });
        for (var log in monthLogs) {
          if (log.isTaken) {
            int daysAgo = now.difference(log.scheduledTime!).inDays;
            if (daysAgo < 7) {
              groupedData['Wk 4'] = groupedData['Wk 4']! + 1.0;
            } else if (daysAgo < 14)
              groupedData['Wk 3'] = groupedData['Wk 3']! + 1.0;
            else if (daysAgo < 21)
              groupedData['Wk 2'] = groupedData['Wk 2']! + 1.0;
            else if (daysAgo < 28)
              groupedData['Wk 1'] = groupedData['Wk 1']! + 1.0;
          }
        }
      }

      _graphLabels = groupedData.keys.toList();
      _graphData = groupedData.values.toList();
    });
  }

  // ──────────────────────────────────────────
  // IN-APP NOTIFICATION BOTTOM SHEET
  // ──────────────────────────────────────────
  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          height: MediaQuery.of(sheetContext).size.height * 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const Divider(height: 30),
              // Inside _showNotificationsSheet, replace the existing Expanded child with:
              Expanded(
                child: _notifications.where((n) => !n.isRead).isEmpty
                    ? Center(
                        child: Text(
                          'No unread notifications.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _notifications
                            .where((n) => !n.isRead)
                            .length,
                        itemBuilder: (context, index) {
                          final notif = _notifications
                              .where((n) => !n.isRead)
                              .toList()[index];
                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: AppColors.primaryPurple.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryPurple,
                                child: Icon(
                                  Icons.medication_liquid_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                notif.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(notif.message),
                              ),
                              onTap: () async {
                                final success = await PatientService()
                                    .markNotificationRead(notif.notificationId);
                                if (!mounted) return;
                                if (success) {
                                  await _loadAll(
                                    showLoading: false,
                                  ); // refresh dashboard data
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext); // close sheet
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _redirectToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _loadAll({bool showLoading = true}) async {
    if (_currentPatientId == 0) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }
    print('Caregiver name: ${_patient?.caregiver?.user.fullName}');
    try {
      final results = await Future.wait([
        PatientService().getPatient(_currentPatientId),
        MedicationService().getPatientMedications(_currentPatientId),
        PatientService().getAdherenceLogs(_currentPatientId, limit: 30),
        PatientService().getAdherenceStats(_currentPatientId),
        PatientService().getNotifications(_currentPatientId),
      ]);

      final meds = results[1] as List<Prescription>;
      final logs = results[2] as List<AdherenceLog>;
      var notifications = results[4] as List<NotificationModel>;

      try {
        await ReminderService.checkAndSendReminders(medications: meds);
        notifications = await PatientService().getNotifications(
          _currentPatientId,
        );
      } catch (reminderError) {
        debugPrint('Reminder notification sync skipped: $reminderError');
      }

      setState(() {
        _patient = results[0] as Patient?;
        _medications = meds;
        _recentLogs = logs;
        _adherenceStats = results[3] as Map<String, dynamic>;
        _notifications = notifications;
        _weeklyTaken = _computeWeekly(logs);
        if (showLoading) _isLoading = false;
      });
      _updateChartPeriod(_selectedPeriod);
      try {
        await ReminderService.scheduleUpcomingMedicationReminders(
          _currentPatientId,
          medications: meds,
        );
      } catch (scheduleError) {
        debugPrint('Reminder scheduling skipped: $scheduleError');
      }
    } catch (e, stack) {
      debugPrint('❌ ERROR: $e');
      debugPrint('❌ STACK: $stack');
      setState(() {
        _errorMessage = 'Error: $e';
        if (showLoading) _isLoading = false;
      });
    }
  }

  // ✅ FIXED: Compute max inventory from actual data, not hardcoded multiplier
  int _getMaxInventory(Prescription med) {
    // Use refill_threshold * 2 as max, or fallback to current inventory if higher
    final calculatedMax = med.refillThreshold * 2;
    if (med.currentInventory > calculatedMax) {
      return med.currentInventory;
    }
    return calculatedMax;
  }

  // Compute weekly taken count from adherence_logs.scheduled_time
  List<double> _computeWeekly(List<AdherenceLog> logs) {
    final counts = List<double>.filled(7, 0);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    for (final log in logs) {
      if (!log.isTaken) continue;
      final scheduledTime = log.scheduledTime;
      if (scheduledTime == null) continue;
      final diff = scheduledTime.difference(
        DateTime(weekStart.year, weekStart.month, weekStart.day),
      );
      if (diff.inDays >= 0 && diff.inDays < 7) {
        counts[diff.inDays] += 1;
      }
    }
    return counts;
  }

  int get _streak {
    int streak = 0;
    final now = DateTime.now();

    for (final log in _recentLogs) {
      if (log.isTaken) {
        streak++;
      } else if (log.isMissed) {
        break;
      } else if (log.status == 'PENDING' && log.scheduledTime != null) {
        // If it's a pending dose from the past, the streak is broken
        if (log.scheduledTime!.isBefore(now)) {
          break;
        }
        // If it's a pending dose for the future (e.g., tonight), just ignore it and keep going
      }
    }
    return streak;
  }

  int get _taken => _adherenceStats['taken_count'] ?? 0;
  int get _missed => _adherenceStats['missed_count'] ?? 0;
  int get _upcoming => _adherenceStats['upcoming_count'] ?? 0;

  double get _adherenceScore {
    final total = _taken + _missed;
    if (total == 0) return 0.0;
    return (_taken / total) * 100;
  }

  Prescription? get _nextDose =>
      _medications.where((m) => m.currentInventory > 0).isNotEmpty
      ? _medications.where((m) => m.currentInventory > 0).first
      : null;

  int get _unreadNotifications => _notifications.where((n) => !n.isRead).length;

  Future<void> _markTaken(int prescriptionId, int deviceId) async {
    final success = await MedicationService().recordMedicationTaken(
      prescriptionId,
      deviceId,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Dose recorded successfully!'),
          backgroundColor: Colors.teal,
        ),
      );
      _loadAll(showLoading: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to record. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPatientId == 0) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.login, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Please login to continue'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Navigate to login page
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                ),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadAll(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.premiumLight.withValues(alpha: 0.1),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _loadAll(showLoading: false),
          color: AppColors.primaryPurple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildDonutCard(),
                      const SizedBox(height: 18),
                      _buildAdherenceChart(),
                      const SizedBox(height: 18),
                      _buildCaregiverCard(),
                      const SizedBox(height: 18),
                      _buildMissedDosesSection(),
                      const SizedBox(height: 30),
                      _buildPrescriptionsList(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _formattedDate {
    final now = DateTime.now();
    return '${now.day} ${_getMonthName(now.month)} ${now.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  // ──────────────────────────────────────────
  // TOP APP BAR (HEADER)
  // ──────────────────────────────────────────
  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    final patientName = _patient?.user.fullName ?? 'Patient';

    // Build profile photo URL from patient data
    final String? rawPhotoPath = _patient?.user.profilePhoto;
    String? fullPhotoUrl;
    if (rawPhotoPath != null && rawPhotoPath.isNotEmpty) {
      if (rawPhotoPath.startsWith('http')) {
        fullPhotoUrl = rawPhotoPath;
      } else {
        fullPhotoUrl =
            '${ApiClient.baseUrl}${rawPhotoPath.startsWith('/') ? '' : '/'}$rawPhotoPath';
      }
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding + 16, 24, 32),
      decoration: const BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo + MedSmart text
              const Text(
                'MedSmart',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),

              // 🔔 TOP RIGHT: Bell Icon ONLY (Navigates to SmartReminderPage)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SmartReminderPage(),
                    ),
                  ).then((_) => _loadAll(showLoading: false));
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    if (_unreadNotifications > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_unreadNotifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      letterSpacing: 1.5,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryPurple,
                  backgroundImage: fullPhotoUrl != null
                      ? NetworkImage(fullPhotoUrl)
                      : null,
                  child: fullPhotoUrl == null
                      ? const Icon(Icons.person_rounded, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Today's Date Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _formattedDate,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // DONUT CHART CARD
  // ──────────────────────────────────────────
  Widget _buildDonutCard() {
    final scoreColor = _adherenceScore >= 75
        ? Colors.green
        : _adherenceScore >= 50
        ? Colors.orange
        : Colors.redAccent;

    return _card(
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(190, 190),
                  painter: _DonutPainter(
                    taken: _taken.toDouble(),
                    missed: _missed.toDouble(),
                    pending: _upcoming.toDouble(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_adherenceScore.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    const Text(
                      'Adherence Rate',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDonutStat('Taken', _taken.toString(), Colors.green),
              _buildVertDivider(),

              _buildDonutStat('Pending', _upcoming.toString(), Colors.orange),
              _buildVertDivider(),
              _buildDonutStat('Missed', _missed.toString(), Colors.red),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 16,
                color: AppColors.premiumDark,
              ),
              const SizedBox(width: 4),
              Text(
                '$_streak dose streak',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.premiumDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: color, // ✅ now uses the same color as the value
          ),
        ),
      ],
    );
  }

  Widget _buildVertDivider() =>
      Container(height: 36, width: 1, color: Colors.grey.shade200);

  // ──────────────────────────────────────────
  // WEEKLY LINE CHART
  // ──────────────────────────────────────────
  Widget _buildAdherenceChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Adherence Trends',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: ['Day', 'Week', 'Month'].map((period) {
                  final isSelected = _selectedPeriod == period;
                  return GestureDetector(
                    onTap: () => _updateChartPeriod(period),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryPurple
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        period,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 110,
                child: CustomPaint(
                  size: const Size(double.infinity, 110),
                  painter: _LinePainter(
                    data: _graphData.isEmpty ? [0] : _graphData,
                    lineColor: AppColors.primaryPurple,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: _graphLabels.length == 1
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                children: _graphLabels
                    .map(
                      (d) => Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  // NEXT DOSE CARD
  // ──────────────────────────────────────────
  Widget _buildNextDoseCard() {
    final dose = _nextDose;
    if (dose == null) {
      return _card(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.celebration,
                color: AppColors.primaryPurple,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'All caught up! 🎉 No pending doses.',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final deviceId = dose.deviceId;
    final canTake = deviceId != null && deviceId > 0;

    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: AppColors.primaryPurple,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Dose',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                Text(
                  dose.medicationName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${dose.dosageTablet.toStringAsFixed(0)} tablet · Stock: ${dose.currentInventory}',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (canTake)
            ElevatedButton(
              onPressed: () => _markTaken(dose.prescriptionId, deviceId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Take',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No device',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCaregiverCard() {
    final caregiver = _patient?.caregiver;
    if (caregiver == null) return const SizedBox.shrink();

    final name = caregiver.user.fullName;
    final phone = caregiver.user.phoneNo ?? 'N/A';
    final email = caregiver.user.email;

    final String? rawPhotoPath = caregiver.user.profilePhoto;
    String? fullPhotoUrl;
    if (rawPhotoPath != null && rawPhotoPath.isNotEmpty) {
      if (rawPhotoPath.startsWith('http')) {
        fullPhotoUrl = rawPhotoPath;
      } else {
        fullPhotoUrl =
            '${ApiClient.baseUrl}${rawPhotoPath.startsWith('/') ? '' : '/'}$rawPhotoPath';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Caregiver',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        _card(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.teal.shade50,
                backgroundImage: fullPhotoUrl != null
                    ? NetworkImage(fullPhotoUrl)
                    : null,
                child: fullPhotoUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.email, size: 14, color: Colors.teal),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionsList() {
    if (_medications.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text(
          'My Prescriptions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        ..._medications.map((med) => _buildScheduleCard(med)),
      ],
    );
  }

  // ──────────────────────────────────────────
  // PRESCRIPTION SCHEDULE (assigned by caregiver)
  // ──────────────────────────────────────────
  Widget _buildScheduleCard(Prescription med) {
    final scheduleText = _formatDispenseTimes(med.dispenseTimes);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.primaryPurple, width: 6),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryPurple.withValues(alpha: 0.15),
                      AppColors.primaryPurple.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.medication_liquid_rounded,
                  color: AppColors.primaryPurple,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.medicationName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: AppColors.primaryPurple,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            scheduleText,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (med.dosageTablet > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.medical_information_outlined,
                            size: 15,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Dosage: ${med.dosageTablet.toStringAsFixed(0)} tablet(s)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retakeDose(AdherenceLog log) async {
    // 1. Ask backend if retake is still allowed (30‑minute window)
    final doseData = await PatientService().triggerRetake(log.logId);
    if (doseData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retake no longer allowed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Get the device IP for the device_id
    final deviceId = doseData['device_id'];
    if (deviceId == null || deviceId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No device assigned'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final deviceIp = await DeviceService.getDeviceIp(deviceId);
    if (deviceIp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device offline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 3. Send command to ESP32 to start beeping & wait for touch
    final url =
        'http://$deviceIp/retake?adlog_id=${log.logId}&prescription_id=${doseData['prescription_id']}&slot=${doseData['motor_slot']}&med_name=${Uri.encodeComponent(doseData['medication_name'])}';
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please touch the device button within 10 seconds'),
            backgroundColor: Colors.teal,
          ),
        );
        // Refresh after a delay to reflect possible status change
        Future.delayed(const Duration(seconds: 12), () => _loadAll());
      } else {
        throw Exception('Device rejected');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not reach device'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDispenseTimes(List<String> times) {
    if (times.isEmpty) return 'No schedule';
    final formattedTimes = times.map((t) {
      final parts = t.split(':');
      if (parts.length >= 2) {
        int h = int.tryParse(parts[0]) ?? 8;
        int m = int.tryParse(parts[1]) ?? 0;
        final amPm = h >= 12 ? 'PM' : 'AM';
        int displayHour = h % 12;
        if (displayHour == 0) displayHour = 12;
        final displayMinute = m.toString().padLeft(2, '0');
        return '$displayHour:$displayMinute $amPm';
      }
      return t;
    }).toList();
    return 'Daily at ${formattedTimes.join(', ')}';
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.premiumLight.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.premiumDark.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning 🌤️';
    if (h < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌙';
  }
}

// DONUT CHART PAINTER
class _DonutPainter extends CustomPainter {
  final double taken, missed, pending;
  _DonutPainter({
    required this.taken,
    required this.missed,
    required this.pending,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = taken + missed + pending;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const stroke = 30.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * pi,
      false,
      Paint()
        ..color = Colors.grey.shade100
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (total == 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        0,
        2 * pi,
        false,
        Paint()
          ..color = Colors
              .grey // Change this from AppColors.primaryPurple... to Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final segments = [
      {'v': taken, 'c': Colors.green}, // taken → green
      {'v': missed, 'c': Colors.red}, // missed → red
      {'v': pending, 'c': Colors.orange}, // pending → orange
    ];
    double start = -pi / 2;
    for (final seg in segments) {
      final v = seg['v'] as double;

      if (v == 0) continue;

      final c = seg['c'] as Color;
      final sweep = (v / total) * 2 * pi;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + 0.05,
        sweep - 0.10,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => false;
}

// LINE CHART PAINTER
class _LinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;

  _LinePainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final maxV = maxValue > 0 ? maxValue : 1.0;

    final points = List.generate(data.length, (i) {
      final x = data.length == 1
          ? size.width / 2
          : i * size.width / (data.length - 1);
      final y =
          size.height -
          (data[i] / maxV) * size.height * 0.8 -
          size.height * 0.1;
      return Offset(x, y);
    });

    if (data.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, size.height);
      for (int i = 0; i < points.length - 1; i++) {
        final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
        final cp2 = Offset(
          (points[i].dx + points[i + 1].dx) / 2,
          points[i + 1].dy,
        );
        fillPath.cubicTo(
          cp1.dx,
          cp1.dy,
          cp2.dx,
          cp2.dy,
          points[i + 1].dx,
          points[i + 1].dy,
        );
      }
      fillPath
        ..lineTo(points.last.dx, size.height)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: 0.25),
              lineColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );

      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 0; i < points.length - 1; i++) {
        final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
        final cp2 = Offset(
          (points[i].dx + points[i + 1].dx) / 2,
          points[i + 1].dy,
        );
        linePath.cubicTo(
          cp1.dx,
          cp1.dy,
          cp2.dx,
          cp2.dy,
          points[i + 1].dx,
          points[i + 1].dy,
        );
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 6, Paint()..color = Colors.white);
      canvas.drawCircle(points[i], 4, Paint()..color = lineColor);

      if (data[i] > 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: data[i].toInt().toString(),
            style: TextStyle(
              fontSize: 10,
              color: lineColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(points[i].dx - textPainter.width / 2, points[i].dy - 20),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) => true;
}
