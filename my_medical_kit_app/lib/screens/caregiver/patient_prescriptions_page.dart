// patient_prescriptions_page.dart
// Displays a list of prescriptions for a specific patient (used by caregiver view).
// Allows editing and deleting prescriptions via icon buttons. The data is fetched
// from the MedicationService API and displayed in a list with medication details
// like dosage, schedule, days, and inventory.

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';

import 'caregiver_dashboard_page.dart'; // (unused import – could be removed)

import 'edit_prescription_page.dart';

class PatientPrescriptionsPage extends StatefulWidget {
  final Map<String, dynamic> patient; // Patient data (contains patient_id)

  const PatientPrescriptionsPage({super.key, required this.patient});

  @override
  State<PatientPrescriptionsPage> createState() =>
      _PatientPrescriptionsPageState();
}

class _PatientPrescriptionsPageState extends State<PatientPrescriptionsPage> {
  List<Map<String, dynamic>> _prescriptions = []; // List of prescription maps
  bool _isLoading = true;
  String _error = '';

  // Helper to format a list of dispense times (e.g., ["08:00:00", "20:00:00"])
  // into a human-readable schedule (e.g., "8:00 AM, 8:00 PM").
  String _formatSchedule(List<dynamic> times) {
    if (times.isEmpty) return 'No schedule';
    final formattedTimes = times.map((t) {
      final parts = t.toString().split(':');
      if (parts.length >= 2) {
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        String period = h >= 12 ? 'PM' : 'AM';
        int displayHour = h % 12;
        if (displayHour == 0) displayHour = 12;
        return '$displayHour:${parts[1]} $period';
      }
      return t.toString();
    }).toList();
    return '${formattedTimes.join(', ')}';
  }

  // Helper to format a list of day numbers (1=Mon, 7=Sun) into day abbreviations.
  // If empty or null, returns 'Everyday'.
  String _formatDays(List<dynamic>? days) {
    if (days == null || days.isEmpty) return 'Everyday';

    final dayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    // Parse days to ints, filter valid range, sort.
    final sortedDays = days
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((d) => d > 0 && d <= 7)
        .toList();
    sortedDays.sort();

    return sortedDays.map((d) => dayNames[d]).join(', ');
  }

  @override
  void initState() {
    super.initState();
    _fetchPrescriptions(); // Load data when screen opens.
  }

  // Fetches prescriptions for the patient and updates state.
  Future<void> _fetchPrescriptions({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _isLoading = true;
      _error = '';
    });
    try {
      final prescriptions = await MedicationService().getPatientPrescriptions(
        widget.patient['patient_id'],
      );
      setState(() {
        _prescriptions = List<Map<String, dynamic>>.from(prescriptions);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Navigates to EditPrescriptionPage with the current prescription data.
  // Refreshes list if edit was successful.
  void _editPrescription(Map<String, dynamic> prescription) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPrescriptionPage(prescription: prescription),
      ),
    );
    if (result == true) {
      _fetchPrescriptions(); // Refresh after edit.
    }
  }

  // Shows a confirmation dialog and deletes the prescription if confirmed.
  Future<void> _deletePrescription(Map<String, dynamic> prescription) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Prescription'),
        content: Text(
          'Are you sure you want to delete "${prescription['medication_name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await MedicationService().deletePrescription(
      prescription['prescription_id'],
    );
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prescription deleted')));
      _fetchPrescriptions(); // Refresh list after deletion.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete prescription'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Prescription Detail',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFEFE8FA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            )
          : _error.isNotEmpty
          ? Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _prescriptions.isEmpty
          ? const Center(
              child: Text(
                'No active prescriptions found.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _fetchPrescriptions(showLoading: false),
              color: AppColors.primaryPurple,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _prescriptions.length,
                itemBuilder: (context, index) {
                  final rx = _prescriptions[index];
                  return Card(
                    color: Colors.white,
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryPurple,
                        child: Icon(Icons.medication, color: Colors.white),
                      ),
                      title: Text(
                        rx['medication_name'] ?? 'Unknown Med',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dosage: ${formatDosage(rx['dosage_tablet'])}',
                            ),
                            Text(
                              'Schedule: ${_formatSchedule(rx['dispense_times'] ?? [])}',
                            ),
                            Text('Days: ${_formatDays(rx['dispense_days'])}'),
                            Text(
                              'Inventory: ${rx['current_inventory'] ?? 0} left',
                            ),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit button
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.blue,
                            ),
                            onPressed: () => _editPrescription(rx),
                            tooltip: 'Edit',
                          ),
                          // Delete button
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _deletePrescription(rx),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
