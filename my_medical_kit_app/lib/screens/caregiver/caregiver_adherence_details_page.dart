//caregiver_adherence_details_page.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';


class CaregiverAdherenceDetailsPage extends StatefulWidget {
  final int caregiverId;
  const CaregiverAdherenceDetailsPage({super.key, required this.caregiverId});

  @override
  State<CaregiverAdherenceDetailsPage> createState() =>
      CaregiverAdherenceDetailsPageState();
}

class CaregiverAdherenceDetailsPageState
    extends State<CaregiverAdherenceDetailsPage> {
  
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
      final data = await CaregiverService().getCaregiverOverview(widget.caregiverId);
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
                              color: Colors.black.withValues(alpha: 0.05),
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
                        color: AppColors.primaryPurple.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryPurple.withValues(alpha: 0.1),
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
              color: color.withValues(alpha: 0.1),
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
