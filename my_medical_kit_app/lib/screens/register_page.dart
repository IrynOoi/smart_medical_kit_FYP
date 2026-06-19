// screens/register_page.dart
// Registration screen for new users (Patient or Caregiver). Collects user details,
// validates input, and calls the AuthService to create a new account.

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Form key for overall form validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for all text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController(); // Separate for password confirmation
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _medicalNotesController =
      TextEditingController(); // Only used for patients

  // State variables for password visibility toggles
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Selected role (Patient / Caregiver) and gender
  String _selectedRole = 'Patient';
  String _selectedGender = 'Male';

  /// Opens a date picker to select date of birth and formats it as YYYY-MM-DD.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 20),
      ), // roughly 20 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      // Customize the picker theme to match the app's primary color
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        // Format as YYYY-MM-DD (server expects this format)
        _dobController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  /// Performs the registration API call.
  /// Shows a loading indicator, sends data to AuthService, handles response.
  Future<void> _register() async {
    // Validate all form fields before proceeding
    if (!_formKey.currentState!.validate()) return;

    try {
      // Show a loading spinner (non-dismissible)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );

      // Build the request payload
      final result = await AuthService().register({
        "role": _selectedRole,
        "fullname": _nameController.text,
        "email": _emailController.text,
        "password": _passwordController.text,
        "gender": _selectedGender,
        "phone_no": _phoneController.text,
        "date_of_birth": _dobController.text,
        "address": _addressController.text,
        // Only send medical_notes if role is Patient, otherwise null
        "medical_notes": _selectedRole == 'Patient'
            ? _medicalNotesController.text
            : null,
        "caregiver_id": null, // Not used during registration
      });

      // Dismiss the loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] == true) {
        // Success: show a snackbar and navigate back to login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Return to login screen
      } else {
        // Server returned an error (e.g., duplicate email)
        throw Exception(result['error'] ?? 'Registration failed');
      }
    } catch (e) {
      // Handle any exceptions: dismiss loading if still open, show error snackbar
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Extend body behind the app bar for a transparent effect
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context), // Go back to login
        ),
      ),
      body: Container(
        // Full-screen gradient background
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: SingleChildScrollView(
          // Allow scrolling if content overflows
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Form(
              key: _formKey, // Attach the form key for validation
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  // Page title
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join the Smart Medical Kit family',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // White card containing all input fields
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Role selection: Patient or Caregiver
                        Text(
                          'I am a:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryPurple.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Patient')),
                                selected: _selectedRole == 'Patient',
                                onSelected: (_) =>
                                    setState(() => _selectedRole = 'Patient'),
                                selectedColor: AppColors.primaryPurple
                                    .withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: _selectedRole == 'Patient'
                                      ? AppColors.primaryPurple
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Caregiver')),
                                selected: _selectedRole == 'Caregiver',
                                onSelected: (_) =>
                                    setState(() => _selectedRole = 'Caregiver'),
                                selectedColor: AppColors.primaryPurple
                                    .withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: _selectedRole == 'Caregiver'
                                      ? AppColors.primaryPurple
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // --- Text fields using the helper method _buildTextField ---
                        _buildTextField(
                          _nameController,
                          'Full Name',
                          Icons.person_outline,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          _emailController,
                          'Email Address',
                          Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Password field with visibility toggle
                        _buildTextField(
                          _passwordController,
                          'Password',
                          Icons.lock_outline,
                          obscureText: !_isPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Confirm password field
                        _buildTextField(
                          _confirmPasswordController,
                          'Confirm Password',
                          Icons.lock_outline,
                          obscureText: !_isConfirmPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          _phoneController,
                          'Phone Number',
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        // Row for Gender dropdown and Date of Birth picker
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedGender,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.wc_outlined,
                                    color: AppColors.primaryPurple,
                                  ),
                                  labelText: 'Gender',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                items: ['Male', 'Female']
                                    .map(
                                      (g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(g),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedGender = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                _dobController,
                                'Date of Birth (YYYY-MM-DD)',
                                Icons.calendar_today_outlined,
                                readOnly:
                                    true, // Prevents manual entry, forces picker
                                onTap: () => _selectDate(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          _addressController,
                          'Address',
                          Icons.location_on_outlined,
                        ),

                        // Optional: medical notes (commented out in original)
                        // if (_selectedRole == 'Patient') ...[
                        //   const SizedBox(height: 16),
                        //   _buildTextField(
                        //     _medicalNotesController,
                        //     'Medical Notes',
                        //     Icons.note_alt_outlined,
                        //     maxLines: 2,
                        //   ),
                        // ],
                        const SizedBox(height: 32),

                        // Register button
                        ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'REGISTER NOW',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper method to build a consistent text field with label, icon, and optional features.
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon, // For visibility toggle, etc.
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: _inputDecoration(
        label,
        icon,
      ).copyWith(suffixIcon: suffixIcon),
      // Validators for each field
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your $label';
        }

        // Email format validation
        if (label == 'Email Address') {
          final emailRegex = RegExp(
            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
          );
          if (!emailRegex.hasMatch(value.trim())) {
            return 'Please enter a valid email address';
          }
        }

        // Password confirmation match
        if (label == 'Confirm Password' && value != _passwordController.text) {
          return 'Passwords do not match';
        }

        return null; // Validation passed
      },
    );
  }

  /// Returns a consistent InputDecoration for all fields.
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primaryPurple),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
