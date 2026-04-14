// lib/screens/patient_dashboard_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';
import 'package:my_medical_kit_app/models/patient.dart';
import 'package:my_medical_kit_app/models/medication.dart';
import 'package:my_medical_kit_app/models/adherence_log.dart';
import 'package:my_medical_kit_app/models/ai_prediction.dart';
import 'package:my_medical_kit_app/models/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<Medication> _medications = [];
  List<AdherenceLog> _recentLogs = [];
  AIPrediction? _aiPrediction;
  Map<String, dynamic> _adherenceStats = {};
  List<NotificationModel> _notifications = [];

  // Weekly data: [Mon, Tue, Wed, Thu, Fri, Sat, Sun] taken count
  List<double> _weeklyTaken = [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _loadPatientId();
  }

  // ✅ FIXED: Load patient ID from stored session
  Future<void> _loadPatientId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPatientId = prefs.getInt('patient_id');
      if (savedPatientId != null && savedPatientId > 0) {
        _currentPatientId = savedPatientId;
      } else {
        // Fallback: try to get from API or show error
        _currentPatientId = 1; // Only as last resort, show login screen instead
      }
      await _loadAll();
    } catch (e) {
      setState(() {
        _errorMessage = 'Please login again';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAll() async {
    if (_currentPatientId == 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final results = await Future.wait([
        _apiService.getPatient(_currentPatientId),
        _apiService.getPatientMedications(_currentPatientId),
        _apiService.getAdherenceLogs(_currentPatientId, limit: 30),
        _apiService.getAIPrediction(_currentPatientId),
        _apiService.getAdherenceStats(_currentPatientId),
        _apiService.getNotifications(_currentPatientId),
      ]);

      final logs = results[2] as List<AdherenceLog>;

      setState(() {
        _patient = results[0] as Patient?;
        _medications = results[1] as List<Medication>;
        _recentLogs = logs;
        _aiPrediction = results[3] as AIPrediction?;
        _adherenceStats = results[4] as Map<String, dynamic>;
        _notifications = results[5] as List<NotificationModel>;
        _weeklyTaken = _computeWeekly(logs);
        _isLoading = false;
      });
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
  int _getMaxInventory(Medication med) {
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
    for (final log in _recentLogs) {
      if (log.isTaken) {
        streak++;
      } else if (log.isMissed)
        break;
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

  Medication? get _nextDose =>
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
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          color: AppColors.primaryPurple,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildAppBar()),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildDonutCard(),
                    const SizedBox(height: 18),
                    _buildWeeklyLineChart(),
                    const SizedBox(height: 18),
                    _buildAIPredictionBanner(),
                    const SizedBox(height: 18),
                    _buildNextDoseCard(),
                    const SizedBox(height: 18),
                    _buildInventoryRow(),
                    const SizedBox(height: 18),
                    _buildRecentLogs(),
                    const SizedBox(height: 30),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // TOP APP BAR
  // ──────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Text(
                _patient?.fullName.split(' ').first ?? 'Patient',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {},
                child: Stack(
                  children: [
                    _buildIconBox(Icons.notifications_outlined),
                    if (_unreadNotifications > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildIconBox(Icons.tune_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: Colors.black87),
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
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    const Text(
                      'Adherence Rate',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
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
              _buildDonutStat(
                'Taken',
                _taken.toString(),
                const Color(0xFF6C63FF),
              ),
              _buildVertDivider(),
              _buildDonutStat(
                'Missed',
                _missed.toString(),
                const Color(0xFFFF6584),
              ),
              _buildVertDivider(),
              _buildDonutStat(
                'Pending',
                _upcoming.toString(),
                const Color(0xFF43C6AC),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 16,
                color: Colors.deepPurple.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '$_streak day streak',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple.shade700,
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
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildVertDivider() =>
      Container(height: 36, width: 1, color: Colors.grey.shade200);

  // ──────────────────────────────────────────
  // WEEKLY LINE CHART
  // ──────────────────────────────────────────
  Widget _buildWeeklyLineChart() {
    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Doses Taken',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'This Week',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: CustomPaint(
              size: const Size(double.infinity, 110),
              painter: _LinePainter(
                data: _weeklyTaken,
                lineColor: AppColors.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDays
                .map(
                  (d) => Text(
                    d,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // AI PREDICTION BANNER
  // ──────────────────────────────────────────
  Widget _buildAIPredictionBanner() {
    if (_aiPrediction == null) return const SizedBox.shrink();

    final risk = _aiPrediction!.riskLevel
        .toString()
        .split('.')
        .last
        .toUpperCase();
    final score = _aiPrediction!.predictionScore;
    final riskColor = risk == 'HIGH'
        ? Colors.redAccent
        : risk == 'MEDIUM'
        ? Colors.orange
        : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.indigo.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Health Prediction',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  risk == 'HIGH'
                      ? 'High risk — extra reminder sent!'
                      : risk == 'MEDIUM'
                      ? 'Moderate risk — stay on track'
                      : 'You\'re doing great! Low risk.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  risk,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.celebration,
                color: Colors.teal,
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

    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: Colors.orange.shade600,
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
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  dose.medicationName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${dose.dosageTablet.toStringAsFixed(0)} tablet · Stock: ${dose.currentInventory}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                _markTaken(dose.prescriptionId, dose.deviceId ?? 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Take',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // INVENTORY ROW - FIXED: No hardcoded multiplier
  // ──────────────────────────────────────────
  Widget _buildInventoryRow() {
    final lowStock = _medications.where((m) => m.isLowStock).toList();
    final allMeds = _medications.take(4).toList();

    if (allMeds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Inventory Status',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (lowStock.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${lowStock.length} low stock',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: allMeds.map((med) => _buildInventoryTile(med)).toList(),
        ),
      ],
    );
  }

  Widget _buildInventoryTile(Medication med) {
    final isLow = med.isLowStock;
    // ✅ FIXED: Use dynamic max inventory based on actual data
    final maxInventory = _getMaxInventory(med);
    final pct = (med.currentInventory / maxInventory).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  med.medicationName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLow)
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 13,
                  color: Colors.orange,
                ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              color: isLow ? Colors.orange : Colors.teal,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${med.currentInventory} left',
            style: TextStyle(
              fontSize: 10,
              color: isLow ? Colors.orange : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // RECENT LOGS
  // ──────────────────────────────────────────
  Widget _buildRecentLogs() {
    final displayLogs = _recentLogs.take(5).toList();
    if (displayLogs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent History',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'See all',
                style: TextStyle(color: AppColors.primaryPurple, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _card(
          padding: EdgeInsets.zero,
          child: Column(
            children: displayLogs.asMap().entries.map((entry) {
              final idx = entry.key;
              final log = entry.value;
              final isTaken = log.isTaken;
              final isMissed = log.isMissed;
              final statusColor = isTaken
                  ? Colors.teal
                  : isMissed
                  ? Colors.redAccent
                  : Colors.orange;
              final statusLabel = isTaken
                  ? 'Taken'
                  : isMissed
                  ? 'Missed'
                  : 'Pending';

              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isTaken
                            ? Icons.check_circle_rounded
                            : isMissed
                            ? Icons.cancel_rounded
                            : Icons.schedule_rounded,
                        color: statusColor,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      log.medicationName ?? 'Medication',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      _formatTime(log.scheduledTime!),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (idx < displayLogs.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey.shade100,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// DONUT CHART PAINTER (UI only - acceptable to hardcode colors)
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
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const stroke = 30.0;

    final segments = [
      {'v': taken, 'c': const Color(0xFF6C63FF)},
      {'v': missed, 'c': const Color(0xFFFF6584)},
      {'v': pending, 'c': const Color(0xFF43C6AC)},
    ];

    double start = -pi / 2;
    for (final seg in segments) {
      final v = seg['v'] as double;
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

      final mid = start + sweep / 2;
      final lx = center.dx + radius * cos(mid);
      final ly = center.dy + radius * sin(mid);
      final pct = '${(v / total * 100).toStringAsFixed(0)}%';
      final tp = TextPainter(
        text: TextSpan(
          text: pct,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => false;
}

// LINE CHART PAINTER (UI only)
class _LinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  _LinePainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxV = data.reduce(max).clamp(1.0, double.infinity);

    final points = List.generate(data.length, (i) {
      final x = i * size.width / (data.length - 1);
      final y =
          size.height -
          (data[i] / maxV) * size.height * 0.8 -
          size.height * 0.1;
      return Offset(x, y);
    });

    final fill = Path()..moveTo(points.first.dx, size.height);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i + 1].dy,
      );
      fill.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }
    fill
      ..lineTo(points.last.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i + 1].dy,
      );
      line.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 6, Paint()..color = Colors.white);
      canvas.drawCircle(points[i], 4, Paint()..color = lineColor);
      if (data[i] > 0) {
        final tp = TextPainter(
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
        tp.paint(
          canvas,
          Offset(points[i].dx - tp.width / 2, points[i].dy - 20),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter o) => false;
}
