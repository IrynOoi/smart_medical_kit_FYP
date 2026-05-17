import 'package:my_medical_kit_app/services/api/api_client.dart';
// lib/screens/caregiver_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'caregiver_patients_list_page.dart';
import 'caregiver_devices_list_page.dart';
import 'caregiver_adherence_details_page.dart';
import '../../widget/caregiver_wdgt/curved_chart_painter.dart';
import 'caregiver_performance_details_page.dart';
import 'caregiver_prescription_setup_page.dart';
import 'caregiver_medications_list_page.dart';

String formatDosage(double dosage) {
  if (dosage == dosage.toInt()) {
    return '${dosage.toInt()} tablet${dosage.toInt() > 1 ? 's' : ''}';
  }
  return '${dosage.toStringAsFixed(2)} tablets';
}

class CaregiverDashboardPage extends StatefulWidget {
  const CaregiverDashboardPage({super.key});

  @override
  State<CaregiverDashboardPage> createState() => _CaregiverDashboardPageState();
}

class _CaregiverDashboardPageState extends State<CaregiverDashboardPage> {
  

  String _caregiverPhotoUrl = '';

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
      final data = await CaregiverService().getChartData(_caregiverId, period);
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

      final profile = await CaregiverService().getCaregiverProfile(_caregiverId);
      if (profile['success'] == true) {
        setState(() {
          _caregiverPhotoUrl = profile['data']['profile_photo'] ?? '';
        });
      }
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
        CaregiverService().getCaregiverOverview(_caregiverId),
        CaregiverService().getCaregiverPatients(_caregiverId),
        CaregiverService().getCaregiverAlerts(_caregiverId),
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
  int get _totalPrescriptions => _overviewStats['total_prescriptions'] ?? 0;
  int get _devicesOnline =>
      _patients.where((p) => p['device_id'] != null).length;

  int get _distinctMedications => _overviewStats['distinct_medications'] ?? 0;

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
        builder: (_) => CaregiverPatientsListPage(caregiverId: _caregiverId),
      ),
    );
  }

  void _navigateToDevicesList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaregiverDevicesListPage(caregiverId: _caregiverId),
      ),
    );
  }

  void _navigateToAdherenceDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CaregiverAdherenceDetailsPage(caregiverId: _caregiverId),
      ),
    );
  }

  // void _navigateToAlertsDetails() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => CaregiverAlertsDetailsPage(caregiverId: _caregiverId),
  //     ),
  //   );
  // }

  void _navigateToPerformanceDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaregiverPerformanceDetailsPage(
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
      return Scaffold(
        backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.05),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.05),
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
      backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.05),
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
                // const SizedBox(height: 16),
                // _buildRecentActivities(),
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
              const SizedBox(width: 10),
              const Text(
                'MedSmart',
                style: TextStyle(
                  fontSize: 24,
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
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  backgroundImage: _caregiverPhotoUrl.isNotEmpty
                      ? (_caregiverPhotoUrl.startsWith('http')
                            ? NetworkImage(_caregiverPhotoUrl)
                            : NetworkImage(
                                '${ApiClient.baseUrl}${_caregiverPhotoUrl.startsWith('/') ? '' : '/'}$_caregiverPhotoUrl',
                              ))
                      : null,
                  child: _caregiverPhotoUrl.isEmpty
                      ? Text(
                          _caregiverName.isNotEmpty
                              ? _caregiverName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryPurple,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
            color: Colors.black.withValues(alpha: 0.04),
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
                    color: AppColors.primaryPurple.withValues(alpha: 0.1),
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
              Expanded(
                child: _buildStatCard(
                  title: 'Prescriptions',
                  value: _totalPrescriptions.toString(),
                  subtitle: 'Tap to manage',
                  icon: Icons.post_add_rounded,
                  color: AppColors.premiumLight,
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
                  color: AppColors.premiumMid,
                  onTap: _navigateToDevicesList,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatCard(
                  title: 'Medications',
                  value: _distinctMedications.toString(),
                  subtitle: 'Active Rx',
                  icon: Icons.medication_rounded,
                  color: AppColors.premiumMid,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CaregiverMedicationsListPage(),
                      ),
                    );
                  },
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
              color: Colors.black.withValues(alpha: 0.04),
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
                    color: color.withValues(alpha: 0.1),
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
                                    color: Colors.black.withValues(alpha: 0.05),
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
                    color: Colors.black.withValues(alpha: 0.04),
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
                  painter: CurvedChartPainter(
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

  // Widget _buildRecentActivities() {
  //   /* unchanged */
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16),
  //     padding: const EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(24),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: 0.04),
  //           blurRadius: 10,
  //           offset: const Offset(0, 3),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             const Text(
  //               'Recent Alerts',
  //               style: TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.bold,
  //                 color: AppColors.textDark,
  //               ),
  //             ),
  //             TextButton(
  //               onPressed:
  //                   _navigateToAlertsDetails, // ✅ FIX: Add the navigation function here
  //               style: TextButton.styleFrom(
  //                 padding: const EdgeInsets.symmetric(
  //                   horizontal: 8,
  //                   vertical: 4,
  //                 ),
  //               ),
  //               child: const Text(
  //                 'View All',
  //                 style: TextStyle(
  //                   color: AppColors.primaryPurple,
  //                   fontSize: 12,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 16),
  //         if (_recentActivities.isEmpty)
  //           const Padding(
  //             padding: EdgeInsets.all(20),
  //             child: Center(
  //               child: Text(
  //                 'All good! No recent alerts 🎉',
  //                 style: TextStyle(fontSize: 14),
  //               ),
  //             ),
  //           )
  //         else
  //           ..._recentActivities.map(
  //             (activity) => _buildActivityItem(activity),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    /* unchanged */
    final isMissed = activity['status'] == 'MISSED';
    final color = AppColors.primaryPurple;
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
              color: color.withValues(alpha: 0.1),
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
