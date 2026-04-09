import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:my_medical_kit_app/theme/colors.dart';

class MedicationHistoryScreen extends StatefulWidget {
  const MedicationHistoryScreen({super.key});

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  final String serverIp = "172.20.10.9";

  Future<List<dynamic>> fetchLogs() async {
    final response = await http.get(
      Uri.parse('http://$serverIp:5000/get_logs'),
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['success']) {
        return jsonResponse['data'];
      } else {
        throw Exception(jsonResponse['error']);
      }
    } else {
      throw Exception(
        'Unable to connect to server. Code: ${response.statusCode}',
      );
    }
  }

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

      Navigator.pop(context);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to connect to AI: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Medical Kit 💊',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: fetchLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Connection failed: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No medication records available!',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final logList = snapshot.data!;
          return ListView.builder(
            itemCount: logList.length,
            itemBuilder: (context, index) {
              var log = logList[index];
              String displayTime = log['timestamp'] ?? 'Unknown time';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(
                    log['status'] == 1 ? Icons.check_circle : Icons.cancel,
                    color: log['status'] == 1 ? AppColors.primaryPurple : Colors.red,
                    size: 48,
                  ),
                  title: Text(
                    log['status'] == 1 ? 'Medication Taken' : 'Missed Medication',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Recorded Time: $displayTime\n'
                      'Schedule: ${log['day_of_week']} ${log['time_of_day']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _askAIDoctor,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.psychology, color: Colors.white),
        label: const Text(
          'Ask AI',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
