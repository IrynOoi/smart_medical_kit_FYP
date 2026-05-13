// lib/screens/patient_dashboard_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/screens/patient/smart_reminder_page.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';
import 'package:my_medical_kit_app/models/patient.dart';
import 'package:my_medical_kit_app/models/prescription.dart';
import 'package:my_medical_kit_app/models/adherence_log.dart';
import 'package:my_medical_kit_app/models/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class PatientDashboardPage extends StatefulWidget {
  const PatientDashboardPage({super.key});

  @override
  State<PatientDashboardPage> createState() => _PatientDashboardPageState();
}

class _PatientDashboardPageState extends State<PatientDashboardPage> {
  final ApiService _apiService = ApiService();

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

  @override
  void initState() {
    super.initState();
    _loadPatientId();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
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

  void _redirectToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _loadAll() async {
    if (_currentPatientId == 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    print('Caregiver name: ${_patient?.caregiver?.user.fullName}');
    try {
      final results = await Future.wait([
        _apiService.getPatient(_currentPatientId),
        _apiService.getPatientMedications(_currentPatientId),
        _apiService.getAdherenceLogs(_currentPatientId, limit: 30),
        _apiService.getAdherenceStats(_currentPatientId),
        _apiService.getNotifications(_currentPatientId),
      ]);

      final logs = results[2] as List<AdherenceLog>;

      setState(() {
        _patient = results[0] as Patient?;
        _medications = results[1] as List<Prescription>;
        _recentLogs = logs;
        _adherenceStats = results[3] as Map<String, dynamic>;
        _notifications = results[4] as List<NotificationModel>;
        _weeklyTaken = _computeWeekly(logs);
        _isLoading = false;
      });
      _updateChartPeriod(_selectedPeriod);
    } catch (e, stack) {
      debugPrint('❌ ERROR: $e');
      debugPrint('❌ STACK: $stack');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
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
    if (total == 0) return 100.0;
    return (_taken / total) * 100;
  }

  Prescription? get _nextDose =>
      _medications.where((m) => m.currentInventory > 0).isNotEmpty
      ? _medications.where((m) => m.currentInventory > 0).first
      : null;

  int get _unreadNotifications => _notifications.where((n) => !n.isRead).length;

  Future<void> _markTaken(int prescriptionId, int deviceId) async {
    final success = await _apiService.recordMedicationTaken(
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
      _loadAll();
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
                onPressed: _loadAll,
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
      backgroundColor: AppColors.premiumLight.withOpacity(0.1),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadAll,
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
            '${ApiService.baseUrl}${rawPhotoPath.startsWith('/') ? '' : '/'}$rawPhotoPath';
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
              // Reminder icon (PNG)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SmartReminderPage(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/icon/reminder.png',
                    // 🚀 FIXED: Scaled up to 40x40. This enlarges the icon
                    // and naturally makes the PNG's outlines look thicker on screen.
                    height: 40,
                    width: 40,
                    color: Colors.white,
                  ),
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
                      color: Colors.black.withOpacity(0.15),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
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
                color: AppColors.primaryPurple.withOpacity(0.1),
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
              color: AppColors.primaryPurple.withOpacity(0.1),
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
            '${ApiService.baseUrl}${rawPhotoPath.startsWith('/') ? '' : '/'}$rawPhotoPath';
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

  // ──────────────────────────────────────────
  // PRESCRIPTION SCHEDULE (assigned by caregiver)
  // ──────────────────────────────────────────
  Widget _buildScheduleCard(Prescription med) {
    final scheduleText = _parseCronSchedule(med.dispenseSchedule);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.premiumLight.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.premiumDark.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.schedule,
              color: AppColors.primaryPurple,
              size: 24,
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scheduleText,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                if (med.dosageTablet > 0)
                  Text(
                    'Dosage: ${med.dosageTablet.toStringAsFixed(0)} tablet(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Convert cron‑style schedule (e.g. "0 8 * * *") to human‑readable text.
  String _parseCronSchedule(String cron) {
    final parts = cron.split(' ');
    if (parts.length < 5) return cron;

    final minute = parts[0];
    final hourPart = parts[1];
    final dayOfMonth = parts[2];
    final month = parts[3];
    final dayOfWeek = parts[4];

    String timeStr = '';
    if (hourPart.contains(',')) {
      final hours = hourPart
          .split(',')
          .map((h) => '${h.padLeft(2, '0')}:${minute.padLeft(2, '0')}')
          .join(', ');
      timeStr = hours;
    } else {
      timeStr = '${hourPart.padLeft(2, '0')}:${minute.padLeft(2, '0')}';
    }

    if (dayOfMonth == '*' && month == '*' && dayOfWeek == '*') {
      if (hourPart.contains(',')) {
        return 'Daily at $timeStr';
      } else {
        return 'Daily at $timeStr';
      }
    } else if (dayOfMonth == '*' && month == '*' && dayOfWeek != '*') {
      final days = dayOfWeek.split(',');
      final dayNames = {
        '0': 'Sun',
        '1': 'Mon',
        '2': 'Tue',
        '3': 'Wed',
        '4': 'Thu',
        '5': 'Fri',
        '6': 'Sat',
        '7': 'Sun',
      };
      final readableDays = days.map((d) => dayNames[d] ?? d).join(', ');
      return '$readableDays at $timeStr';
    }

    return cron;
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.premiumLight.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.premiumDark.withOpacity(0.06),
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
          ..color = AppColors.primaryPurple.withOpacity(0.5)
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
            colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0.0)],
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
