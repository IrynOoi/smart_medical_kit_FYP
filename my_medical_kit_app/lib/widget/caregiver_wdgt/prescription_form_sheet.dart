//prescription_form_sheet.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';


class PrescriptionFormSheet extends StatefulWidget {
  final Map<String, dynamic> patient;
  final int caregiverId;

  const PrescriptionFormSheet({super.key, 
    required this.patient,
    required this.caregiverId,
  });

  @override
  State<PrescriptionFormSheet> createState() => PrescriptionFormSheetState();
}

class PrescriptionFormSheetState extends State<PrescriptionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String _medicationName = '';
  String _dosage = '';

  // 🌟 REPLACED: String _timeOfDay with a precise TimeOfDay object
  TimeOfDay? _selectedTime;

  final List<String> _selectedDays = [];

  final List<String> _daysOfWeek = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  bool _isSaving = false;

  // 🌟 NEW: Helper to show the clock picker
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryPurple, // Header color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _savePrescription() async {
    if (_formKey.currentState!.validate()) {
      // Validate Time
      if (_selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a precise time.')),
        );
        return;
      }

      // Validate Days
      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one day.')),
        );
        return;
      }

      _formKey.currentState!.save();
      setState(() => _isSaving = true);

      try {
        // Prepare the formatted time string (e.g., "08:30" or "14:15") for your PostgreSQL database
        // final String formattedTime =
        //     '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

        // TODO: Send to API
        // Example: await _apiService.addPrescription(widget.patient['patient_id'], _medicationName, _dosage, _selectedDays, formattedTime);
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pop(context); // Close the sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully added $_medicationName at ${_selectedTime!.format(context)} for ${widget.patient['full_name']}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _isSaving = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: kToolbarHeight),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Setup Prescription',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'For ${widget.patient['full_name']}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // Medication Name
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Medication Name',
                  prefixIcon: const Icon(
                    Icons.medication_outlined,
                    color: AppColors.primaryPurple,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _medicationName = val!,
              ),
              const SizedBox(height: 16),

              // Dosage
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Dosage (e.g., 1 Pill, 500mg)',
                  prefixIcon: const Icon(
                    Icons.vaccines_outlined,
                    color: AppColors.primaryPurple,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _dosage = val!,
              ),
              const SizedBox(height: 24),

              // 🌟 Precise Time Picker UI
              const Text(
                'Precise Time',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedTime == null
                          ? Colors.grey.shade400
                          : AppColors.primaryPurple,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_filled_rounded,
                        color: _selectedTime == null
                            ? Colors.grey
                            : AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _selectedTime != null
                            ? _selectedTime!.format(context)
                            : 'Tap to select time...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _selectedTime != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedTime != null
                              ? AppColors.textDark
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Days of the week
              const Text(
                'Schedule Days',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _daysOfWeek.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    selectedColor: AppColors.primaryPurple.withOpacity(0.2),
                    checkmarkColor: AppColors.primaryPurple,
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _selectedDays.add(day)
                            : _selectedDays.remove(day);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePrescription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Assign Prescription',
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
}
