//medication list page

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';

class CaregiverMedicationsListPage extends StatefulWidget {
  const CaregiverMedicationsListPage({super.key});

  @override
  State<CaregiverMedicationsListPage> createState() =>
      CaregiverMedicationsListPageState();
}

class CaregiverMedicationsListPageState
    extends State<CaregiverMedicationsListPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final meds = await _apiService.getMedications();
      setState(() {
        _medications = meds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ------------------------------------------------------------------
  // Add medication (already exists)
  // ------------------------------------------------------------------
  Future<void> _showAddMedicationDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Medication'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Medication Name',
              hintText: 'e.g. Paracetamol 500mg',
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed == true && formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final result = await _apiService.addMedication(controller.text.trim());
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medication added successfully')),
        );
        _fetchMedications();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add medication: ${result['message'] ?? result['error']}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------------
  // Edit medication
  // ------------------------------------------------------------------
  Future<void> _showEditDialog(Map<String, dynamic> medication) async {
    final controller = TextEditingController(
      text: medication['medication_name'],
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Medication'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Medication Name'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final result = await _apiService.updateMedication(
        medication['medication_id'],
        controller.text.trim(),
      );
      if (result['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Medication updated')));
        _fetchMedications();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${result['message'] ?? result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------------
  // Delete medication
  // ------------------------------------------------------------------
  Future<void> _confirmDelete(Map<String, dynamic> medication) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text(
          'Delete "${medication['medication_name']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      final result = await _apiService.deleteMedication(
        medication['medication_id'],
      );
      if (result['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Medication deleted')));
        _fetchMedications();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? result['error'] ?? 'Delete failed',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE8FA),
      appBar: AppBar(
        title: const Text(
          'Medications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMedicationDialog,
        backgroundColor: AppColors.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMedications,
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
                      onPressed: _fetchMedications,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _medications.isEmpty
            ? const Center(child: Text('No medications found in the system.'))
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _medications.length,
                itemBuilder: (_, i) {
                  final m = _medications[i];
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryPurple.withOpacity(
                          0.1,
                        ),
                        child: const Icon(
                          Icons.medication,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      title: Text(
                        m['medication_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(m),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(m),
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
