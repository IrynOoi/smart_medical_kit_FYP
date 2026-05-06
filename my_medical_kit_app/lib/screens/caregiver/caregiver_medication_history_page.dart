//caregiver_medication_history_page.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicationHistoryScreen extends StatefulWidget {
  const MedicationHistoryScreen({super.key});

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  final ApiService _apiService = ApiService();
  final String serverIp = "172.20.10.9";

  List<Map<String, dynamic>> _alerts = [];
  int _totalDoses = 0;
  bool _isLoading = true;
  String _error = '';
  int _caregiverId = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Fetch the caregiverId from session since this is a Bottom Nav tab
      final prefs = await SharedPreferences.getInstance();
      _caregiverId = prefs.getInt('caregiver_id') ?? 0;

      if (_caregiverId == 0) {
        setState(() {
          _error = 'Session error. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      // Fetch data using the robust ApiService
      final overview = await _apiService.getCaregiverOverview(_caregiverId);
      final allLogs = await _apiService.getAllRecentLogs(_caregiverId);

      setState(() {
        _totalDoses = overview['total_doses'] ?? 0;
        _alerts = allLogs; // Contains TAKEN + MISSED + PENDING
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /*
  Future<void> _askAIDoctor() async {
    final String apiUrl = "http://$serverIp:5000/predict";
    final Map<String, dynamic> patientData = {
      "age": 78,
      "day_of_week": "Friday",
      "time_of_day": "Evening",
      "history": [1, 0, 1],
    };

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(patientData),
      );

      if (!context.mounted) return;
      Navigator.pop(context);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _showResultDialog(
          probability: result['forget_probability'],
          level: result['warning_level'],
          message: result['message'],
        );
      } else {
        throw Exception("Server error code: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to connect to AI: $e')));
      }
    }
  }

  void _showResultDialog({
    required double probability,
    required String level,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧠 AI Prediction Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Probability of forgetting medication: ${(probability * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Warning Level: $level',
              style: TextStyle(
                color: level == 'High' ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text('System Recommendation: $message'),
          ],
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
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Doses Taken & History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _initializeData,
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
                      onPressed: _initializeData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Total Doses Card
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // List of Logs
                  Expanded(
                    child: _alerts.isEmpty
                        ? const Center(
                            child: Text(
                              'No recent dose records',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _alerts.length,
                            itemBuilder: (_, i) {
                              final act = _alerts[i];
                              final isTaken = act['status'] == 'TAKEN';
                              final isMissed = act['status'] == 'MISSED';

                              Color iconColor =
                                  Colors.orange; // Default pending
                              IconData iconData = Icons.access_time_filled;

                              if (isTaken) {
                                iconColor = Colors.green;
                                iconData = Icons.check_circle;
                              } else if (isMissed) {
                                iconColor = Colors.red;
                                iconData = Icons.cancel;
                              }

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    iconData,
                                    color: iconColor,
                                    size: 32,
                                  ),
                                  title: Text(
                                    act['patient_name'] ?? 'Patient',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${act['medication_name'] ?? 'Medication'} - ${act['status'] ?? 'Unknown'}',
                                  ),
                                  trailing: Text(
                                    act['scheduled_time'] != null
                                        ? DateTime.parse(act['scheduled_time'])
                                              .toLocal()
                                              .toString()
                                              .substring(0, 16)
                                        : '',
                                    style: const TextStyle(fontSize: 12),
                                  ),
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
