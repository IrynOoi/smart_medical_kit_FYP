// caregiver_patients_list_page.dart
// Displays the list of patients linked to a caregiver, with options to filter,
// view details, deactivate/reactivate, permanently delete, and link new patients.
// Also provides an "Add Patient" button to create a new patient account.

import 'package:my_medical_kit_app/services/api/api_client.dart';

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';

import 'patient_detail_page.dart';
import 'add_patient_page.dart';

// Stateful widget for the caregiver's patient list.
class CaregiverPatientsListPage extends StatefulWidget {
  final int caregiverId; // ID of the logged-in caregiver

  const CaregiverPatientsListPage({super.key, required this.caregiverId});

  @override
  State<CaregiverPatientsListPage> createState() =>
      CaregiverPatientsListPageState();
}

class CaregiverPatientsListPageState extends State<CaregiverPatientsListPage> {
  // Lists of patients
  List<Map<String, dynamic>> _patients =
      []; // Patients already linked to this caregiver
  List<Map<String, dynamic>> _availablePatients =
      []; // Unlinked patients available to link

  int? _selectedPatientId; // Currently selected patient ID in the dropdown
  bool _isLoading = true; // Main loading flag
  bool _isLinking = false; // Flag for the linking operation
  String _statusFilter =
      'all'; // Filter for linked patients: 'active', 'inactive', 'all'
  String _error = '';
  String _availableFilter =
      'all'; // Filter for available patients: 'all', 'active', 'inactive'
  bool _isLoadingAvailable = false; // Loading flag for available patients list

  @override
  void initState() {
    super.initState();
    _fetchPatients(); // Load data when the screen is created
  }

  // Shows a confirmation dialog for deactivating a patient (soft delete).
  Future<void> _confirmDelete(int patientId, String patientName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Patient'),
        content: Text(
          'Are you sure you want to deactivate $patientName? This will disable their account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await PatientService().deletePatient(patientId);
      setState(() => _isLoading = false);

      if (success) {
        // Remove patient from local list
        setState(() {
          _patients.removeWhere((p) => p['patient_id'] == patientId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient deactivated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to deactivate patient'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fetches the list of patients available to be linked to this caregiver,
  // respecting the current _availableFilter.
  Future<void> _fetchAvailablePatients() async {
    setState(() => _isLoadingAvailable = true);
    final available = await CaregiverService().getAvailablePatients(
      widget.caregiverId,
      status: _availableFilter,
    );
    setState(() {
      _availablePatients = available;
      _isLoadingAvailable = false;
      _selectedPatientId = null; // Clear any selected ID after refresh
    });
  }

  // Builds the patient avatar CircleAvatar (with photo or initials).
  Widget _buildPatientAvatar(Map<String, dynamic> patient) {
    final photoUrl = patient['profile_photo'];
    if (photoUrl != null && photoUrl.toString().isNotEmpty) {
      final imageUrl = photoUrl.toString().startsWith('http')
          ? photoUrl.toString()
          : '${ApiClient.baseUrl}${photoUrl.toString().startsWith('/') ? '' : '/'}$photoUrl';
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) =>
            debugPrint('Failed to load image: $imageUrl'),
      );
    }
    // Fallback: display initials.
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
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

  // Shows confirmation dialog and calls reactivation API.
  Future<void> _confirmReactivate(int patientId, String patientName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivate Patient'),
        content: Text(
          'Reactivate $patientName? They will reappear in the active list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await PatientService().reactivatePatient(patientId);
      setState(() => _isLoading = false);

      if (success) {
        await _fetchPatients(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Patient reactivated')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to reactivate patient'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Fetches the list of linked patients for this caregiver with the current filter.
  Future<void> _fetchPatients({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _isLoading = true;
      _error = '';
    });
    try {
      final patients = await CaregiverService().getCaregiverPatients(
        widget.caregiverId,
        show: _statusFilter,
      );
      final available = await CaregiverService().getAvailablePatients(
        widget.caregiverId,
      );
      setState(() {
        _patients = patients;
        _availablePatients = available;
        _selectedPatientId = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Links the selected patient to this caregiver.
  Future<void> _linkPatient() async {
    if (_selectedPatientId == null) return;
    setState(() => _isLinking = true);
    try {
      final success = await CaregiverService().linkPatient(
        widget.caregiverId,
        _selectedPatientId!,
      );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient linked successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Refresh both lists after linking.
        await _fetchPatients();
        await _fetchAvailablePatients();
      } else {
        throw Exception('Failed to link patient');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  // Helper to compute age from date of birth.
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

  // Shows confirmation for deactivating (soft-deleting) a patient.
  Future<void> _confirmDeactivate(int patientId, String patientName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Patient'),
        content: Text(
          'Deactivate $patientName? They will be hidden from the active list but can be reactivated later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await PatientService().deletePatient(patientId);
      setState(() => _isLoading = false);

      if (success) {
        setState(() {
          _patients.removeWhere((p) => p['patient_id'] == patientId);
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Patient deactivated')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to deactivate patient'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Shows confirmation for permanent (hard) deletion of a patient.
  Future<void> _confirmHardDelete(int patientId, String patientName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient Permanently'),
        content: Text(
          'This will permanently remove $patientName and ALL their data '
          '(prescriptions, logs, AI predictions, etc.). This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await PatientService().deletePatient(
        patientId,
        hard: true,
      );
      setState(() => _isLoading = false);

      if (success) {
        setState(() {
          _patients.removeWhere((p) => p['patient_id'] == patientId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient permanently deleted')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete patient'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Builds the dropdown for linking a new patient (with status filter and link button).
  Widget _buildLinkPatientDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Find Other Patient',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(height: 12),
            // Status filter for available patients (All, Active, Inactive)
            Row(
              children: [
                const Text('Show: ', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('All')),
                      ButtonSegment(value: 'active', label: Text('Active')),
                      ButtonSegment(value: 'inactive', label: Text('Inactive')),
                    ],
                    selected: {_availableFilter},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _availableFilter = newSelection.first;
                      });
                      _fetchAvailablePatients(); // Refresh with new filter
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.primaryPurple;
                        }
                        return Colors.grey.shade200;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return Colors.black87;
                      }),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Patient dropdown (list already filtered)
            if (_isLoadingAvailable)
              const Center(child: CircularProgressIndicator())
            else if (_availablePatients.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _availableFilter == 'inactive'
                          ? 'No inactive unlinked patients.'
                          : 'No unlinked patients available.',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Select a patient',
                      ),
                      initialValue: _selectedPatientId,
                      items: _availablePatients.map((p) {
                        final bool isActive =
                            p['is_active'] == 1 || p['is_active'] == true;
                        final String statusText = isActive ? '' : ' (INACTIVE)';
                        return DropdownMenuItem<int>(
                          value: p['patient_id'],
                          child: Text(
                            '${p['full_name']} (${p['email']})$statusText',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedPatientId = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Link button
                  ElevatedButton(
                    onPressed: _isLinking || _selectedPatientId == null
                        ? null
                        : _linkPatient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                    ),
                    child: _isLinking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Link'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Builds the header for the linked patients list (title + filter popup).
  Widget _buildPatientsListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'My Patients',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.primaryPurple,
            ),
          ),
          // Filter popup menu for the linked patients list.
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list,
              color: _statusFilter == 'active'
                  ? AppColors.primaryPurple
                  : Colors.grey,
            ),
            tooltip: 'Filter patients',
            onSelected: (value) {
              setState(() => _statusFilter = value);
              _fetchPatients();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'active', child: Text('Active')),
              const PopupMenuItem(value: 'inactive', child: Text('Inactive')),
              const PopupMenuItem(value: 'all', child: Text('All')),
            ],
          ),
        ],
      ),
    );
  }

  // (Commented out) Alternative filter chip implementation – not used.
  // Widget _buildFilterChip(String label, String value) { ... }

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
          // Add Patient button – navigates to AddPatientPage.
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
          onRefresh: () => _fetchPatients(showLoading: false),
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
              : Column(
                  children: [
                    _buildLinkPatientDropdown(),
                    _buildPatientsListHeader(),
                    Expanded(
                      child: _patients.isEmpty
                          ? const Center(child: Text('No patients assigned.'))
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: _patients.length,
                              itemBuilder: (_, i) {
                                final p = _patients[i];
                                // Determine active status (defaults to active if missing)
                                final bool isActive =
                                    (p['is_active'] ?? 1) == 1;

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
                                    ),
                                    leading: _buildPatientAvatar(p),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p['full_name'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Active/Inactive badge
                                        if (isActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'ACTIVE',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'INACTIVE',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      'Age: ${_getAge(p['date_of_birth'])}',
                                    ),
                                    // Three-dot popup menu: Deactivate/Reactivate/Delete Permanently
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Colors.grey,
                                      ),
                                      onSelected: (value) {
                                        if (value == 'deactivate') {
                                          _confirmDeactivate(
                                            p['patient_id'],
                                            p['full_name'],
                                          );
                                        } else if (value == 'reactivate') {
                                          _confirmReactivate(
                                            p['patient_id'],
                                            p['full_name'],
                                          );
                                        } else if (value == 'delete') {
                                          _confirmHardDelete(
                                            p['patient_id'],
                                            p['full_name'],
                                          );
                                        }
                                      },
                                      itemBuilder: (context) {
                                        final items = <PopupMenuItem<String>>[];
                                        if (isActive) {
                                          items.add(
                                            const PopupMenuItem(
                                              value: 'deactivate',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.block,
                                                    color: Colors.orange,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Deactivate'),
                                                ],
                                              ),
                                            ),
                                          );
                                        } else {
                                          items.add(
                                            const PopupMenuItem(
                                              value: 'reactivate',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.restore,
                                                    color: Colors.green,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Reactivate'),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                        items.add(
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_forever,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Delete Permanently'),
                                              ],
                                            ),
                                          ),
                                        );
                                        return items;
                                      },
                                    ),
                                    onTap: () async {
                                      // Navigate to patient detail page.
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PatientDetailPage(
                                            patient: p,
                                            allPatients: _patients,
                                            caregiverId: widget.caregiverId,
                                          ),
                                        ),
                                      );
                                      _fetchPatients(); // Refresh after returning.
                                    },
                                  ),
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
}
