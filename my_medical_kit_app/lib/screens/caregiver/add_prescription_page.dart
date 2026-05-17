//add_prescription_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';

class AddPrescriptionPage extends StatefulWidget {
  final Map<String, dynamic> patient;

  const AddPrescriptionPage({super.key, required this.patient});

  @override
  State<AddPrescriptionPage> createState() => _AddPrescriptionPageState();
}

class _AddPrescriptionPageState extends State<AddPrescriptionPage> {
  
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _medications = [];
  String? _selectedMedicationName;
  final TextEditingController _dosageController = TextEditingController(text: '1.0');

  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  final List<String> _selectedDays = [];
  final List<String> _daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

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
      final meds = await MedicationService().getMedications();
      setState(() {
        _medications = meds.cast<Map<String, dynamic>>();
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

  String _buildCronExpression() {
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    final hour = _selectedTime.hour.toString().padLeft(2, '0');
    
    if (_selectedDays.isEmpty || _selectedDays.length == 7) {
      return '$minute $hour * * *';
    }

    final dayNumbers = _selectedDays.map((d) {
      switch (d) {
        case 'Mon': return '1';
        case 'Tue': return '2';
        case 'Wed': return '3';
        case 'Thu': return '4';
        case 'Fri': return '5';
        case 'Sat': return '6';
        case 'Sun': return '0';
        default: return '1';
      }
    }).join(',');

    return '$minute $hour * * $dayNumbers';
  }

  Future<void> _savePrescription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMedicationName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a medication')),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    final String cronSchedule = _buildCronExpression();
    final DateFormat formatter = DateFormat('yyyy-MM-dd');

    final data = {
      'patient_id': widget.patient['patient_id'],
      'medication_name': _selectedMedicationName,
      'dosage_tablet': double.tryParse(_dosageController.text) ?? 1.0,
      'dispense_schedule': cronSchedule,
      'start_date': formatter.format(_startDate),
      'end_date': _endDate != null ? formatter.format(_endDate!) : null,
    };

    final response = await MedicationService().addPrescription(data);
    setState(() => _isSaving = false);

    if (response['success'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription added successfully'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true); // Return true to indicate success
    } else {
      if (!mounted) return;
      String errorMsg = response['message'] ?? response['error'] ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $errorMsg'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Prescription', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingMedications
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient Info
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
                              child: Text(widget.patient['full_name'][0], style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Prescription for", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(widget.patient['full_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Medication Dropdown
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Select Medication *',
                              prefixIcon: const Icon(Icons.medication, color: AppColors.primaryPurple),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _selectedMedicationName,
                            items: _medications.map((med) => DropdownMenuItem(
                              value: med['medication_name'].toString(),
                              child: Text(med['medication_name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                            )).toList(),
                            onChanged: (val) => setState(() => _selectedMedicationName = val),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Dosage
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: TextFormField(
                            controller: _dosageController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Dosage (Tablets) *',
                              prefixIcon: const Icon(Icons.vaccines, color: AppColors.primaryPurple),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : (double.tryParse(v) == null ? 'Invalid number' : null),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Dispense Time
                        const Text('Dispense Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ListTile(
                          tileColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: const Icon(Icons.access_time, color: AppColors.primaryPurple),
                          title: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryPurple)),
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                            if (picked != null) setState(() => _selectedTime = picked);
                          },
                        ),
                        const SizedBox(height: 24),

                        // Schedule Days
                        const Text('Schedule Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _daysOfWeek.map((day) {
                            final isSelected = _selectedDays.contains(day);
                            return FilterChip(
                              label: Text(day),
                              selected: isSelected,
                              selectedColor: AppColors.primaryPurple.withValues(alpha: 0.2),
                              checkmarkColor: AppColors.primaryPurple,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedDays.add(day);
                                  } else {
                                    _selectedDays.remove(day);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text("Leave empty to dispense every day.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                        const SizedBox(height: 24),

                        // Start & End Dates
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Start Date *', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _selectDate(context, true),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade400),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 18),
                                          const SizedBox(width: 8),
                                          Text(DateFormat('MMM dd, yyyy').format(_startDate)),
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
                                  const Text('End Date', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _selectDate(context, false),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade400),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.event_busy, size: 18),
                                          const SizedBox(width: 8),
                                          Text(_endDate != null ? DateFormat('MMM dd, yyyy').format(_endDate!) : 'No end date'),
                                          if (_endDate != null) ...[
                                            const Spacer(),
                                            GestureDetector(
                                              onTap: () => setState(() => _endDate = null),
                                              child: const Icon(Icons.close, size: 16, color: Colors.grey),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    "Save Prescription",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
