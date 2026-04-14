// lib/screens/profile_page.dart

import 'package:my_medical_kit_app/screens/landing_page.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isEditing = false;
  String _errorMessage = '';
  String _userRole = '';
  int _userId = 0;

  // User data
  Map<String, dynamic> _userData = {};

  // Edit form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedGender = 'Male';
  DateTime? _selectedDate;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _userRole = prefs.getString('role') ?? 'patient';
      _userId = prefs.getInt('${_userRole}_id') ?? 1;

      debugPrint('🔵 Loading profile - Role: $_userRole, ID: $_userId');

      if (_userRole == 'patient') {
        final patient = await _apiService.getPatient(_userId);
        if (patient != null) {
          _userData = {
            'name': patient.fullName,
            'email': patient.email ?? 'Not provided',
            'phone': patient.phoneNo ?? 'Not provided',
            'address': patient.address ?? 'Not provided',
            'gender': patient.gender?.toString().split('.').last ?? 'Male',
            'dob': patient.dateOfBirth,
            'notes': patient.medicalNotes ?? 'No medical notes',
            'is_active': patient.isActive,
          };
          debugPrint('🔵 Patient data loaded: ${_userData['name']}');
        } else {
          _useEmptyDataFallback();
          _errorMessage = 'Patient not found.';
        }
      } else {
        final caregiverData = await _getCaregiverProfile(_userId);
        if (caregiverData.isNotEmpty) {
          _userData = {
            'name': caregiverData['full_name']?.toString() ?? 'Caregiver',
            'email': caregiverData['email']?.toString() ?? 'Not provided',
            'phone': caregiverData['phone_no']?.toString() ?? 'Not provided',
            'address': caregiverData['address']?.toString() ?? 'Not provided',
            'gender': caregiverData['gender']?.toString() ?? 'Male',
            'dob': _parseDateSafely(caregiverData['date_of_birth']),
            'notes': null,
            'is_active': caregiverData['is_active'] ?? true,
          };
          debugPrint('🔵 Caregiver data loaded: ${_userData['name']}');
        } else {
          _useEmptyDataFallback();
          _errorMessage = 'Caregiver not found.';
        }
      }

      // Initialize controllers with current data
      _nameController.text = _userData['name']?.toString() ?? '';
      _phoneController.text = _userData['phone']?.toString() ?? '';
      _addressController.text = _userData['address']?.toString() ?? '';
      _emailController.text = _userData['email']?.toString() ?? '';
      _selectedGender = _userData['gender']?.toString() ?? 'Male';
      _selectedDate = _userData['dob'] as DateTime?;
      _notesController.text = _userData['notes']?.toString() ?? '';
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
      _useEmptyDataFallback();
      _errorMessage = 'Failed to load profile data.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> updateData = {
        'full_name': _nameController.text,
        'phone_no': _phoneController.text,
        'address': _addressController.text,
        'email': _emailController.text,
        'gender': _selectedGender,
      };

      // Add date of birth if selected
      if (_selectedDate != null) {
        updateData['date_of_birth'] =
            "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      }

      // Add medical notes for patients
      if (_userRole == 'patient') {
        updateData['medical_notes'] = _notesController.text;
      }

      debugPrint('🔵 Updating profile with: $updateData');

      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/update_$_userRole/$_userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      );

      final result = jsonDecode(response.body);
      if (result['success']) {
        setState(() {
          _userData['name'] = _nameController.text;
          _userData['phone'] = _phoneController.text;
          _userData['address'] = _addressController.text;
          _userData['email'] = _emailController.text;
          _userData['gender'] = _selectedGender;
          _userData['dob'] = _selectedDate;
          if (_userRole == 'patient') {
            _userData['notes'] = _notesController.text;
          }
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUserData(); // Reload fresh data
      } else {
        throw Exception(result['error'] ?? 'Update failed');
      }
    } catch (e) {
      debugPrint('❌ Update error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
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
        _selectedDate = picked;
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LandingPage()),
      (route) => false, // removes all previous pages
    );
  }

  DateTime? _parseDateSafely(dynamic dateString) {
    if (dateString == null || dateString.toString().isEmpty) return null;
    try {
      return DateTime.parse(dateString.toString());
    } catch (e) {
      return null;
    }
  }

  void _useEmptyDataFallback() {
    _userData = {};
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<Map<String, dynamic>> _getCaregiverProfile(int caregiverId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/caregiver/$caregiverId'),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success']) {
          return json['data'];
        }
      }
      return {};
    } catch (e) {
      debugPrint('❌ Caregiver API Error: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6FB),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    final fullName = _userData['name']?.toString() ?? 'Unknown User';
    final email = _userData['email']?.toString() ?? 'Not provided';
    final phone = _userData['phone']?.toString() ?? 'Not provided';
    final address = _userData['address']?.toString() ?? 'Not provided';
    final gender = _userData['gender']?.toString() ?? 'Not specified';
    final dob = _formatDate(_userData['dob'] as DateTime?);
    final notes = _userData['notes']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          // Fixed Header with Gradient
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Custom AppBar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const Text(
                          'My Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 38),
                      ],
                    ),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  _buildAvatarSection(fullName, _userRole),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Scrollable Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUserData,
              color: AppColors.primaryPurple,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _isEditing
                    ? _buildEditForm()
                    : _buildViewMode(
                        fullName,
                        email,
                        phone,
                        address,
                        gender,
                        dob,
                        notes,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode(
    String fullName,
    String email,
    String phone,
    String address,
    String gender,
    String dob,
    String? notes,
  ) {
    return Column(
      children: [
        const SizedBox(height: 24),
        _buildCardGroup(
          title: 'Contact Details',
          icon: Icons.contact_mail_rounded,
          children: [
            _buildInfoRow(Icons.email_rounded, 'Email Address', email),
            _buildDivider(),
            _buildInfoRow(Icons.phone_rounded, 'Mobile Number', phone),
          ],
        ),
        const SizedBox(height: 16),
        _buildCardGroup(
          title: 'Personal Info',
          icon: Icons.person_rounded,
          children: [
            _buildInfoRow(Icons.wc_rounded, 'Gender', gender),
            _buildDivider(),
            _buildInfoRow(Icons.cake_rounded, 'Date of Birth', dob),
            _buildDivider(),
            _buildInfoRow(Icons.location_on_rounded, 'Address', address),
          ],
        ),
        if (_userRole == 'patient' && notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildCardGroup(
            title: 'Medical Notes',
            icon: Icons.medical_information_rounded,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  notes,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),
        _buildActionButtons(),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildCardGroup(
            title: 'Contact Details',
            icon: Icons.contact_mail_rounded,
            children: [
              _buildEditField(
                Icons.person_rounded,
                'Full Name',
                _nameController,
              ),
              _buildDivider(),
              _buildEditField(
                Icons.email_rounded,
                'Email',
                _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              _buildDivider(),
              _buildEditField(
                Icons.phone_rounded,
                'Mobile Number',
                _phoneController,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCardGroup(
            title: 'Personal Info',
            icon: Icons.person_rounded,
            children: [
              // Gender Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.wc_rounded,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: ['Male', 'Female', 'Other']
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedGender = val!),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please select gender'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              // Date of Birth with Calendar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.cake_rounded,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: TextEditingController(
                              text: _selectedDate != null
                                  ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
                                  : '',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              suffixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              _buildEditField(
                Icons.location_on_rounded,
                'Address',
                _addressController,
              ),
            ],
          ),
          if (_userRole == 'patient') ...[
            const SizedBox(height: 16),
            _buildCardGroup(
              title: 'Medical Notes',
              icon: Icons.medical_information_rounded,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Medical Notes',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isEditing = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(String name, String role) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              const CircleAvatar(
                radius: 54,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primaryPurple,
                  child: Icon(
                    Icons.person_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            role.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardGroup({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 20, bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryPurple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(
    IconData icon,
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter $label' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(
    height: 1,
    indent: 66,
    endIndent: 20,
    color: Colors.grey.shade100,
  );

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () => setState(() => _isEditing = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.redAccent,
              minimumSize: const Size(double.infinity, 55),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
