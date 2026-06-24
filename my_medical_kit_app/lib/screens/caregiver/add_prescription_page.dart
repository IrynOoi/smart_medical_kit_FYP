// add_prescription_page.dart
// Allows a caregiver to add a new prescription for a specific patient.
// Fields: medication (dropdown), dosage, dispense times (list with add/remove),
// days of week (chips, empty = everyday), start date, optional end date.
// Checks for duplicate active prescriptions before saving.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';

class AddPrescriptionPage extends StatefulWidget {
  final Map<String, dynamic> patient; // The patient this prescription is for

  const AddPrescriptionPage({super.key, required this.patient});

  @override
  State<AddPrescriptionPage> createState() => _AddPrescriptionPageState();
}

class _AddPrescriptionPageState extends State<AddPrescriptionPage> {
  final _formKey = GlobalKey<FormState>();

  // ---- Medication selection ----
  List<Map<String, dynamic>> _medications =
      []; // Master list of all medications
  String? _selectedMedicationName; // Currently selected medication name
  final TextEditingController _dosageController = TextEditingController(
    text: '1.0', // Default dosage
  );

  // ---- Schedule ----
  List<TimeOfDay> _selectedTimes = [
    const TimeOfDay(hour: 8, minute: 0),
  ]; // Default one time
  List<int> _selectedDays = []; // 1=Mon, ..., 7=Sun. Empty = everyday.

  // ---- Duration ----
  DateTime _startDate = DateTime.now(); // Default to today
  DateTime? _endDate; // Optional end date

  // ---- UI state ----
  bool _isLoadingMedications = true; // Loading the medication dropdown list
  bool _isSaving = false; // Show loading spinner while saving
  String? _errorMessage; // Error message from API

  @override
  void initState() {
    super.initState();
    _fetchMedications(); // Load medication list when screen opens
  }

  // Fetches the master list of medications for the dropdown.
  Future<void> _fetchMedications() async {
    setState(() {
      _isLoadingMedications = true;
      _errorMessage = null;
    });
    try {
      final meds = await MedicationService().getMedications();
      setState(() {
        _medications = meds.cast<Map<String, dynamic>>();
        // Auto-select the first medication if available.
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

  // Opens a date picker for the start or end date.
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
          // Ensure end date is not before start date.
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // Validates and saves the new prescription.
  // Checks for duplicate active prescriptions for the same patient.
  Future<void> _savePrescription() async {
    // =============================================
    // 🛡️ CRITICAL FIX 1: Prevent double‑tap (synchronous lock)
    // Lock the button IMMEDIATELY before any async work or validation,
    // so rapid taps cannot both slip through before setState fires.
    // =============================================
    if (_isSaving) return;
    setState(() => _isSaving = true); // Lock synchronously right away

    // =============================================
    // 📝 Basic form validation (unlock if validation fails)
    // =============================================
    if (!_formKey.currentState!.validate()) {
      setState(() => _isSaving = false);
      return;
    }

    if (_selectedMedicationName == null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a medication')),
      );
      return;
    }

    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be before start date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // =============================================
    // 🔍 Check if an active prescription for this medication already exists (frontend safety)
    // =============================================
    try {
      final patientId = widget.patient['patient_id'];
      final existing = await MedicationService().getPatientMedications(
        patientId,
      );
      final hasDuplicate = existing.any((p) {
        // Only check prescriptions that haven't ended
        if (p.endDate != null && p.endDate!.isBefore(DateTime.now()))
          return false;
        return p.medicationName == _selectedMedicationName;
      });
      if (hasDuplicate) {
        if (!mounted) return;
        setState(() => _isSaving = false);
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
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not verify duplicates: $e')),
      );
      return;
    }

    try {
      // Build the request payload
      final List<String> dispenseTimes = _selectedTimes.map((t) {
        final hour = t.hour.toString().padLeft(2, '0');
        final minute = t.minute.toString().padLeft(2, '0');
        return '$hour:$minute:00';
      }).toList();

      final DateFormat formatter = DateFormat('yyyy-MM-dd');

      final data = {
        'patient_id': widget.patient['patient_id'],
        'medication_name': _selectedMedicationName,
        'dosage_tablet': double.tryParse(_dosageController.text) ?? 1.0,
        'dispense_times': dispenseTimes,
        'dispense_days': _selectedDays,
        'start_date': formatter.format(_startDate),
        'end_date': _endDate != null ? formatter.format(_endDate!) : null,
      };

      // Call the backend API
      final response = await MedicationService().addPrescription(data);

      // Handle the response
      if (response['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Return to previous screen and refresh the list
      } else {
        if (!mounted) return;
        String errorMsg =
            response['message'] ?? response['error'] ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Exception handling
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      // =============================================
      // 🔓 CRITICAL FIX 2: Always unlock the button, regardless of success or failure
      // =============================================
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5), // Light purple background
      appBar: AppBar(
        title: const Text(
          'Add Prescription',
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _fetchMedications,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- Patient info card ----
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primaryPurple
                                  .withOpacity(0.1),
                              child: Text(
                                widget.patient['full_name'][0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Prescribing for",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.patient['full_name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---- Medication Details section ----
                    _buildSectionHeader('Medication Details', Icons.medication),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Medication dropdown (from master list)
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Select Medication *',
                                prefixIcon: const Icon(
                                  Icons.medication,
                                  color: AppColors.primaryPurple,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryPurple,
                                    width: 2,
                                  ),
                                ),
                              ),
                              initialValue: _selectedMedicationName,
                              items: _medications
                                  .map(
                                    (med) => DropdownMenuItem(
                                      value: med['medication_name'].toString(),
                                      child: Text(
                                        med['medication_name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedMedicationName = val),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            // Dosage (tablets)
                            TextFormField(
                              controller: _dosageController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Dosage (Tablets) *',
                                prefixIcon: const Icon(
                                  Icons.vaccines,
                                  color: AppColors.primaryPurple,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryPurple,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Required'
                                  : (double.tryParse(v) == null
                                        ? 'Invalid number'
                                        : null),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---- Schedule section ----
                    _buildSectionHeader('Schedule', Icons.schedule),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dispense times: list of TimeOfDay widgets with add/remove
                            const Text(
                              'Dispense Times',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: _selectedTimes.asMap().entries.map((
                                entry,
                              ) {
                                int index = entry.key;
                                TimeOfDay time = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showTimePicker(
                                              context: context,
                                              initialTime: time,
                                              builder: (context, child) {
                                                return Theme(
                                                  data: Theme.of(context).copyWith(
                                                    colorScheme:
                                                        const ColorScheme.light(
                                                          primary: AppColors
                                                              .primaryPurple,
                                                        ),
                                                  ),
                                                  child: child!,
                                                );
                                              },
                                            );
                                            if (picked != null) {
                                              setState(
                                                () => _selectedTimes[index] =
                                                    picked,
                                              );
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.access_time,
                                                  color:
                                                      AppColors.primaryPurple,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  time.format(context),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const Spacer(),
                                                const Icon(
                                                  Icons.arrow_drop_down,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Remove button (only if more than one time)
                                      if (_selectedTimes.length > 1)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            setState(
                                              () => _selectedTimes.removeAt(
                                                index,
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            // Add time button
                            TextButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: const TimeOfDay(
                                    hour: 8,
                                    minute: 0,
                                  ),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: AppColors.primaryPurple,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
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
                                style: TextStyle(
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            // Days of the week (chips)
                            const Text(
                              'Days of the Week',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'If no days are selected, it will default to Everyday.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---- Duration section (Start and End date) ----
                    _buildSectionHeader('Duration', Icons.date_range),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start Date *',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _selectDate(context, true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: AppColors.primaryPurple,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat(
                                              'MMM dd, yyyy',
                                            ).format(_startDate),
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
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
                                    'End Date (Optional)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => _selectDate(context, false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.event_busy,
                                            size: 18,
                                            color: AppColors.primaryPurple,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _endDate != null
                                                  ? DateFormat(
                                                      'MMM dd, yyyy',
                                                    ).format(_endDate!)
                                                  : 'No end date',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          // Clear end date button
                                          if (_endDate != null)
                                            GestureDetector(
                                              onTap: () => setState(
                                                () => _endDate = null,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ---- Save button ----
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
                          elevation: 2,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "Save Prescription",
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

  // Helper: builds a section header with an icon and title.
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Helper: builds a day chip (toggle for days of the week).
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
