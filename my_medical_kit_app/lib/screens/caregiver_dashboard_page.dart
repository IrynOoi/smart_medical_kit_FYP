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
        _chartData = data;
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
  int get _devicesOnline => _patients.length;
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
              Expanded(
                child: _buildStatCard(
                  title: 'Doses Taken',
                  value: _totalDoses.toString(),
                  subtitle: 'All records',
                  icon: Icons.medication_rounded,
                  color: const Color(0xFF4CAF82),
                  onTap: _navigateToDosesDetails,
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
  // 4. CHART SECTION (IMPROVISED VERSION)
  // ==========================================
  Widget _buildChartSection() {
    // 確保不會出現除以 0 的情況
    final double maxValue =
        _chartData.isEmpty || _chartData.every((e) => e == 0)
        ? 5.0
        : _chartData.reduce(max).toDouble();

    final days = _chartLabels;

    // 判斷高亮索引 (僅在 Week 模式下高亮今天)
    final int todayIndex = _selectedPeriod == 'Week'
        ? (DateTime.now().weekday - 1)
        : -1;
    final int barCount = min(days.length, _chartData.length);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              // 時間選擇器切換按鈕
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
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
                          color: isSelected
                              ? AppColors.primaryPurple
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          period,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
          const SizedBox(height: 24),

          // 圖表繪製區
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y 軸刻度
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      maxValue.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Text(
                      (maxValue / 2).toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 20), // 給底部的星期標籤留空隙
                  ],
                ),
                const SizedBox(width: 12),

                // 柱狀圖與網格線
                Expanded(
                  child: Stack(
                    children: [
                      // 背景網格線 (Horizontal Lines)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          3,
                          (index) => Divider(
                            color: Colors.grey.shade100,
                            height: 1,
                            thickness: 1,
                          ),
                        ),
                      ),

                      // 柱子本體
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(barCount, (index) {
                          final value = _chartData[index];
                          final height = (value / maxValue) * 115;
                          final isToday = index == todayIndex;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (value > 0)
                                Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isToday
                                        ? AppColors.primaryPurple
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              const SizedBox(height: 4),

                              // 🌟 帶漸層的柱子
                              Container(
                                width: 22,
                                height: height.clamp(4.0, 115.0),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isToday
                                        ? [
                                            AppColors.primaryPurple,
                                            AppColors.primaryPurple.withOpacity(
                                              0.7,
                                            ),
                                          ]
                                        : [
                                            AppColors.primaryPurple.withOpacity(
                                              0.5,
                                            ),
                                            AppColors.primaryPurple.withOpacity(
                                              0.3,
                                            ),
                                          ], // 🌟 加深了顏色
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // 下方的星期/時間標籤
                              Text(
                                days[index],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isToday
                                      ? AppColors.primaryPurple
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 底部統計文字
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
                onPressed: () {},
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
                    subtitle: Text('Battery: ${p['battery_level'] ?? 'N/A'}%'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showPatientDetails(p),
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
