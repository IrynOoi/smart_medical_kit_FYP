//patient_detail_page.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';

import 'edit_patient_page.dart';

class PatientDetailPage extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientDetailPage({super.key, required this.patient});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  late Map<String, dynamic> patientData;

  @override
  void initState() {
    super.initState();
    // Initialize state with the passed patient data
    patientData = Map<String, dynamic>.from(widget.patient);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Not provided';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildProfilePhoto() {
    final photoUrl = patientData['profile_photo'];
    if (photoUrl != null && photoUrl.toString().isNotEmpty) {
      final imageUrl = photoUrl.toString().startsWith('http')
          ? photoUrl.toString()
          : '${ApiService.baseUrl}${photoUrl.toString().startsWith('/') ? '' : '/'}$photoUrl';

      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.transparent,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) {
          debugPrint('Failed to load profile image: $imageUrl');
        },
      );
    }

    return CircleAvatar(
      radius: 50,
      backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
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
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              // Wait for the updated data from EditPatientPage
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditPatientPage(patient: patientData),
                ),
              );

              // If we received updated data, update the UI immediately
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
              const SizedBox(height: 16),
            ],
          ),
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
