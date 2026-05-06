//caregiver_prescription_setup_page.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';
import 'patient_prescriptions_page.dart';

class CaregiverPrescriptionSetupPage extends StatefulWidget {
  final int caregiverId;
  const CaregiverPrescriptionSetupPage({super.key, required this.caregiverId});

  @override
  State<CaregiverPrescriptionSetupPage> createState() =>
      _CaregiverPrescriptionSetupPageState();
}

class _CaregiverPrescriptionSetupPageState
    extends State<CaregiverPrescriptionSetupPage> {
  final ApiService _apiService = ApiService();
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

  void _openPrescriptionForm(Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PrescriptionFormSheet(patient: patient),
    );
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
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.primaryPurple
                                .withOpacity(0.1),
                            child: Text(
                              p['full_name']?.substring(0, 1).toUpperCase() ??
                                  '?',
                              style: const TextStyle(
                                color: AppColors.primaryPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['full_name'] ?? 'Unknown Patient',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Device: ${p['device_serial'] ?? 'Not Paired'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openPrescriptionForm(p),
                            icon: const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Set prescription",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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

// ----------------------------------------------------------------------
//  Nested Prescription Form Sheet (with medication dropdown & improved logic)
// ----------------------------------------------------------------------
class PrescriptionFormSheet extends StatefulWidget {
  final Map<String, dynamic> patient;
  const PrescriptionFormSheet({super.key, required this.patient});

  @override
  State<PrescriptionFormSheet> createState() => _PrescriptionFormSheetState();
}

class _PrescriptionFormSheetState extends State<PrescriptionFormSheet> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _medications = [];
  String? _selectedMedicationName;
  final TextEditingController _dosageController = TextEditingController(
    text: '1.0',
  );
  final TextEditingController _scheduleController = TextEditingController(
    text: '0 8 * * *',
  );
  final TextEditingController _inventoryController = TextEditingController(
    text: '30',
  );
  final TextEditingController _thresholdController = TextEditingController(
    text: '10',
  );
  final TextEditingController _deviceIdController = TextEditingController();

  bool _isLoadingMedications = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    setState(() {
      _isLoadingMedications = true;
      _errorMessage = null;
    });
    try {
      final meds = await _apiService.getMedications();
      setState(() {
        _medications = meds;
        if (_medications.isNotEmpty) {
          _selectedMedicationName = _medications.first['medication_name'];
        }
        _isLoadingMedications = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load medications: $e';
        _isLoadingMedications = false;
      });
    }
  }

  Future<void> _savePrescription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMedicationName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a medication')),
      );
      return;
    }
    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No medications available. Add a medication first.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final data = {
      'patient_id': widget.patient['patient_id'],
      'medication_name': _selectedMedicationName,
      'dosage_tablet': double.tryParse(_dosageController.text) ?? 1.0,
      'dispense_schedule': _scheduleController.text.trim(),
      'current_inventory': int.tryParse(_inventoryController.text) ?? 0,
      'refill_threshold': int.tryParse(_thresholdController.text) ?? 5,
      'start_date': DateTime.now().toIso8601String().split('T')[0],
      'device_id': _deviceIdController.text.trim().isEmpty
          ? null
          : int.tryParse(_deviceIdController.text),
    };

    print('📤 Sending prescription: $data'); // Debug log

    final response = await _apiService.addPrescription(data);
    setState(() => _isSaving = false);

    print('📥 Response: $response'); // Debug log

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription added successfully')),
      );
      Navigator.pop(context);
    } else {
      String errorMsg =
          response['message'] ?? response['error'] ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Prescription',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_isLoadingMedications)
                const CircularProgressIndicator()
              else if (_medications.isEmpty)
                const Text(
                  'No medications found. Please add a medication first.',
                  style: TextStyle(color: Colors.red),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedMedicationName,
                  items: _medications.map((med) {
                    return DropdownMenuItem<String>(
                      value: med['medication_name'],
                      child: Text(med['medication_name']),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _selectedMedicationName = val),
                  decoration: const InputDecoration(
                    labelText: 'Medication *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null ? 'Select a medication' : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage (tablets)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null
                    ? 'Invalid number'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _scheduleController,
                decoration: const InputDecoration(
                  labelText: 'Schedule (cron)',
                  hintText: 'e.g. 0 8 * * *',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _inventoryController,
                decoration: const InputDecoration(
                  labelText: 'Initial Inventory',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || int.tryParse(v) == null
                    ? 'Number required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _thresholdController,
                decoration: const InputDecoration(
                  labelText: 'Refill Threshold',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || int.tryParse(v) == null
                    ? 'Number required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Device ID (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed:
                    (_isLoadingMedications || _medications.isEmpty || _isSaving)
                    ? null
                    : _savePrescription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Prescription'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
