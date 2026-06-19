//edit_patient_page.dart
// edit_patient_page.dart
// Allows a caregiver to edit a patient's profile information (name, email, phone, address,
// gender, date of birth, medical notes). Also supports uploading a profile photo.
// The updated data is sent back to the previous screen (PatientDetailPage) via Navigator.pop.

import 'package:my_medical_kit_app/services/api/api_client.dart';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';

class EditPatientPage extends StatefulWidget {
  final Map<String, dynamic>
  patient; // The patient data passed from the detail page

  const EditPatientPage({super.key, required this.patient});

  @override
  State<EditPatientPage> createState() => _EditPatientPageState();
}

class _EditPatientPageState extends State<EditPatientPage> {
  final _formKey = GlobalKey<FormState>(); // Form validation key

  // Controllers for all editable fields
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _medicalNotesController;
  late TextEditingController _dobController;

  String? _selectedGender; // Currently selected gender
  DateTime? _selectedDob; // Selected date of birth
  String? _photoPath; // Path of the newly picked photo (if any)
  bool _isSaving = false; // Prevent double submission

  final List<String> _genders = ['Male', 'Female']; // Gender options

  @override
  void initState() {
    super.initState();
    // Initialise controllers with existing patient data
    final p = widget.patient;
    _fullNameController = TextEditingController(text: p['full_name'] ?? '');
    _emailController = TextEditingController(text: p['email'] ?? '');
    _phoneController = TextEditingController(text: p['phone_no'] ?? '');
    _addressController = TextEditingController(text: p['address'] ?? '');
    _selectedGender = p['gender'];
    _medicalNotesController = TextEditingController(
      text: p['medical_notes'] ?? '',
    );
    // Parse and format date of birth if present
    if (p['date_of_birth'] != null && p['date_of_birth'].isNotEmpty) {
      try {
        _selectedDob = DateTime.parse(p['date_of_birth']);
        _dobController = TextEditingController(
          text: _formatDate(_selectedDob!),
        );
      } catch (_) {
        _dobController = TextEditingController();
      }
    } else {
      _dobController = TextEditingController();
    }
  }

  // Formats a DateTime to YYYY-MM-DD (server expects this format)
  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // Opens a date picker for the date of birth.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDob ??
          DateTime.now().subtract(const Duration(days: 365 * 65)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = _formatDate(picked);
      });
    }
  }

  // Opens the image picker to select a profile photo from the gallery.
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _photoPath = pickedFile.path);
  }

  // Saves the updated patient data to the server via PatientService.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // Build the form data map
    final formData = {
      'full_name': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone_no': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'gender': _selectedGender,
      'date_of_birth': _selectedDob != null ? _formatDate(_selectedDob!) : null,
      'medical_notes': _medicalNotesController.text.trim(),
    };

    // Call the API to update the patient with the photo if picked.
    final result = await PatientService().updatePatient(
      widget.patient['patient_id'],
      formData,
      photoPath: _photoPath,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient updated successfully')),
        );

        // Create an updated map to send back to the detail page.
        Map<String, dynamic> updatedData = Map<String, dynamic>.from(
          widget.patient,
        );
        updatedData['full_name'] = formData['full_name'];
        updatedData['email'] = formData['email'];
        updatedData['phone_no'] = formData['phone_no'];
        updatedData['address'] = formData['address'];
        updatedData['gender'] = formData['gender'];
        updatedData['date_of_birth'] = formData['date_of_birth'];
        updatedData['medical_notes'] = formData['medical_notes'];

        // If a new photo URL was returned, update it.
        if (result['photo_url'] != null) {
          updatedData['profile_photo'] = result['photo_url'];
        }

        // Pop and return the fresh data so the detail page can update.
        Navigator.pop(context, updatedData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: ${result['error']}')),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Edit Patient',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        // Removed the actions: [IconButton(...)] from here!
      ),
      body: Container(
        color: const Color(0xFFEFE8FA),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile photo section with camera icon (tap to pick image)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: AppColors.primaryPurple.withValues(
                          alpha: 0.05,
                        ),
                        backgroundImage:
                            widget.patient['profile_photo'] != null &&
                                widget.patient['profile_photo'].isNotEmpty
                            ? NetworkImage(
                                _buildImageUrl(widget.patient['profile_photo']),
                              )
                            : null,
                        child:
                            (widget.patient['profile_photo'] == null ||
                                widget.patient['profile_photo'].isEmpty)
                            ? Text(
                                widget.patient['full_name']
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryPurple,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.primaryPurple,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Input fields wrapped in styled cards ---

              // Full Name
              _buildInputCard(
                'Full Name',
                _fullNameController,
                Icons.person,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              // Email
              _buildInputCard(
                'Email',
                _emailController,
                Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              // Phone
              _buildInputCard(
                'Phone',
                _phoneController,
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              // Address
              _buildInputCard('Address', _addressController, Icons.location_on),
              // Gender dropdown
              _buildDropdownCard(
                'Gender',
                _selectedGender,
                _genders,
                (val) => setState(() => _selectedGender = val),
              ),
              // Date of Birth (with date picker)
              _buildDateCard(
                'Date of Birth',
                _dobController,
                () => _pickDate(),
              ),
              // Medical Notes (multi-line)
              _buildInputCard(
                'Medical Notes',
                _medicalNotesController,
                Icons.note,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Save button (solid dark purple)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build a text input field card.
  Widget _buildInputCard(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryPurple, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 50,
              minHeight: 40,
            ),
            border: InputBorder.none,
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textDark,
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
        ),
      ),
    );
  }

  // Helper to build a dropdown field card.
  Widget _buildDropdownCard(
    String label,
    String? value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.transgender_rounded,
                color: AppColors.primaryPurple,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 50,
              minHeight: 40,
            ),
            border: InputBorder.none,
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textDark,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primaryPurple,
          ),
          items: items
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Helper to build a date picker field card.
  Widget _buildDateCard(
    String label,
    TextEditingController controller,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primaryPurple,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 50,
              minHeight: 40,
            ),
            border: InputBorder.none,
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textDark,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  // Builds a full URL for a profile photo (prepends base URL if relative).
  String _buildImageUrl(String url) => url.startsWith('http')
      ? url
      : '${ApiClient.baseUrl}${url.startsWith('/') ? '' : '/'}$url';
}
