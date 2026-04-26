// lib/screens/ai_analytics_page_caregiver.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';

class AiAnalyticsPage extends StatefulWidget {
  final int caregiverId;

  const AiAnalyticsPage({super.key, required this.caregiverId});

  @override
  State<AiAnalyticsPage> createState() => _AiAnalyticsPageState();
}

class _AiAnalyticsPageState extends State<AiAnalyticsPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';

  // Real data from backend
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _riskPatients = [];
  List<Map<String, dynamic>> _allPatients = [];
  Map<int, bool> _predictingPatients = {};

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
      final overview = await _apiService.getAnalyticsOverview(
        widget.caregiverId,
      );
      final patients = await _apiService.getAtRiskPatients(widget.caregiverId);
      final allPatients = await _apiService.getCaregiverPatients(
        widget.caregiverId,
      );

      setState(() {
        _overview = overview;
        _riskPatients = patients;
        _allPatients = allPatients;
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
      final logs = await _apiService.getAdherenceLogs(patientId, limit: 3);
      final history = <int>[];
      for (var log in logs) {
        history.add(log.isTaken ? 1 : 0);
      }
      while (history.length < 3) {
        history.insert(0, 1);
      }
      return history.take(3).toList().reversed.toList();
    } catch (e) {
      print('Error fetching history: $e');
      return [1, 1, 1];
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

    List<int> history = await _fetchPatientHistory(patientId);
    String dayOfWeek = _getCurrentDayOfWeek();
    String timeOfDay = _getCurrentTimeOfDay();

    Navigator.pop(context); // Close loading dialog

    // Show prediction dialog
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isPredicting = false;
          Map<String, dynamic>? predictionResult;

          Future<void> runPrediction() async {
            setStateDialog(() => isPredicting = true);

            try {
              final result = await _apiService.predictAndSaveForPatient(
                patientId: patientId,
                age: age,
                dayOfWeek: dayOfWeek,
                timeOfDay: timeOfDay,
                history: history,
              );

              if (result.containsKey('error')) {
                throw Exception(result['error']);
              }

              predictionResult = result;
              setStateDialog(() => isPredicting = false);
              await _loadData();
            } catch (e) {
              setStateDialog(() => isPredicting = false);
              if (mounted) {
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
            title: Text('AI Prediction for $patientName'),
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
                          'Running LSTM model...',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 20),
                      ],
                    )
                  : predictionResult != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✅ Prediction Complete!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPredictionResultCard(
                          (predictionResult?['prediction_score'] as num?)
                                  ?.toDouble() ??
                              0.0,
                          predictionResult?['risk_level'] ?? 'LOW',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'This will run the LSTM model to predict:',
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
                                            color: value == 1
                                                ? Colors.green
                                                : Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              value == 1
                                                  ? Icons.check
                                                  : Icons.close,
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
            actions: predictionResult == null && !isPredicting
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
  }

  Widget _buildPredictionResultCard(double score, String riskLevel) {
    final riskColor = riskLevel == 'HIGH'
        ? Colors.redAccent
        : riskLevel == 'MEDIUM'
        ? Colors.orange
        : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [riskColor.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor.withOpacity(0.3)),
      ),
      child: Column(
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
                '${score.toStringAsFixed(1)}%',
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
            value: score / 100,
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
                ? '📊 Moderate risk. Monitor patient carefully.'
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
              label + ':',
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
      final success = await _apiService.predictAndSave(
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
              content: Text('✅ AI prediction completed successfully!'),
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
      final success = await _apiService.runBatchPrediction();

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

  // Navigate to patient profile
  void _navigateToPatientProfile(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PatientDetailPage(patient: patient),
      ),
    );
  }

  // Show all at-risk patients
  void _showAllAtRiskPatients() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'All At-Risk Patients',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _riskPatients.length,
                  itemBuilder: (context, index) {
                    final patient = _riskPatients[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            (patient['risk_level'] == 'HIGH'
                                    ? Colors.redAccent
                                    : Colors.orange)
                                .withOpacity(0.1),
                        child: Text(
                          (patient['name'] ?? '?')[0],
                          style: TextStyle(
                            color: patient['risk_level'] == 'HIGH'
                                ? Colors.redAccent
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(patient['name'] ?? 'Unknown'),
                      subtitle: Text(patient['medication'] ?? 'No medication'),
                      trailing: Chip(
                        label: Text(patient['risk_level'] ?? 'MEDIUM'),
                        backgroundColor:
                            (patient['risk_level'] == 'HIGH'
                                    ? Colors.redAccent
                                    : Colors.orange)
                                .withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: patient['risk_level'] == 'HIGH'
                              ? Colors.redAccent
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        final fullPatient = _allPatients.firstWhere(
                          (p) => p['full_name'] == patient['name'],
                          orElse: () => {},
                        );
                        if (fullPatient.isNotEmpty) {
                          _navigateToPatientProfile(fullPatient);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      backgroundColor: AppColors.scaffoldBackground,
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
                _buildLSTMHeaderCard(),
                const SizedBox(height: 24),
                _buildActionableInsights(),
                const SizedBox(height: 24),
                _buildBatchPredictionButton(),
                const SizedBox(height: 16),
                _buildAssignedPatientsList(),
                const SizedBox(height: 16),
                _buildRiskAnalysisList(),
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
              ? 'Running AI Analytics...'
              : 'Run AI Analytics for All Patients',
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
              final existingPrediction = _riskPatients.firstWhere(
                (p) => p['name'] == patient['full_name'],
                orElse: () => {},
              );
              final hasRiskLevel = existingPrediction['risk_level'] != null;
              return _buildPatientCard(
                patient,
                isPredicting,
                hasRiskLevel,
                existingPrediction,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(
    Map<String, dynamic> patient,
    bool isPredicting,
    bool hasRiskLevel,
    Map<String, dynamic> prediction,
  ) {
    final String patientName = patient['full_name'] ?? 'Unknown';
    final String? deviceSerial = patient['device_serial'];
    final int? batteryLevel = patient['battery_level'];

    String riskLevel = prediction['risk_level']?.toString() ?? 'Not analyzed';
    double predictionScore = 0.0;
    if (hasRiskLevel) {
      predictionScore = _toDouble(
        prediction['forget_probability'],
        defaultValue: 0.0,
      );
    }

    final Color riskColor = riskLevel == 'HIGH'
        ? Colors.redAccent
        : riskLevel == 'MEDIUM'
        ? Colors.orange
        : riskLevel == 'LOW'
        ? Colors.green
        : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: hasRiskLevel
            ? BorderSide(color: riskColor.withOpacity(0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToPatientProfile(patient),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
                    child: Text(
                      patientName.isNotEmpty
                          ? patientName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (deviceSerial != null)
                          Text(
                            'Device: $deviceSerial • Battery: ${batteryLevel ?? 'N/A'}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: (batteryLevel ?? 100) < 20
                                  ? Colors.red
                                  : Colors.grey.shade600,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_graph, size: 16),
                              SizedBox(width: 6),
                              Text('Predict'),
                            ],
                          ),
                  ),
                ],
              ),
              if (hasRiskLevel) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          riskLevel == 'HIGH'
                              ? Icons.warning
                              : riskLevel == 'MEDIUM'
                              ? Icons.trending_down
                              : Icons.check_circle,
                          size: 16,
                          color: riskColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Risk Level: $riskLevel',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: riskColor,
                              ),
                            ),
                            if (predictionScore > 0)
                              Text(
                                'Forget Probability: ${predictionScore.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // HEADER CARD
  Widget _buildLSTMHeaderCard() {
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
                  color: Colors.white.withOpacity(0.2),
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
                      'LSTM Model Status',
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
                color: Colors.white.withOpacity(0.3),
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
            color: color.withOpacity(0.1),
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
                  color: color.withOpacity(0.15),
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

  // RISK PATIENTS LIST
  Widget _buildRiskAnalysisList() {
    if (_riskPatients.isEmpty) {
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
              'No at-risk patients found.\nAll patients are stable.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Identified At-Risk Patients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              TextButton(
                onPressed: _showAllAtRiskPatients,
                child: const Text(
                  'See All',
                  style: TextStyle(color: AppColors.primaryPurple),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _riskPatients.length > 3 ? 3 : _riskPatients.length,
            itemBuilder: (context, index) {
              final patient = _riskPatients[index];
              return _buildPatientRiskCard(patient);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPatientRiskCard(Map<String, dynamic> patient) {
    final riskLevel = (patient['risk_level'] ?? 'MEDIUM')
        .toString()
        .toUpperCase();
    final isHighRisk = riskLevel == 'HIGH';
    final riskColor = isHighRisk ? Colors.redAccent : Colors.orange;
    final forgetProb = _toDouble(
      patient['forget_probability'],
      defaultValue: 50.0,
    );
    final temporalPattern =
        patient['temporal_pattern'] ?? 'Irregular pattern detected';

    final fullPatient = _allPatients.firstWhere(
      (p) => p['full_name'] == patient['name'],
      orElse: () => {},
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: riskColor.withOpacity(0.1),
                    child: Text(
                      (patient['name'] ?? '?')[0],
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        patient['medication'] ?? 'No medication',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  riskLevel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: AppColors.primaryPurple,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LSTM Assessment:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        temporalPattern,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Probability of missing next dose: ${forgetProb.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: riskColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (fullPatient.isNotEmpty) {
                      _showPredictionDialog(fullPatient);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh Prediction'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (fullPatient.isNotEmpty) {
                      _navigateToPatientProfile(fullPatient);
                    }
                  },
                  icon: const Icon(Icons.person_search_rounded, size: 16),
                  label: const Text('View Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                    side: const BorderSide(color: AppColors.primaryPurple),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
