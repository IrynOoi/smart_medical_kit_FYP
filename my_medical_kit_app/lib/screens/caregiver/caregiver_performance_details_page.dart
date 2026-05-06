//caregiver_performance_details_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';

import '../../widget/caregiver_wdgt/curved_chart_painter.dart';

class CaregiverPerformanceDetailsPage extends StatelessWidget {
  final int caregiverId;
  final List<double> chartData;
  final List<String> chartLabels;
  final String period;

  const CaregiverPerformanceDetailsPage({super.key, 
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
                      painter: CurvedChartPainter(
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
