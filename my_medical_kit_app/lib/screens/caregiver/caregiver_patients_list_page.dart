//caregiver_patients_list_page.dart
import 'package:my_medical_kit_app/services/api/api_client.dart';

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';

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
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _availablePatients = [];
  int? _selectedPatientId;
  bool _isLoading = true;
  bool _isLinking = false;
  String _statusFilter = 'all'; // 'active', 'inactive', 'all'
  String _error = '';
  String _availableFilter = 'all'; // 'all', 'active', 'inactive'
  bool _isLoadingAvailable = false;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

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
      // Show loading indicator (optional)
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

  Future<void> _fetchAvailablePatients() async {
    setState(() => _isLoadingAvailable = true);
    final available = await CaregiverService().getAvailablePatients(
      widget.caregiverId,
      status: _availableFilter,
    );
    setState(() {
      _availablePatients = available;
      _isLoadingAvailable = false;
      _selectedPatientId = null; // 清空选中
    });
  }

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
        await _fetchPatients(); // refresh list
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

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final patients = await CaregiverService().getCaregiverPatients(
        widget.caregiverId,
        show: _statusFilter, // <-- use the filter
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
        // 刷新两个列表：已关联患者列表 和 可用患者列表
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
            // 添加状态筛选控件
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
                      _fetchAvailablePatients(); // 根据新筛选条件刷新列表
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
            // 患者下拉框（根据 _availableFilter 已过滤）
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
                      value: _selectedPatientId,
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

  // Widget _buildFilterChip(String label, String value) {
  //   final isSelected = _statusFilter == value;
  //   return ChoiceChip(
  //     label: Text(label),
  //     selected: isSelected,
  //     onSelected: (selected) {
  //       if (selected) {
  //         setState(() => _statusFilter = value);
  //         _fetchPatients();
  //       }
  //     },
  //     selectedColor: AppColors.primaryPurple.withOpacity(0.2),
  //     labelStyle: TextStyle(
  //       color: isSelected ? AppColors.primaryPurple : Colors.grey,
  //       fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
  //     ),
  //     backgroundColor: Colors.white,
  //     side: BorderSide(
  //       color: isSelected ? AppColors.primaryPurple : Colors.grey.shade300,
  //     ),
  //   );
  // }

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
                                // Default to 1 (active) if is_active is missing
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
                                      _fetchPatients();
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
