//lib//screens/caregiver/edit_prescription_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';

class EditPrescriptionPage extends StatefulWidget {
  final Map<String, dynamic> prescription;

  const EditPrescriptionPage({super.key, required this.prescription});

  @override
  State<EditPrescriptionPage> createState() => _EditPrescriptionPageState();
}

class _EditPrescriptionPageState extends State<EditPrescriptionPage> {
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _medications = [];
  String? _selectedMedicationName;
  late TextEditingController _dosageController;

  // 🚫 Removed: _inventoryController, _thresholdController, _deviceIdController

  List<TimeOfDay> _selectedTimes = [];
  List<int> _selectedDays = [];

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  bool _isLoadingMedications = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initFields();
    _fetchMedications();
  }

  void _initFields() {
    final rx = widget.prescription;
    _selectedMedicationName = rx['medication_name'];
    _dosageController = TextEditingController(
      text: (rx['dosage_tablet'] ?? 1.0).toString(),
    );
    // 🚫 No inventory, threshold, device ID controllers

    if (rx['start_date'] != null) {
      _startDate =
          DateTime.tryParse(rx['start_date'].toString()) ?? DateTime.now();
    }
    if (rx['end_date'] != null) {
      _endDate = DateTime.tryParse(rx['end_date'].toString());
    }

    _selectedTimes.clear();
    if (rx['dispense_times'] != null) {
      final List<dynamic> times = rx['dispense_times'];
      for (var timeStr in times) {
        final parts = timeStr.toString().split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]) ?? 8;
          final minute = int.tryParse(parts[1]) ?? 0;
          _selectedTimes.add(TimeOfDay(hour: hour, minute: minute));
        }
      }
    }
    if (_selectedTimes.isEmpty) {
      _selectedTimes.add(const TimeOfDay(hour: 8, minute: 0));
    }

    _selectedDays.clear();
    if (rx['dispense_days'] != null) {
      final List<dynamic> days = rx['dispense_days'];
      _selectedDays.addAll(days.map((d) => int.tryParse(d.toString()) ?? 1));
      _selectedDays.sort();
    }
  }

  @override
  void dispose() {
    _dosageController.dispose();
    // 🚫 No other controllers to dispose
    super.dispose();
  }

  Future<void> _fetchMedications() async {
    setState(() {
      _isLoadingMedications = true;
      _errorMessage = null;
    });
    try {
      final meds = await MedicationService().getMedications();
      setState(() {
        _medications = meds.cast<Map<String, dynamic>>();
        if (_selectedMedicationName != null) {
          final exists = _medications.any(
            (m) => m['medication_name'] == _selectedMedicationName,
          );
          if (!exists) _selectedMedicationName = null;
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

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
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

    try {
      // 从 widget.prescription 获取 patient_id（需确保字段存在）
      final patientId =
          widget.prescription['patient_id'] ?? widget.prescription['patientId'];
      if (patientId == null) {
        throw Exception('Patient ID not found in prescription data');
      }

      final existing = await MedicationService().getPatientMedications(
        patientId,
      );
      final currentPrescriptionId = widget.prescription['prescription_id'];

      final hasDuplicate = existing.any((p) {
        // 排除自身
        if (p.prescriptionId == currentPrescriptionId) return false;
        // 只检查未结束的处方（end_date 为 null 或 >= 今天）
        if (p.endDate != null && p.endDate!.isBefore(DateTime.now()))
          return false;
        return p.medicationName == _selectedMedicationName;
      });

      if (hasDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ This medication has already been prescribed to this patient.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not verify duplicates: $e')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final List<String> dispenseTimes = _selectedTimes.map((t) {
      final hour = t.hour.toString().padLeft(2, '0');
      final minute = t.minute.toString().padLeft(2, '0');
      return '$hour:$minute:00';
    }).toList();

    final DateFormat formatter = DateFormat('yyyy-MM-dd');

    final data = {
      'medication_name': _selectedMedicationName,
      'dosage_tablet': double.tryParse(_dosageController.text) ?? 1.0,
      'dispense_times': dispenseTimes,
      'dispense_days': _selectedDays,
      'start_date': formatter.format(_startDate),
      'end_date': _endDate != null ? formatter.format(_endDate!) : null,
      // 🚫 Do NOT send inventory, threshold, device_id – backend keeps existing values
    };

    final result = await MedicationService().updatePrescription(
      widget.prescription['prescription_id'],
      data,
    );
    final success = result['success'] == true;
    setState(() => _isSaving = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update prescription'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Edit Prescription',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingMedications
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            )
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Medication Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Medication *',
                        prefixIcon: const Icon(Icons.medication),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      initialValue: _selectedMedicationName,
                      items: _medications
                          .map(
                            (med) => DropdownMenuItem(
                              value: med['medication_name'].toString(),
                              child: Text(med['medication_name']),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedMedicationName = val),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Dosage
                    TextFormField(
                      controller: _dosageController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Dosage (Tablets) *',
                        prefixIcon: const Icon(Icons.vaccines),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Required'
                          : (double.tryParse(v) == null
                                ? 'Invalid number'
                                : null),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Dispense Times',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: _selectedTimes.asMap().entries.map((entry) {
                        int index = entry.key;
                        TimeOfDay time = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  tileColor: Colors.grey.shade100,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: const Icon(
                                    Icons.access_time,
                                    color: AppColors.primaryPurple,
                                  ),
                                  title: Text(
                                    time.format(context),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.primaryPurple,
                                    ),
                                  ),
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: time,
                                    );
                                    if (picked != null) {
                                      setState(
                                        () => _selectedTimes[index] = picked,
                                      );
                                    }
                                  },
                                ),
                              ),
                              if (_selectedTimes.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _selectedTimes.removeAt(index),
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 8, minute: 0),
                        );
                        if (picked != null) {
                          setState(() => _selectedTimes.add(picked));
                        }
                      },
                      icon: const Icon(
                        Icons.add,
                        color: AppColors.primaryPurple,
                      ),
                      label: const Text(
                        'Add Time',
                        style: TextStyle(color: AppColors.primaryPurple),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Days of the Week',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If no days are selected, it will default to Everyday.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: [
                        _buildDayChip('Mon', 1),
                        _buildDayChip('Tue', 2),
                        _buildDayChip('Wed', 3),
                        _buildDayChip('Thu', 4),
                        _buildDayChip('Fri', 5),
                        _buildDayChip('Sat', 6),
                        _buildDayChip('Sun', 7),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Start & End Dates
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Date *',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _selectDate(context, true),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat(
                                          'MMM dd, yyyy',
                                        ).format(_startDate),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End Date',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _selectDate(context, false),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event_busy, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _endDate != null
                                            ? DateFormat(
                                                'MMM dd, yyyy',
                                              ).format(_endDate!)
                                            : 'No end date',
                                      ),
                                      if (_endDate != null) ...[
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () =>
                                              setState(() => _endDate = null),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _savePrescription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Save Changes",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDayChip(String label, int dayIndex) {
    final isSelected = _selectedDays.contains(dayIndex);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          if (selected) {
            _selectedDays.add(dayIndex);
            _selectedDays.sort();
          } else {
            _selectedDays.remove(dayIndex);
          }
        });
      },
      selectedColor: AppColors.primaryPurple.withOpacity(0.2),
      checkmarkColor: AppColors.primaryPurple,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryPurple : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
