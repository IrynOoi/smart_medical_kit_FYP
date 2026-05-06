//caregiver_patients_list_page.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';

import 'patient_detail_page.dart';
import 'add_patient_page.dart';

class CaregiverPatientsListPage extends StatefulWidget {
  final int caregiverId;
  const CaregiverPatientsListPage({super.key, required this.caregiverId});

  @override
  State<CaregiverPatientsListPage> createState() =>
      CaregiverPatientsListPageState();
}

class CaregiverPatientsListPageState extends State<CaregiverPatientsListPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _confirmDelete(int patientId, String patientName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text(
          'Are you sure you want to permanently delete $patientName?',
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

    if (confirm == true) {
      // Show loading indicator (optional)
      setState(() => _isLoading = true);
      final success = await _apiService.deletePatient(patientId);
      setState(() => _isLoading = false);

      if (success) {
        // Remove patient from local list
        setState(() {
          _patients.removeWhere((p) => p['patient_id'] == patientId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete patient'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPatientAvatar(Map<String, dynamic> patient) {
    final photoUrl = patient['profile_photo'];
    if (photoUrl != null && photoUrl.toString().isNotEmpty) {
      final imageUrl = photoUrl.toString().startsWith('http')
          ? photoUrl.toString()
          : '${ApiService.baseUrl}${photoUrl.toString().startsWith('/') ? '' : '/'}$photoUrl';
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) =>
            debugPrint('Failed to load image: $imageUrl'),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
      child: Text(
        patient['full_name']?.substring(0, 1).toUpperCase() ?? '?',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.primaryPurple,
        ),
      ),
    );
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final patients = await _apiService.getCaregiverPatients(
        widget.caregiverId,
      );
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getAge(String? dob) {
    if (dob == null || dob.isEmpty) return 'N/A';
    try {
      final birthDate = DateTime.parse(dob);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age.toString();
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE8FA),
      appBar: AppBar(
        title: const Text(
          'Patients List',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AddPatientPage(caregiverId: widget.caregiverId),
                ),
              );
              if (result == true) _fetchPatients();
            },
            tooltip: 'Add Patient',
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFEFE8FA),
        child: RefreshIndicator(
          onRefresh: _fetchPatients,
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
                        onPressed: _fetchPatients,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _patients.isEmpty
              ? const Center(child: Text('No patients assigned.'))
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _patients.length,
                  itemBuilder: (_, i) {
                    final p = _patients[i];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ), // 👈 ADD THIS LINE
                        leading: _buildPatientAvatar(p),
                        title: Text(
                          p['full_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Age: ${_getAge(p['date_of_birth'])}'),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              _confirmDelete(p['patient_id'], p['full_name']),
                          tooltip: 'Delete Patient',
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientDetailPage(patient: p),
                            ),
                          );
                          _fetchPatients();
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
