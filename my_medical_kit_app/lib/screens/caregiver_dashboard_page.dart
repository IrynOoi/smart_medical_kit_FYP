// lib/screens/caregiver_dashboard_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaregiverDashboardPage extends StatefulWidget {
  const CaregiverDashboardPage({super.key});

  @override
  State<CaregiverDashboardPage> createState() => _CaregiverDashboardPageState();
}

class _CaregiverDashboardPageState extends State<CaregiverDashboardPage> {
  final ApiService _apiService = ApiService();

  int _caregiverId = 0;
  String _caregiverName = '';

  String _selectedPeriod = 'Week';

  bool _isLoading = true;
  String _errorMessage = '';

  Map<String, dynamic> _overviewStats = {};
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _recentActivities = [];
  List<double> _chartData = [0, 0, 0, 0, 0, 0, 0];
  List<String> _chartLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _fetchChartData(String period) async {
    setState(() => _selectedPeriod = period);
    try {
      final data = await _apiService.getChartData(_caregiverId, period);
      setState(() {
        _chartData = data['taken'] ?? []; // 🌟 只取 'taken' 的數據來畫圖表

        if (period == 'Day') {
          _chartLabels = ['12AM', '4AM', '8AM', '12PM', '4PM', '8PM'];
        } else if (period == 'Month') {
          _chartLabels = ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];
        } else {
          _chartLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        }
      });
    } catch (e) {
      debugPrint('Chart error: $e');
    }
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt('caregiver_id');
      if (savedId == null || savedId == 0) {
        setState(() {
          _errorMessage = 'Please login to continue';
          _isLoading = false;
        });
        return;
      }
      _caregiverId = savedId;
      _caregiverName = prefs.getString('user_name') ?? 'Caregiver';
      await _loadDashboardData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Session error. Please login again.';
        _isLoading = false;
      });
      await _fetchChartData('Week');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final results = await Future.wait([
        _apiService.getCaregiverOverview(_caregiverId),
        _apiService.getCaregiverPatients(_caregiverId),
        _apiService.getCaregiverAlerts(_caregiverId),
      ]);
      final overview = results[0] as Map<String, dynamic>;
      final patients = results[1] as List<Map<String, dynamic>>;
      final alerts = results[2] as List<Map<String, dynamic>>;
      await _fetchChartData('Week');
      setState(() {
        _overviewStats = overview;
        _patients = patients;
        _recentActivities = alerts.take(5).toList();
        _isLoading = false;
      });
    } catch (e, s) {
      debugPrint('❌ $e\n$s');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Derived stats from PostgreSQL
  // ──────────────────────────────────────────────────────────────
  int get _totalPatients => _overviewStats['total_patients'] ?? 0;
  int get _totalDoses => _overviewStats['total_doses'] ?? 0;
  int get _totalPrescriptions => _overviewStats['total_prescriptions'] ?? 0;
  int get _devicesOnline => _patients.length;

  // 👇 RESTORED: This line was missing! 👇
  int get _adherenceRate => _overviewStats['adherence_score']?.toInt() ?? 0;

  int get _pendingAlerts => _overviewStats['pending_count'] ?? 0;
  int get _missedDoses => _overviewStats['missed_count'] ?? 0;
  int get _lowStockCount => _overviewStats['low_stock_count'] ?? 0;
  int get _lowBatteryCount => _patients.where((p) {
    final b = p['battery_level'];
    return b != null && (b as int) < 20;
  }).length;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
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

  // ──────────────────────────────────────────────────────────────
  //  Navigation helpers
  // ──────────────────────────────────────────────────────────────
  void _navigateToPatientsList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PatientsListPage(caregiverId: _caregiverId),
      ),
    );
  }

  void _navigateToDevicesList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DevicesListPage(caregiverId: _caregiverId),
      ),
    );
  }

  void _navigateToAdherenceDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdherenceDetailsPage(caregiverId: _caregiverId),
      ),
    );
  }

  void _navigateToDosesDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DosesDetailsPage(caregiverId: _caregiverId),
      ),
    );
  }

  void _navigateToAlertsDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AlertsDetailsPage(caregiverId: _caregiverId),
      ),
    );
  }

  void _navigateToPerformanceDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PerformanceDetailsPage(
          caregiverId: _caregiverId,
          chartData: _chartData,
          chartLabels: _chartLabels,
          period: _selectedPeriod,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  Build
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDashboardData,
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
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: AppColors.primaryPurple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildWelcomeCard(),
                const SizedBox(height: 16),
                _buildStatsGrid(),
                const SizedBox(height: 16),
                _buildChartSection(),
                const SizedBox(height: 16),
                _buildRecentActivities(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HEADER
  // ==========================================
  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding + 16, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.primaryPurple,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.medical_information_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'MedSmart',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
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
                    _greeting.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      letterSpacing: 1.5,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _caregiverName,
                    style: const TextStyle(
                      fontSize: 30,
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
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Text(
                    _caregiverName.isNotEmpty
                        ? _caregiverName[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryPurple,
                    ),
                  ),
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
                    fontSize: 13,
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

  Widget _buildWelcomeCard() {
    /* unchanged */
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CAREGIVER DASHBOARD',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Medical Adherence Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_totalPatients Assigned Patients',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.mainGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STATS GRID with onTap navigation
  // ==========================================
  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total Patients',
                  value: _totalPatients.toString(),
                  subtitle: 'Assigned',
                  icon: Icons.people_rounded,
                  color: AppColors.primaryPurple,
                  onTap: _navigateToPatientsList,
                ),
              ),
              const SizedBox(width: 14),
              // 🌟 UPDATED: Now shows the Number of Prescriptions
              Expanded(
                child: _buildStatCard(
                  title: 'Prescriptions',
                  value: _totalPrescriptions
                      .toString(), // Shows the actual number
                  subtitle: 'Tap to manage', // Hint that they can tap it
                  icon: Icons.post_add_rounded,
                  color: const Color(0xFF4CAF82),
                  onTap: _navigateToPrescriptionSetup,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Devices Online',
                  value: _devicesOnline.toString(),
                  subtitle: 'Smart Kits',
                  icon: Icons.router_rounded,
                  color: const Color(0xFF5B8DEF),
                  onTap: _navigateToDevicesList,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatCard(
                  title: 'Avg Adherence',
                  value: '$_adherenceRate%',
                  subtitle: 'Overall',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFFF5A623),
                  onTap: _navigateToAdherenceDetails,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 👇 ADD THIS NEW HELPER FUNCTION IF YOU HAVEN'T ALREADY 👇
  void _navigateToPrescriptionSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CaregiverPrescriptionSetupPage(caregiverId: _caregiverId),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. CHART SECTION (IMPROVISED VERSION - NO OVERFLOW)
  // ==========================================
  // ==========================================
  // 4. CHART SECTION (Redesigned matching reference image)
  // ==========================================
  Widget _buildChartSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Toggles Outside the Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: ['Month', 'Week', 'Day'].map((period) {
                    final isSelected = _selectedPeriod == period;
                    return GestureDetector(
                      onTap: () => _fetchChartData(period),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          period,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.primaryPurple
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

          // The Clickable Chart Card
          GestureDetector(
            onTap: _navigateToPerformanceDetails, // 🌟 Click to view details!
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: CustomPaint(
                  // 🌟 Draws the smooth curve based on real PostgreSQL data!
                  painter: _CurvedChartPainter(
                    data: _chartData,
                    labels: _chartLabels,
                    lineColor: AppColors.primaryPurple,
                    selectedIndex: _selectedPeriod == 'Week'
                        ? (DateTime.now().weekday - 1)
                        : _chartData.length - 1, // Highlights today or latest
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Summary Stats moved below the card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryStat(
                'Pending',
                _pendingAlerts.toString(),
                Colors.orange,
              ),
              _buildSummaryStat(
                'Missed',
                _missedDoses.toString(),
                Colors.redAccent,
              ),
              _buildSummaryStat(
                'Stock',
                _lowStockCount.toString(),
                Colors.orange,
              ),
              _buildSummaryStat(
                'Battery',
                _lowBatteryCount.toString(),
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRecentActivities() {
    /* unchanged */
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Alerts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              TextButton(
                onPressed:
                    _navigateToAlertsDetails, // ✅ FIX: Add the navigation function here
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primaryPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'All good! No recent alerts 🎉',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            )
          else
            ..._recentActivities.map(
              (activity) => _buildActivityItem(activity),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    /* unchanged */
    final isMissed = activity['status'] == 'MISSED';
    final color = isMissed ? Colors.redAccent : Colors.orange;
    final icon = isMissed ? Icons.close_rounded : Icons.access_time_rounded;
    final statusText = isMissed ? 'Missed' : 'Pending';
    DateTime? dt;
    try {
      dt = DateTime.parse(activity['scheduled_time'] as String);
    } catch (_) {}
    String timeText = '';
    if (dt != null) {
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        timeText =
            'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        timeText = 'Yesterday';
      } else {
        timeText = '${dt.day}/${dt.month}';
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['patient_name'] ?? 'Patient',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${activity['medication_name'] ?? 'Medication'} • $statusText',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            timeText,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🌟 Alerts Details Page – Fetches full alert history
// ==========================================
class _AlertsDetailsPage extends StatefulWidget {
  final int caregiverId;
  const _AlertsDetailsPage({required this.caregiverId});

  @override
  State<_AlertsDetailsPage> createState() => _AlertsDetailsPageState();
}

class _AlertsDetailsPageState extends State<_AlertsDetailsPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      // 這裡的 API 現在會支援回傳更多警告（透過後端設定 limit=50）
      final data = await _apiService.getCaregiverAlerts(widget.caregiverId);
      setState(() {
        _alerts = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(String? dtString) {
    if (dtString == null) return '';
    try {
      final dt = DateTime.parse(dtString).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dtString.length > 16 ? dtString.substring(0, 16) : dtString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recent Alerts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F6FB),
      body: RefreshIndicator(
        onRefresh: _fetchAlerts,
        color: AppColors.primaryPurple,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchAlerts,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _alerts.isEmpty
            ? const Center(
                child: Text(
                  'All Good! No recent alerts 🎉',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _alerts.length,
                itemBuilder: (_, i) {
                  final act = _alerts[i];
                  final isMissed = act['status'] == 'MISSED';
                  final iconColor = isMissed ? Colors.redAccent : Colors.orange;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isMissed
                              ? Icons.cancel_rounded
                              : Icons.access_time_rounded,
                          color: iconColor,
                        ),
                      ),
                      title: Text(
                        act['patient_name'] ?? 'Unknown Patient',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '${act['medication_name'] ?? 'Medication'} • ${act['status']}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      trailing: Text(
                        _formatDateTime(act['scheduled_time']),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ==========================================
// Patient Detail Page – Full personal info
// ==========================================
class PatientDetailPage extends StatelessWidget {
  final Map<String, dynamic> patient;

  const PatientDetailPage({super.key, required this.patient});

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Not provided';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(patient['full_name'] ?? 'Patient Details'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F6FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Personal Information Card
            _buildInfoCard(
              title: 'Personal Information',
              icon: Icons.person,
              children: [
                _infoRow('Full Name', patient['full_name'] ?? '—'),
                _infoRow('Email', patient['email'] ?? '—'),
                _infoRow('Phone', patient['phone_no'] ?? '—'),
                _infoRow('Address', patient['address'] ?? '—'),
                _infoRow('Gender', patient['gender'] ?? '—'),
                _infoRow(
                  'Date of Birth',
                  _formatDate(patient['date_of_birth']),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Medical Information Card
            _buildInfoCard(
              title: 'Medical Information',
              icon: Icons.health_and_safety,
              children: [
                _infoRow(
                  'Medical Notes',
                  patient['medical_notes'] ?? 'No notes',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Device Information Card
            _buildInfoCard(
              title: 'Device Information',
              icon: Icons.devices,
              children: [
                _infoRow(
                  'Device Serial',
                  patient['device_serial'] ?? 'Not paired',
                ),
                _infoRow(
                  'Battery Level',
                  patient['battery_level'] != null
                      ? '${patient['battery_level']}%'
                      : '—',
                ),
                _infoRow(
                  'Last Active',
                  patient['last_active_timestamp'] != null
                      ? _formatDate(patient['last_active_timestamp'])
                      : '—',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryPurple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Patients List Page – Fetches data directly from PostgreSQL
// ==========================================
class _PatientsListPage extends StatefulWidget {
  final int caregiverId;
  const _PatientsListPage({required this.caregiverId});

  @override
  State<_PatientsListPage> createState() => _PatientsListPageState();
}

class _PatientsListPageState extends State<_PatientsListPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final patients = await _apiService.getCaregiverPatients(
        widget.caregiverId,
      );
      print('📋 Patients API response: $patients'); // 👈 DEBUG
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching patients: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Helper to calculate age from date_of_birth
  String _getAge(String? dob) {
    if (dob == null || dob.isEmpty) return 'N/A';
    try {
      final birthDate = DateTime.parse(dob);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age.toString();
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients List'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPatients,
        color: AppColors.primaryPurple,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchPatients,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _patients.isEmpty
            ? const Center(child: Text('No patients assigned.'))
            : ListView.builder(
                itemCount: _patients.length,
                itemBuilder: (_, i) {
                  final p = _patients[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(p['full_name']?.substring(0, 1) ?? '?'),
                    ),
                    title: Text(p['full_name'] ?? 'Unknown'),
                    subtitle: Text('Age: ${_getAge(p['date_of_birth'])}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientDetailPage(patient: p),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(patient['full_name'] ?? 'Patient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Medical Notes: ${patient['medical_notes'] ?? 'None'}'),
            const SizedBox(height: 8),
            Text('Battery: ${patient['battery_level'] ?? 'N/A'}%'),
            const SizedBox(height: 8),
            Text('Device: ${patient['device_serial'] ?? 'Not paired'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Devices List Page – Fetches fresh data
// ==========================================
class _DevicesListPage extends StatefulWidget {
  final int caregiverId;
  const _DevicesListPage({required this.caregiverId});

  @override
  State<_DevicesListPage> createState() => _DevicesListPageState();
}

class _DevicesListPageState extends State<_DevicesListPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final patients = await _apiService.getCaregiverPatients(
        widget.caregiverId,
      );
      final devices = patients
          .where((p) => p['device_serial'] != null)
          .toList();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDevices,
        color: AppColors.primaryPurple,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchDevices,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _devices.isEmpty
            ? const Center(child: Text('No devices registered.'))
            : ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (_, i) {
                  final d = _devices[i];
                  return ListTile(
                    leading: Icon(
                      Icons.devices,
                      color: (d['battery_level'] ?? 100) < 20
                          ? Colors.red
                          : Colors.green,
                    ),
                    title: Text(d['device_serial'] ?? 'Unknown'),
                    subtitle: Text(
                      'Patient: ${d['full_name']} • Battery: ${d['battery_level'] ?? 'N/A'}%',
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ==========================================
// 🌟 完整版：Adherence Details Page (串接 PostgreSQL 真實數據)
// ==========================================
class _AdherenceDetailsPage extends StatefulWidget {
  final int caregiverId;
  const _AdherenceDetailsPage({required this.caregiverId});

  @override
  State<_AdherenceDetailsPage> createState() => _AdherenceDetailsPageState();
}

class _AdherenceDetailsPageState extends State<_AdherenceDetailsPage> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFullStats();
  }

  Future<void> _fetchFullStats() async {
    setState(() => _isLoading = true);
    try {
      // 這裡直接從 API 撈取最新的總體數據
      final data = await _apiService.getCaregiverOverview(widget.caregiverId);
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 提取數據
    final int taken = _stats['taken_count'] ?? 0;
    final int missed = _stats['missed_count'] ?? 0;
    final int pending = _stats['pending_count'] ?? 0;
    final int score = _stats['adherence_score'] ?? 0;
    final int total = taken + missed;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Adherence Analysis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F6FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFullStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 160,
                              height: 160,
                              child: CircularProgressIndicator(
                                value: score / 100,
                                strokeWidth: 15,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  score >= 80
                                      ? Colors.green
                                      : score >= 50
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$score%',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const Text(
                                  'Overall Score',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 2. 數據分析報告標題
                    const Text(
                      'Dose Distribution (Last 7 Days)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. 詳細卡片列表 (全動態)
                    _buildAnalysisCard(
                      'Successful Doses',
                      '$taken',
                      'Pills successfully dispensed & taken',
                      Colors.green,
                      Icons.check_circle,
                    ),
                    _buildAnalysisCard(
                      'Missed Doses',
                      '$missed',
                      'Alerts sent but no action detected',
                      Colors.red,
                      Icons.cancel,
                    ),
                    _buildAnalysisCard(
                      'Upcoming / Pending',
                      '$pending',
                      'Scheduled for the next 24 hours',
                      Colors.blue,
                      Icons.pending_actions,
                    ),

                    const SizedBox(height: 24),

                    // 4. 小提醒
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryPurple.withOpacity(0.1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: AppColors.primaryPurple,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Adherence is calculated based on IoT sensor data from all assigned pill dispensers.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAnalysisCard(
    String title,
    String value,
    String desc,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Doses Taken Page – Fetches fresh alerts
// ==========================================
class _DosesDetailsPage extends StatefulWidget {
  final int caregiverId;
  const _DosesDetailsPage({required this.caregiverId});

  @override
  State<_DosesDetailsPage> createState() => _DosesDetailsPageState();
}

class _DosesDetailsPageState extends State<_DosesDetailsPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _alerts = [];
  int _totalDoses = 0;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final overview = await _apiService.getCaregiverOverview(
        widget.caregiverId,
      );
      final allLogs = await _apiService.getAllRecentLogs(widget.caregiverId);
      setState(() {
        _totalDoses = overview['total_doses'] ?? 0;
        _alerts = allLogs; // now contains TAKEN + MISSED + PENDING
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doses Taken'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: AppColors.primaryPurple,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade200, blurRadius: 4),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Text(
                            'Total Doses Taken',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_totalDoses',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Recent Activity',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _alerts.isEmpty
                        ? const Center(child: Text('No recent dose records'))
                        : ListView.builder(
                            itemCount: _alerts.length,
                            itemBuilder: (_, i) {
                              final act = _alerts[i];
                              final isTaken = act['status'] == 'TAKEN';
                              return ListTile(
                                leading: Icon(
                                  isTaken ? Icons.check_circle : Icons.cancel,
                                  color: isTaken ? Colors.green : Colors.red,
                                ),
                                title: Text(act['patient_name'] ?? 'Patient'),
                                subtitle: Text(
                                  '${act['medication_name'] ?? 'Medication'} - ${act['status'] ?? 'Unknown'}',
                                ),
                                trailing: Text(
                                  act['scheduled_time'] != null
                                      ? DateTime.parse(
                                          act['scheduled_time'],
                                        ).toLocal().toString().substring(0, 16)
                                      : '',
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ==========================================
// 🎨 Curved Line Chart Painter (Matches Reference Image)
// ==========================================
class _CurvedChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final Color lineColor;
  final int selectedIndex;

  _CurvedChartPainter({
    required this.data,
    required this.labels,
    required this.lineColor,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || labels.isEmpty) return;

    // Chart boundary definitions
    const double leftPadding = 30.0;
    const double bottomPadding = 25.0;
    final double chartWidth = size.width - leftPadding;
    final double chartHeight = size.height - bottomPadding;

    final double maxV = data.isEmpty || data.every((e) => e == 0)
        ? 5.0
        : data.reduce(max).clamp(1.0, double.infinity);

    // 1. Draw Y-Axis Text
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final yLabels = [
      maxV.toInt().toString(),
      (maxV / 2).toInt().toString(),
      '0',
    ];
    for (int i = 0; i < yLabels.length; i++) {
      textPainter.text = TextSpan(
        text: yLabels[i],
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      final yPos = (i * (chartHeight / 2)) - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(0, yPos));
    }

    // Generate Points for the curve
    final int pointCount = min(data.length, labels.length);
    final points = List.generate(pointCount, (i) {
      final x = leftPadding + (i * chartWidth / (pointCount - 1));
      final y = chartHeight - ((data[i] / maxV) * chartHeight);
      return Offset(x, y);
    });

    if (points.isEmpty) return;

    // 2. Draw Gradient Fill
    final fillPath = Path()..moveTo(points.first.dx, chartHeight);
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
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withOpacity(0.3), lineColor.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight)),
    );

    // 3. Draw Smooth Line
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
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // 4. Draw X-Axis Labels and the Active Dot
    for (int i = 0; i < points.length; i++) {
      final isSelected = i == selectedIndex;

      // X-Axis Text
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: isSelected ? AppColors.textDark : Colors.grey.shade400,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - textPainter.width / 2, chartHeight + 10),
      );

      // Active Dot with Tooltip
      if (isSelected && data[i] > 0) {
        // Dot
        canvas.drawCircle(points[i], 6, Paint()..color = Colors.white);
        canvas.drawCircle(points[i], 4, Paint()..color = lineColor);

        // Tooltip bubble
        final valueText = data[i].toInt().toString();
        textPainter.text = TextSpan(
          text: valueText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();

        final bubbleRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(points[i].dx, points[i].dy - 22),
            width: textPainter.width + 16,
            height: 20,
          ),
          const Radius.circular(6),
        );
        canvas.drawRRect(bubbleRect, Paint()..color = lineColor);
        textPainter.paint(
          canvas,
          Offset(points[i].dx - textPainter.width / 2, points[i].dy - 29),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CurvedChartPainter old) => true;
}

// ==========================================
// 📊 Performance Details Page
// ==========================================
class _PerformanceDetailsPage extends StatelessWidget {
  final int caregiverId;
  final List<double> chartData;
  final List<String> chartLabels;
  final String period;

  const _PerformanceDetailsPage({
    required this.caregiverId,
    required this.chartData,
    required this.chartLabels,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final int totalDoses = chartData.fold(0, (sum, item) => sum + item.toInt());

    return Scaffold(
      appBar: AppBar(
        title: Text('$period Performance Details'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F6FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Doses Taken',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalDoses',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _CurvedChartPainter(
                        data: chartData,
                        labels: chartLabels,
                        lineColor: AppColors.primaryPurple,
                        selectedIndex: chartData.length - 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Data Insights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.insights, color: Colors.white),
                ),
                title: const Text('Highest Activity'),
                subtitle: Text(
                  'The most doses were taken on ${chartLabels[chartData.indexOf(chartData.reduce(max))]}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.info_outline, color: Colors.white),
                ),
                title: Text('About this metric'),
                subtitle: Text(
                  'This chart tracks successful physical dispenses verified by the IoT Smart Kit sensors.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🌟 Prescription Setup Details Page
// ==========================================
class CaregiverPrescriptionSetupPage extends StatefulWidget {
  final int caregiverId;
  const CaregiverPrescriptionSetupPage({super.key, required this.caregiverId});

  @override
  State<CaregiverPrescriptionSetupPage> createState() =>
      _CaregiverPrescriptionSetupPageState();
}

class _CaregiverPrescriptionSetupPageState
    extends State<CaregiverPrescriptionSetupPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final patients = await _apiService.getCaregiverPatients(
        widget.caregiverId,
      );
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Helper method to open the Prescription Form Bottom Sheet
  void _openPrescriptionForm(Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PrescriptionFormSheet(
        patient: patient,
        caregiverId: widget.caregiverId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription Setup'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F6FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _patients.isEmpty
          ? const Center(
              child: Text(
                'No patients assigned to manage.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _patients.length,
              itemBuilder: (context, index) {
                final p = _patients[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  // 🌟 Wrap Padding with InkWell to make the whole card clickable
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      // 🌟 Navigate to the new View Prescriptions Page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientPrescriptionsPage(patient: p),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // 🌟 RESTORED: Circular Profile Avatar
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.primaryPurple
                                .withOpacity(0.1),
                            child: Text(
                              p['full_name']?.substring(0, 1).toUpperCase() ??
                                  '?',
                              style: const TextStyle(
                                color: AppColors.primaryPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 🌟 RESTORED: Patient Name and Device Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['full_name'] ?? 'Unknown Patient',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Device: ${p['device_serial'] ?? 'Not Paired'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openPrescriptionForm(p),
                            icon: const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Set prescription",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 🌟 The Form Sheet for Adding Meds
// ==========================================
class _PrescriptionFormSheet extends StatefulWidget {
  final Map<String, dynamic> patient;
  final int caregiverId;

  const _PrescriptionFormSheet({
    required this.patient,
    required this.caregiverId,
  });

  @override
  State<_PrescriptionFormSheet> createState() => _PrescriptionFormSheetState();
}

class _PrescriptionFormSheetState extends State<_PrescriptionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String _medicationName = '';
  String _dosage = '';

  // 🌟 REPLACED: String _timeOfDay with a precise TimeOfDay object
  TimeOfDay? _selectedTime;

  List<String> _selectedDays = [];

  final List<String> _daysOfWeek = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  bool _isSaving = false;

  // 🌟 NEW: Helper to show the clock picker
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryPurple, // Header color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _savePrescription() async {
    if (_formKey.currentState!.validate()) {
      // Validate Time
      if (_selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a precise time.')),
        );
        return;
      }

      // Validate Days
      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one day.')),
        );
        return;
      }

      _formKey.currentState!.save();
      setState(() => _isSaving = true);

      try {
        // Prepare the formatted time string (e.g., "08:30" or "14:15") for your PostgreSQL database
        final String formattedTime =
            '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

        // TODO: Send to API
        // Example: await _apiService.addPrescription(widget.patient['patient_id'], _medicationName, _dosage, _selectedDays, formattedTime);
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pop(context); // Close the sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully added $_medicationName at ${_selectedTime!.format(context)} for ${widget.patient['full_name']}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: kToolbarHeight),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Setup Prescription',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'For ${widget.patient['full_name']}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // Medication Name
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Medication Name',
                  prefixIcon: const Icon(
                    Icons.medication_outlined,
                    color: AppColors.primaryPurple,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _medicationName = val!,
              ),
              const SizedBox(height: 16),

              // Dosage
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Dosage (e.g., 1 Pill, 500mg)',
                  prefixIcon: const Icon(
                    Icons.vaccines_outlined,
                    color: AppColors.primaryPurple,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _dosage = val!,
              ),
              const SizedBox(height: 24),

              // 🌟 Precise Time Picker UI
              const Text(
                'Precise Time',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedTime == null
                          ? Colors.grey.shade400
                          : AppColors.primaryPurple,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_filled_rounded,
                        color: _selectedTime == null
                            ? Colors.grey
                            : AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _selectedTime != null
                            ? _selectedTime!.format(context)
                            : 'Tap to select time...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _selectedTime != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedTime != null
                              ? AppColors.textDark
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Days of the week
              const Text(
                'Schedule Days',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _daysOfWeek.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    selectedColor: AppColors.primaryPurple.withOpacity(0.2),
                    checkmarkColor: AppColors.primaryPurple,
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _selectedDays.add(day)
                            : _selectedDays.remove(day);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePrescription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Assign Prescription',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 🌟 View Existing Prescriptions Page
// ==========================================
class PatientPrescriptionsPage extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientPrescriptionsPage({super.key, required this.patient});

  @override
  State<PatientPrescriptionsPage> createState() =>
      _PatientPrescriptionsPageState();
}

class _PatientPrescriptionsPageState extends State<PatientPrescriptionsPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _prescriptions = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPrescriptions();
  }

  Future<void> _fetchPrescriptions() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      // 🌟 Calls your existing Flask GET endpoint!
      final prescriptions = await _apiService.getPatientPrescriptions(
        widget.patient['patient_id'],
      );
      setState(() {
        _prescriptions = List<Map<String, dynamic>>.from(prescriptions);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.patient['full_name']}\'s Prescriptions'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF4F6FB),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            )
          : _error.isNotEmpty
          ? Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _prescriptions.isEmpty
          ? const Center(
              child: Text(
                'No active prescriptions found.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchPrescriptions,
              color: AppColors.primaryPurple,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _prescriptions.length,
                itemBuilder: (context, index) {
                  final rx = _prescriptions[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryPurple,
                        child: Icon(Icons.medication, color: Colors.white),
                      ),
                      title: Text(
                        rx['medication_name'] ?? 'Unknown Med',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dosage: ${rx['dosage_tablet']}'),
                            Text(
                              'Schedule: ${rx['dispense_schedule']}',
                            ), // Note: CRON string, you might want to parse this later!
                            Text('Inventory: ${rx['current_inventory']} left'),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
