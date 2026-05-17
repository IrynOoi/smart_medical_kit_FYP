//caregiver_doses_details_page.dart

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';

class CaregiverDosesDetailsPage extends StatefulWidget {
  final int caregiverId;
  const CaregiverDosesDetailsPage({super.key, required this.caregiverId});

  @override
  State<CaregiverDosesDetailsPage> createState() =>
      CaregiverDosesDetailsPageState();
}

class CaregiverDosesDetailsPageState extends State<CaregiverDosesDetailsPage> {
  
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
      final overview = await CaregiverService().getCaregiverOverview(
        widget.caregiverId,
      );
      final allLogs = await CaregiverService().getAllRecentLogs(widget.caregiverId);
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
