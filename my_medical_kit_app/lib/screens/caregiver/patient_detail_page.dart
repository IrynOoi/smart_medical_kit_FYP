// patient_detail_page.dart
// Displays detailed information about a single patient (for caregiver view).
// Shows personal info, medical notes, and allows unlinking the patient.
// Also provides an edit button to navigate to EditPatientPage.

import 'package:my_medical_kit_app/services/api/api_client.dart';

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';

import 'edit_patient_page.dart';

class PatientDetailPage extends StatefulWidget {
  final Map<String, dynamic> patient; // Patient data to display
  final List<Map<String, dynamic>>
  allPatients; // List of all patients (for switching, though commented out)
  final int caregiverId; // Caregiver's ID (used for unlinking)

  const PatientDetailPage({
    super.key,
    required this.patient,
    required this.allPatients,
    required this.caregiverId,
  });

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  late Map<String, dynamic>
  patientData; // Mutable copy of patient data (can be updated)

  @override
  void initState() {
    super.initState();
    // Initialize state with the passed patient data
    patientData = Map<String, dynamic>.from(widget.patient);
  }

  // Helper to format a date string (YYYY-MM-DD) to DD/MM/YYYY.
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Not provided';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // Builds the profile photo widget (NetworkImage if available, otherwise initials).
  Widget _buildProfilePhoto() {
    final photoUrl = patientData['profile_photo'];
    if (photoUrl != null && photoUrl.toString().isNotEmpty) {
      final imageUrl = photoUrl.toString().startsWith('http')
          ? photoUrl.toString()
          : '${ApiClient.baseUrl}${photoUrl.toString().startsWith('/') ? '' : '/'}$photoUrl';

      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.transparent,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) {
          debugPrint('Failed to load profile image: $imageUrl');
        },
      );
    }

    // Fallback: initials circle if no photo.
    return CircleAvatar(
      radius: 50,
      backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.2),
      child: Text(
        patientData['full_name']?.substring(0, 1).toUpperCase() ?? '?',
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryPurple,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE8FA),
      appBar: AppBar(
        title: Text(patientData['full_name'] ?? 'Patient Details'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // (Commented out) Switch Patient popup menu – not used in current implementation.
          // PopupMenuButton<int>(
          //   tooltip: 'Switch Patient',
          //   onSelected: (newId) {
          //     final selected = widget.allPatients.firstWhere(
          //       (p) => p['patient_id'] == newId,
          //     );
          //     setState(() {
          //       patientData = Map<String, dynamic>.from(selected);
          //     });
          //   },
          //   itemBuilder: (context) {
          //     final otherPatients = widget.allPatients
          //         .where((p) => p['patient_id'] != patientData['patient_id'])
          //         .toList();
          //     if (otherPatients.isEmpty) {
          //       return [
          //         const PopupMenuItem<int>(
          //           value: -1,
          //           enabled: false,
          //           child: Text('No other patients found'),
          //         ),
          //       ];
          //     }
          //     return otherPatients.map((p) {
          //       return PopupMenuItem<int>(
          //         value: p['patient_id'],
          //         child: Text(p['full_name'] ?? 'Unknown Patient'),
          //       );
          //     }).toList();
          //   },
          // ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              // Navigate to EditPatientPage and wait for updated data.
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditPatientPage(patient: patientData),
                ),
              );

              // If we received updated data, update the UI immediately.
              if (result != null && result is Map<String, dynamic>) {
                setState(() {
                  patientData = result;
                });
              }
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFEFE8FA),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Center(child: _buildProfilePhoto()),
              const SizedBox(height: 16),
              // Personal Information card
              _buildInfoCard(
                title: 'Personal Information',
                icon: Icons.person,
                children: [
                  _infoRow('Full Name', patientData['full_name'] ?? '—'),
                  _infoRow('Email', patientData['email'] ?? '—'),
                  _infoRow('Phone', patientData['phone_no'] ?? '—'),
                  _infoRow('Address', patientData['address'] ?? '—'),
                  _infoRow('Gender', patientData['gender'] ?? '—'),
                  _infoRow(
                    'Date of Birth',
                    _formatDate(patientData['date_of_birth']),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Medical Information card
              _buildInfoCard(
                title: 'Medical Information',
                icon: Icons.health_and_safety,
                children: [
                  _infoRow(
                    'Medical Notes',
                    patientData['medical_notes'] ?? 'No notes',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Unlink Patient button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmUnlink,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Unlink Patient'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Shows a confirmation dialog before unlinking the patient.
  Future<void> _confirmUnlink() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Patient'),
        content: Text(
          'Are you sure you want to unlink ${patientData['full_name']} from your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;

      // Show loading spinner while unlinking.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Call the API to unlink the patient.
      final success = await CaregiverService().unlinkPatient(
        widget.caregiverId,
        patientData['patient_id'],
      );

      if (!mounted) return;
      Navigator.pop(context); // pop loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient unlinked successfully')),
        );
        Navigator.pop(
          context,
          true,
        ); // pop back to list page, returning true to refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unlink patient'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper to build a consistent information card with title and children.
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: Colors.white,
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

  // Helper to build a label-value row.
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
