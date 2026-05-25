// lib/screens/ai_analytics_page_caregiver.dart
import '../../models/ai_prediction.dart';
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';
import 'package:my_medical_kit_app/services/api/prediction_service.dart';

class AiAnalyticsPage extends StatefulWidget {
  final int caregiverId;

  const AiAnalyticsPage({super.key, required this.caregiverId});

  @override
  State<AiAnalyticsPage> createState() => _AiAnalyticsPageState();
}

class _AiAnalyticsPageState extends State<AiAnalyticsPage> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';

  Map<int, AIPrediction?> _patientPredictions = {};

  // Real data from backend
  Map<String, dynamic> _overview = {};
  final List<Map<String, dynamic>> _riskPatients = [];
  List<Map<String, dynamic>> _allPatients = [];
  final Map<int, bool> _predictingPatients = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  double _toDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final overview = await CaregiverService().getAnalyticsOverview(
        widget.caregiverId,
      );
      final allPatients = await CaregiverService().getCaregiverPatients(
        widget.caregiverId,
      );

      // 并发获取每个患者的最新预测
      final Map<int, AIPrediction?> predictions = {};
      await Future.wait(
        allPatients.map((patient) async {
          final pid = patient['patient_id'];
          final pred = await PredictionService().getAIPrediction(pid);
          predictions[pid] = pred;
        }),
      );

      setState(() {
        _overview = overview;
        _allPatients = allPatients;
        _patientPredictions = predictions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load analytics: $e';
        _isLoading = false;
      });
    }
  }

  // Fetch patient's recent adherence history
  Future<List<int>> _fetchPatientHistory(int patientId) async {
    try {
      final logs = await PatientService().getAdherenceLogs(
        patientId,
        limit: 10,
      );
      final history = <int>[];

      for (var log in logs) {
        if (log.status == 'TAKEN')
          history.add(1);
        else if (log.status == 'MISSED')
          history.add(0);
        if (history.length == 3) break;
      }

      // 关键修改：用 -1 代替 1 来填充
      while (history.length < 3) {
        history.insert(0, -1);
      }
      return history.reversed.toList();
    } catch (e) {
      return [-1, -1, -1]; // 默认也是 -1
    }
  }

  String _getCurrentDayOfWeek() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[DateTime.now().weekday - 1];
  }

  String _getCurrentTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 18) return 'Afternoon';
    return 'Evening';
  }

  // Show prediction dialog with history loading

  Future<void> _showPredictionDialog(Map<String, dynamic> patient) async {
    final int patientId = patient['patient_id'];
    final String patientName = patient['full_name'] ?? 'Patient';

    int age = 65;
    if (patient['date_of_birth'] != null) {
      try {
        final dob = DateTime.parse(patient['date_of_birth']);
        age = DateTime.now().difference(dob).inDays ~/ 365;
      } catch (e) {
        age = 65;
      }
    }

    // Show loading dialog while fetching history
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    await Future.delayed(const Duration(milliseconds: 200));

    List<int> history = await _fetchPatientHistory(patientId);
    String dayOfWeek = _getCurrentDayOfWeek();
    String timeOfDay = _getCurrentTimeOfDay();

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close loading spinner
    }

    // ✅ FIX 1: Move variable OUTSIDE the builder so it doesn't reset on setState!
    bool isPredicting = false;

    // Show initial prediction setup dialog
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> runPrediction() async {
            setStateDialog(
              () => isPredicting = true,
            ); // Show spinner in current dialog
            try {
              final result = await PredictionService().predictAndSaveForPatient(
                patientId: patientId,
                age: age,
                dayOfWeek: dayOfWeek,
                timeOfDay: timeOfDay,
                history: history,
              );

              print('🔍 API result: $result');

              // ✅ FIX 2: Close the current setup dialog BEFORE popping the new window
              if (mounted) {
                Navigator.pop(context);
              }

              // 1. Check for success flag first
              if (result['success'] == false) {
                // 使用 Future.microtask 确保 pop 操作在当前 UI 循环结束后执行
                if (mounted) {
                  // 使用 Future 延迟一小段时间，确保上一个窗口完全关闭，避免上下文竞争
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Insufficient Data'),
                          content: Text(
                            result['message'] ?? 'Not enough history.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  });
                }
                return;
              }

              // 2. Proceed with showing the prediction if successful
              if (!result.containsKey('prediction_score') ||
                  !result.containsKey('risk_level')) {
                throw Exception('Invalid response format');
              }

              // ✅ FIX 3: Pop out a NEW window with the AI results!
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text(
                      '✅ Prediction Complete!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    content: _buildPredictionResultCard(
                      (result['prediction_score'] as num?)?.toDouble() ?? 0.0,
                      result['risk_level']?.toString() ?? 'LOW',
                    ),
                    actions: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final freshPred = await PredictionService().getAIPrediction(
                patientId,
              );
              if (mounted) {
                setState(() {
                  _patientPredictions[patientId] = freshPred;
                });
              }
            } catch (e) {
              print('❌ Prediction error: $e');
              if (mounted) {
                Navigator.pop(context); // Close the dialog if it failed
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Prediction failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          return AlertDialog(
            title: Text('Hybrid AI Prediction for $patientName'),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxWidth: 400),
              child: isPredicting
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 20),
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Running Hybrid AI (LSTM + Random Forest)...',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 20),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'This will run the Hybrid AI model (LSTM + Random Forest) to predict:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text('• Probability of missing next dose'),
                          const Text('• Risk level (LOW/MEDIUM/HIGH)'),
                          const Text('• Temporal pattern analysis'),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Patient Information:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow('Name', patientName),
                                _buildInfoRow('Age', age.toString()),
                                _buildInfoRow('Day', dayOfWeek),
                                _buildInfoRow('Time', timeOfDay),
                                const SizedBox(height: 8),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text(
                                  'Recent Adherence History:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: history.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final value = entry.value;
                                    return Column(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            // 逻辑：1=绿，0=红，-1=灰
                                            color: value == 1
                                                ? Colors.green
                                                : (value == 0
                                                      ? Colors.red
                                                      : Colors.grey),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              value == 1
                                                  ? Icons.check
                                                  : (value == 0
                                                        ? Icons.close
                                                        : Icons.remove),
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          index == 0
                                              ? 'Most Recent'
                                              : index == 2
                                              ? 'Oldest'
                                              : '',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'History: ${history.map((h) => h == 1 ? '✓ Taken' : '✗ Missed').join(' → ')}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            actions: !isPredicting
                ? [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: runPrediction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Run Prediction'),
                    ),
                  ]
                : [],
          );
        },
      ),
    );

    // Refresh the page after the dialog is closed
    _loadData();
  }

  Widget _buildPredictionResultCard(double score, String riskLevel) {
    final riskColor = riskLevel == 'HIGH'
        ? Colors.redAccent
        : riskLevel == 'MEDIUM'
        ? Colors.orange
        : Colors.green;

    final double forgetProbability = 100.0 - score;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [riskColor.withValues(alpha: 0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min, // 🔴 FIX: Shrinks the box to normal size!
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Risk Level:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  riskLevel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Forget Probability:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${forgetProbability.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: forgetProbability / 100,
            backgroundColor: Colors.grey.shade200,
            color: riskColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            score > 60
                ? '⚠️ High risk of missing next dose. Send reminder!'
                : score > 30
                ? '📊 Moderate risk. Monitor patient closely.'
                : '✅ Patient adherence is stable.',
            style: TextStyle(fontSize: 12, color: riskColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // Run prediction for a single patient
  Future<void> _predictForPatient(
    int patientId,
    int age,
    String dayOfWeek,
    String timeOfDay,
    List<int> history,
  ) async {
    setState(() {
      _predictingPatients[patientId] = true;
    });

    try {
      final success = await PredictionService().predictAndSave(
        patientId: patientId,
        age: age,
        dayOfWeek: dayOfWeek,
        timeOfDay: timeOfDay,
        history: history,
      );

      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Hybrid AI prediction completed successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Prediction failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Prediction failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _predictingPatients[patientId] = false;
      });
    }
  }

  // Run batch prediction for all patients
  Future<void> _runBatchPrediction() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final success = await PredictionService().runBatchPrediction();

      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Batch AI prediction completed for all patients!',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Batch prediction failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Batch prediction failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // // Navigate to patient profile
  // void _navigateToPatientProfile(Map<String, dynamic> patient) {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => _PatientDetailPage(patient: patient),
  //     ),
  //   );
  // }

  Future<void> _showPatientPrediction(Map<String, dynamic> patient) async {
    final int patientId = patient['patient_id'];
    final String patientName = patient['full_name'] ?? 'Patient';

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // 🔴 FIX: Wait 200ms to allow the dialog animation to finish before API call
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final prediction = await PredictionService().getAIPrediction(patientId);

      if (mounted) {
        // 🔴 FIX: Use rootNavigator to safely close the loading spinner without crashing
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (prediction != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('AI Prediction – $patientName'),
            content: _buildPredictionResultCard(
              prediction.predictionScore,
              // 🔴 FIX: Safely extracts string from Enum without crashing
              prediction.riskLevel.toString().split('.').last.toUpperCase(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showPredictionDialog(patient);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white, // 🔴 FIX: White text
                ),
                child: const Text('Refresh Prediction'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('No Prediction Yet – $patientName'),
            content: const Text(
              'No AI prediction found for this patient.\nWould you like to run the hybrid model now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showPredictionDialog(patient);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white, // 🔴 FIX: White text
                ),
                child: const Text('Run Prediction'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading prediction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // // Show all at-risk patients
  // void _showAllAtRiskPatients() {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => DraggableScrollableSheet(
  //       initialChildSize: 0.9,
  //       minChildSize: 0.5,
  //       maxChildSize: 0.95,
  //       builder: (context, scrollController) => Container(
  //         decoration: const BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //         ),
  //         child: Column(
  //           children: [
  //             Container(
  //               margin: const EdgeInsets.symmetric(vertical: 12),
  //               width: 40,
  //               height: 4,
  //               decoration: BoxDecoration(
  //                 color: Colors.grey.shade300,
  //                 borderRadius: BorderRadius.circular(2),
  //               ),
  //             ),
  //             const Padding(
  //               padding: EdgeInsets.all(16),
  //               child: Text(
  //                 'All At-Risk Patients',
  //                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  //               ),
  //             ),
  //             Expanded(
  //               child: ListView.builder(
  //                 controller: scrollController,
  //                 itemCount: _riskPatients.length,
  //                 itemBuilder: (context, index) {
  //                   final patient = _riskPatients[index];
  //                   return ListTile(
  //                     leading: CircleAvatar(
  //                       backgroundColor:
  //                           (patient['risk_level'] == 'HIGH'
  //                                   ? Colors.redAccent
  //                                   : Colors.orange)
  //                               .withValues(alpha: 0.1),
  //                       child: Text(
  //                         (patient['name'] ?? '?')[0],
  //                         style: TextStyle(
  //                           color: patient['risk_level'] == 'HIGH'
  //                               ? Colors.redAccent
  //                               : Colors.orange,
  //                           fontWeight: FontWeight.bold,
  //                         ),
  //                       ),
  //                     ),
  //                     title: Text(patient['name'] ?? 'Unknown'),
  //                     subtitle: Text(patient['medication'] ?? 'No medication'),
  //                     trailing: Chip(
  //                       label: Text(patient['risk_level'] ?? 'MEDIUM'),
  //                       backgroundColor:
  //                           (patient['risk_level'] == 'HIGH'
  //                                   ? Colors.redAccent
  //                                   : Colors.orange)
  //                               .withValues(alpha: 0.2),
  //                       labelStyle: TextStyle(
  //                         color: patient['risk_level'] == 'HIGH'
  //                             ? Colors.redAccent
  //                             : Colors.orange,
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                     onTap: () {
  //                       Navigator.pop(context);
  //                       final fullPatient = _allPatients.firstWhere(
  //                         (p) => p['full_name'] == patient['name'],
  //                         orElse: () => {},
  //                       );
  //                       if (fullPatient.isNotEmpty) {
  //                         _showPatientPrediction(fullPatient);
  //                       }
  //                     },
  //                   );
  //                 },
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

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
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(_errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                ),
                child: const Text('Retry'),
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
          onRefresh: _loadData,
          color: AppColors.primaryPurple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHybridAIHeaderCard(),
                const SizedBox(height: 24),
                _buildActionableInsights(),
                const SizedBox(height: 24),
                _buildBatchPredictionButton(),
                const SizedBox(height: 16),
                _buildAssignedPatientsList(),
                // const SizedBox(height: 16),
                // _buildRiskAnalysisList(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBatchPredictionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: _isRefreshing ? null : _runBatchPrediction,
        icon: _isRefreshing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome, size: 18),
        label: Text(
          _isRefreshing
              ? 'Running Hybrid AI Analytics...'
              : 'Run Hybrid AI Analytics for All Patients',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedPatientsList() {
    if (_allPatients.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              'No patients assigned.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assigned Patients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '${_allPatients.length} patients',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allPatients.length,
            itemBuilder: (context, index) {
              final patient = _allPatients[index];
              final isPredicting =
                  _predictingPatients[patient['patient_id']] == true;
              return _buildPatientCard(patient, isPredicting);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient, bool isPredicting) {
    final int pid = patient['patient_id'];
    final AIPrediction? pred = _patientPredictions[pid];
    final String riskLevel =
        pred?.riskLevel.toString().split('.').last.toUpperCase() ?? 'LOW';

    // Only flag MEDIUM and HIGH
    final bool hasRisk = riskLevel == 'HIGH' || riskLevel == 'MEDIUM';
    final Color riskColor = riskLevel == 'HIGH'
        ? Colors.redAccent
        : (riskLevel == 'MEDIUM' ? Colors.orange : Colors.grey);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // Draw border ONLY if it's HIGH or MEDIUM, otherwise no border
        side: hasRisk
            ? BorderSide(color: riskColor.withValues(alpha: 0.6), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPatientPrediction(patient),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                // Neutral purple background for the avatar instead of the risk color
                backgroundColor: AppColors.primaryPurple.withValues(
                  alpha: 0.15,
                ),
                child: Text(
                  patient['full_name']?[0]?.toUpperCase() ?? '?',
                  style: const TextStyle(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient['full_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (patient['device_serial'] != null)
                      Text(
                        'Device: ${patient['device_serial']} • Battery: ${patient['battery_level'] ?? 'N/A'}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: (patient['battery_level'] ?? 100) < 20
                              ? Colors.red
                              : Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 6),
                    // ✨ NEW: Risk Label injected directly onto the patient card
                    if (pred != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: hasRisk
                              ? riskColor.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Risk: $riskLevel',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasRisk ? riskColor : Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: isPredicting
                    ? null
                    : () => _showPredictionDialog(patient),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                ),
                child: isPredicting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        children: [
                          Icon(Icons.auto_graph, size: 16),
                          SizedBox(width: 6),
                          Text('Predict'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // HEADER CARD
  Widget _buildHybridAIHeaderCard() {
    final overallScore = _toDouble(
      _overview['overall_adherence_prediction'],
      defaultValue: 85.0,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 24,
        24,
        32,
      ),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hybrid AI Model (LSTM + Random Forest)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'System Online & Analyzing',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderStat(
                label: 'System Forecast',
                value: '${overallScore.toStringAsFixed(1)}%',
                subLabel: 'Expected Adherence',
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              _buildHeaderStat(
                label: 'Patients Analyzed',
                value: '${_overview['total_analyzed'] ?? 0}',
                subLabel: 'Active Profiles',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({
    required String label,
    required String value,
    required String subLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subLabel,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }

  // ACTIONABLE INSIGHTS
  Widget _buildActionableInsights() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actionable Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  title: 'High Risk',
                  count: '${_overview['high_risk_patients'] ?? 0}',
                  icon: Icons.warning_rounded,
                  color: Colors.redAccent,
                  subtitle: 'Needs Attention',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInsightCard(
                  title: 'Medium Risk',
                  count: '${_overview['medium_risk_patients'] ?? 0}',
                  icon: Icons.trending_down_rounded,
                  color: Colors.orange,
                  subtitle: 'Monitor Closely',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // // RISK PATIENTS LIST
  // Widget _buildRiskAnalysisList() {
  //   if (_riskPatients.isEmpty) {
  //     return Padding(
  //       padding: const EdgeInsets.symmetric(horizontal: 20),
  //       child: Container(
  //         padding: const EdgeInsets.all(24),
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(20),
  //         ),
  //         child: const Center(
  //           child: Text(
  //             'No at-risk patients found.\nAll patients are stable.',
  //             textAlign: TextAlign.center,
  //             style: TextStyle(color: Colors.grey),
  //           ),
  //         ),
  //       ),
  //     );
  //   }

  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 20),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             const Text(
  //               'Identified At-Risk Patients',
  //               style: TextStyle(
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //                 color: AppColors.textDark,
  //               ),
  //             ),
  //             TextButton(
  //               onPressed: _showAllAtRiskPatients,
  //               child: const Text(
  //                 'See All',
  //                 style: TextStyle(color: AppColors.primaryPurple),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 8),
  //         ListView.builder(
  //           shrinkWrap: true,
  //           physics: const NeverScrollableScrollPhysics(),
  //           itemCount: _riskPatients.length > 3 ? 3 : _riskPatients.length,
  //           itemBuilder: (context, index) {
  //             final patient = _riskPatients[index];
  //             return _buildPatientRiskCard(patient);
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildPatientRiskCard(Map<String, dynamic> patient) {
  //   final riskLevel = (patient['risk_level'] ?? 'MEDIUM')
  //       .toString()
  //       .toUpperCase();
  //   final isHighRisk = riskLevel == 'HIGH';
  //   final riskColor = isHighRisk ? Colors.redAccent : Colors.orange;
  //   final forgetProb = _toDouble(
  //     patient['forget_probability'],
  //     defaultValue: 50.0,
  //   );
  //   final temporalPattern =
  //       patient['temporal_pattern'] ?? 'Irregular pattern detected';

  //   final fullPatient = _allPatients.firstWhere(
  //     (p) => p['full_name'] == patient['name'],
  //     orElse: () => {},
  //   );

  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 16),
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(20),
  //       border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 1.5),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: 0.02),
  //           blurRadius: 10,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Row(
  //               children: [
  //                 CircleAvatar(
  //                   radius: 20,
  //                   backgroundColor: riskColor.withValues(alpha: 0.1),
  //                   child: Text(
  //                     (patient['name'] ?? '?')[0],
  //                     style: TextStyle(
  //                       color: riskColor,
  //                       fontWeight: FontWeight.bold,
  //                       fontSize: 16,
  //                     ),
  //                   ),
  //                 ),
  //                 const SizedBox(width: 12),
  //                 Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       patient['name'] ?? 'Unknown',
  //                       style: const TextStyle(
  //                         fontSize: 16,
  //                         fontWeight: FontWeight.bold,
  //                         color: AppColors.textDark,
  //                       ),
  //                     ),
  //                     Text(
  //                       patient['medication'] ?? 'No medication',
  //                       style: TextStyle(
  //                         fontSize: 12,
  //                         color: Colors.grey.shade600,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ],
  //             ),
  //             Container(
  //               padding: const EdgeInsets.symmetric(
  //                 horizontal: 10,
  //                 vertical: 4,
  //               ),
  //               decoration: BoxDecoration(
  //                 color: riskColor.withValues(alpha: 0.1),
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               child: Text(
  //                 riskLevel,
  //                 style: TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: FontWeight.bold,
  //                   color: riskColor,
  //                   letterSpacing: 0.5,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 16),
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color: AppColors.scaffoldBackground,
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //           child: Row(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const Icon(
  //                 Icons.insights_rounded,
  //                 size: 18,
  //                 color: AppColors.primaryPurple,
  //               ),
  //               const SizedBox(width: 10),
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     const Text(
  //                       'Hybrid AI Assessment:',
  //                       style: TextStyle(
  //                         fontSize: 12,
  //                         fontWeight: FontWeight.bold,
  //                         color: AppColors.textDark,
  //                       ),
  //                     ),
  //                     const SizedBox(height: 4),
  //                     Text(
  //                       temporalPattern,
  //                       style: TextStyle(
  //                         fontSize: 13,
  //                         color: Colors.grey.shade700,
  //                       ),
  //                     ),
  //                     const SizedBox(height: 8),
  //                     Text(
  //                       'Probability of missing next dose: ${forgetProb.toStringAsFixed(1)}%',
  //                       style: TextStyle(
  //                         fontSize: 12,
  //                         fontWeight: FontWeight.w600,
  //                         color: riskColor,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         const SizedBox(height: 12),
  //         Row(
  //           children: [
  //             Expanded(
  //               child: ElevatedButton.icon(
  //                 onPressed: () {
  //                   if (fullPatient.isNotEmpty) {
  //                     _showPredictionDialog(fullPatient);
  //                   }
  //                 },
  //                 icon: const Icon(Icons.refresh_rounded, size: 16),
  //                 label: const Text('Refresh Prediction'),
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: AppColors.primaryPurple,
  //                   foregroundColor: Colors.white,
  //                   elevation: 0,
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(12),
  //                   ),
  //                   padding: const EdgeInsets.symmetric(vertical: 12),
  //                 ),
  //               ),
  //             ),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: OutlinedButton.icon(
  //                 onPressed: () {
  //                   if (fullPatient.isNotEmpty) {
  //                     _showPatientPrediction(fullPatient);
  //                   }
  //                 },
  //                 icon: const Icon(Icons.person_search_rounded, size: 16),
  //                 label: const Text('View Profile'),
  //                 style: OutlinedButton.styleFrom(
  //                   foregroundColor: AppColors.primaryPurple,
  //                   side: const BorderSide(color: AppColors.primaryPurple),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(12),
  //                   ),
  //                   padding: const EdgeInsets.symmetric(vertical: 12),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

// ==========================================
// Patient Detail Page
// ==========================================
class _PatientDetailPage extends StatelessWidget {
  final Map<String, dynamic> patient;

  const _PatientDetailPage({required this.patient});

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
