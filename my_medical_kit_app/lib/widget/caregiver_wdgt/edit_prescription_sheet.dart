//edit_prescription_sheet.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';

class EditPrescriptionSheet extends StatefulWidget {
  final Map<String, dynamic> prescription;
  final VoidCallback onUpdated;

  const EditPrescriptionSheet({
    super.key,
    required this.prescription,
    required this.onUpdated,
  });

  @override
  State<EditPrescriptionSheet> createState() => _EditPrescriptionSheetState();
}

class _EditPrescriptionSheetState extends State<EditPrescriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _medications = [];
  String? _selectedMedicationName;
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _inventoryController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController();
  final TextEditingController _deviceIdController = TextEditingController();

  TimeOfDay _selectedTime = TimeOfDay.now();
  List<String> _selectedDays = [];

  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _daysOfWeek = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    setState(() => _isLoading = true);
    try {
      final meds = await _apiService.getMedications();
      final rx = widget.prescription;

      // Set initial values from prescription
      _selectedMedicationName = rx['medication_name'];
      _dosageController.text = (rx['dosage_tablet'] ?? 1.0).toString();
      _inventoryController.text = (rx['current_inventory'] ?? 0).toString();
      _thresholdController.text = (rx['refill_threshold'] ?? 5).toString();
      _deviceIdController.text = (rx['device_id'] ?? '').toString();

      // Parse cron schedule to time + days
      final cron = rx['dispense_schedule'] ?? '';
      final parts = cron.split(' ');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[1]) ?? 8;
        final minute = int.tryParse(parts[0]) ?? 0;
        _selectedTime = TimeOfDay(hour: hour, minute: minute);
      }

      _selectedDays = [];
      if (parts.length >= 5 && parts[4] != '*') {
        final dayNumbers = parts[4].split(',');
        final dayMap = {
          '1': 'Mon',
          '2': 'Tue',
          '3': 'Wed',
          '4': 'Thu',
          '5': 'Fri',
          '6': 'Sat',
          '0': 'Sun',
          '7': 'Sun',
        };
        for (var d in dayNumbers) {
          final dayName = dayMap[d];
          if (dayName != null && !_selectedDays.contains(dayName)) {
            _selectedDays.add(dayName);
          }
        }
      }

      setState(() {
        _medications = meds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading medications: $e')));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryPurple,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMedicationName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a medication')),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select at least one day')));
      return;
    }

    setState(() => _isSaving = true);

    // Build cron string
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    final hour = _selectedTime.hour.toString().padLeft(2, '0');
    final dayNumbers = _selectedDays
        .map((d) {
          switch (d) {
            case 'Mon':
              return '1';
            case 'Tue':
              return '2';
            case 'Wed':
              return '3';
            case 'Thu':
              return '4';
            case 'Fri':
              return '5';
            case 'Sat':
              return '6';
            case 'Sun':
              return '0';
            default:
              return '1';
          }
        })
        .join(',');
    final cron = '$minute $hour * * $dayNumbers';

    final data = {
      'medication_name': _selectedMedicationName,
      'dosage_tablet': double.tryParse(_dosageController.text) ?? 1.0,
      'dispense_schedule': cron,
      'current_inventory': int.tryParse(_inventoryController.text) ?? 0,
      'refill_threshold': int.tryParse(_thresholdController.text) ?? 5,
      'device_id': _deviceIdController.text.isNotEmpty
          ? int.tryParse(_deviceIdController.text)
          : null,
    };

    final success = await _apiService.updatePrescription(
      widget.prescription['prescription_id'],
      data,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Prescription updated')));
        widget.onUpdated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 300,
        color: Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: kToolbarHeight),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                'Edit Prescription',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // Medication dropdown
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
                  prefixIcon: Icon(Icons.medication_outlined),
                ),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Dosage
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage (tablets) *',
                  prefixIcon: Icon(Icons.vaccines_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty
                    ? 'Required'
                    : (double.tryParse(v) == null ? 'Invalid number' : null),
              ),
              const SizedBox(height: 16),
              // Inventory
              TextFormField(
                controller: _inventoryController,
                decoration: const InputDecoration(
                  labelText: 'Current Inventory *',
                  prefixIcon: Icon(Icons.inventory),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty
                    ? 'Required'
                    : (int.tryParse(v) == null ? 'Invalid number' : null),
              ),
              const SizedBox(height: 16),
              // Refill threshold
              TextFormField(
                controller: _thresholdController,
                decoration: const InputDecoration(
                  labelText: 'Refill Threshold *',
                  prefixIcon: Icon(Icons.warning_amber),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty
                    ? 'Required'
                    : (int.tryParse(v) == null ? 'Invalid number' : null),
              ),
              const SizedBox(height: 16),
              // Device ID (optional)
              TextFormField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Device ID (optional)',
                  prefixIcon: Icon(Icons.devices),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              const Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 12),
                      Text(_selectedTime.format(context)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Days', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _daysOfWeek.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    selectedColor: AppColors.primaryPurple.withOpacity(0.2),
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Changes',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
