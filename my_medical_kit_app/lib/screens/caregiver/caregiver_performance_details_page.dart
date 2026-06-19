//caregiver_performance_details_page.dart
// caregiver_performance_details_page.dart
// Displays detailed performance metrics for a caregiver over a selected period.
// Shows a total doses count and a curved chart visualizing the number of taken doses
// per time unit (day, week, or month), along with some insights like the highest activity day.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';

import '../../widget/caregiver_wdgt/curved_chart_painter.dart';

class CaregiverPerformanceDetailsPage extends StatelessWidget {
  final int
  caregiverId; // ID of the caregiver (currently unused but kept for future use)
  final List<double>
  chartData; // List of dose counts for each time unit (e.g., 7 values for a week)
  final List<String>
  chartLabels; // Corresponding labels for the x‑axis (e.g., ['Mon', 'Tue', ...])
  final String period; // The selected time period ('Day', 'Week', or 'Month')

  const CaregiverPerformanceDetailsPage({
    super.key,
    required this.caregiverId,
    required this.chartData,
    required this.chartLabels,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    // Compute total doses by summing all values in chartData.
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
            // Main card: shows total doses and the chart.
            Container(
              padding: const EdgeInsets.all(24),
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
              child: Column(
                children: [
                  // Total doses header
                  const Text(
                    'Total Doses Taken',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Total doses value
                  Text(
                    '$totalDoses',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // The chart widget (custom painter)
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: CurvedChartPainter(
                        data: chartData,
                        labels: chartLabels,
                        lineColor: AppColors.primaryPurple,
                        selectedIndex:
                            chartData.length -
                            1, // Highlights the last data point
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // "Data Insights" section title
            const Text(
              'Data Insights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),

            // If there is at least one dose, show the "Highest Activity" insight.
            if (totalDoses > 0)
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
              )
            else
              // If no data, show a "No Data Available" card.
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.info_outline, color: Colors.white),
                  ),
                  title: Text('No Data Available'),
                  subtitle: Text('No doses recorded during this period.'),
                ),
              ),
            const SizedBox(height: 12),

            // Information card explaining what the metric represents.
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
