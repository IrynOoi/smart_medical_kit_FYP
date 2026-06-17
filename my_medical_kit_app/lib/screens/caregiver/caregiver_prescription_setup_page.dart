//caregiver_prescription_setup_page.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';
import 'patient_prescriptions_page.dart';
import 'package:my_medical_kit_app/services/api/api_client.dart';
import 'add_prescription_page.dart';

class CaregiverPrescriptionSetupPage extends StatefulWidget {
  final int caregiverId;
  const CaregiverPrescriptionSetupPage({super.key, required this.caregiverId});

  @override
  State<CaregiverPrescriptionSetupPage> createState() =>
      _CaregiverPrescriptionSetupPageState();
}

class _CaregiverPrescriptionSetupPageState
    extends State<CaregiverPrescriptionSetupPage> {
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final patients = await CaregiverService().getCaregiverPatients(
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

  void _openPrescriptionForm(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddPrescriptionPage(patient: patient)),
    ).then((_) => _fetchPatients());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Prescription Setup',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFEFE8FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _patients.isEmpty
          ? const Center(
              child: Text(
                'No patients assigned to manage.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _patients.length,
              itemBuilder: (context, index) {
                final p = _patients[index];
                return Card(
                  color: Colors.white,
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientPrescriptionsPage(patient: p),
                        ),
                      ).then((_) => _fetchPatients());
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.primaryPurple.withValues(
                              alpha: 0.1,
                            ),
                            // 1. Add backgroundImage to render the image
                            backgroundImage:
                                (p['profile_photo'] != null &&
                                    p['profile_photo'].toString().isNotEmpty)
                                ? NetworkImage(
                                    p['profile_photo'].toString().startsWith(
                                          'http',
                                        )
                                        ? p['profile_photo']
                                        : '${ApiClient.baseUrl}${p['profile_photo'].toString().startsWith('/') ? '' : '/'}${p['profile_photo']}',
                                  )
                                : null,
                            // 2. Keep the Text as a fallback ONLY if no image exists
                            child:
                                (p['profile_photo'] == null ||
                                    p['profile_photo'].toString().isEmpty)
                                ? Text(
                                    p['full_name']
                                            ?.substring(0, 1)
                                            .toUpperCase() ??
                                        '?',
                                    style: const TextStyle(
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12), // Reduced spacing
                          // Text Column - Now Expanded to handle overflow
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['full_name'] ?? 'Unknown Patient',
                                  style: const TextStyle(
                                    fontSize:
                                        15, // Slightly reduced to fit more
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${p['prescription_count'] ?? 0} active prescription', // Simplified label
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Action Button - Removed icon to maximize space
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _openPrescriptionForm(p),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Add",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
