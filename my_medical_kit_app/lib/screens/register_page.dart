import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:my_medical_kit_app/theme/colors.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _medicalNotesController = TextEditingController();

  String _selectedRole = 'Patient';
  String _selectedGender = 'Male';

  final String serverIp = "172.20.10.9";

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
      );

      final response = await http.post(
        Uri.parse('http://$serverIp:5000/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "role": _selectedRole,
          "fullname": _nameController.text,
          "email": _emailController.text,
          "password": _passwordController.text,
          "gender": _selectedGender,
          "phone_no": _phoneController.text,
          "date_of_birth": _dobController.text,
          "address": _addressController.text,
          "medical_notes": _selectedRole == 'Patient' ? _medicalNotesController.text : null,
          "caregiver_id": 1 // Default for now
        }),
      );

      Navigator.pop(context);

      final result = jsonDecode(response.body);
      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception(result['error'] ?? 'Registration failed');
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 100),
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
                  // Form Card
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
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Role Selector
                        const Text('I am a:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Patient')),
                                selected: _selectedRole == 'Patient',
                                onSelected: (val) => setState(() => _selectedRole = 'Patient'),
                                selectedColor: AppColors.primaryPurple.withOpacity(0.2),
                                labelStyle: TextStyle(color: _selectedRole == 'Patient' ? AppColors.primaryPurple : Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Caregiver')),
                                selected: _selectedRole == 'Caregiver',
                                onSelected: (val) => setState(() => _selectedRole = 'Caregiver'),
                                selectedColor: AppColors.primaryPurple.withOpacity(0.2),
                                labelStyle: TextStyle(color: _selectedRole == 'Caregiver' ? AppColors.primaryPurple : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(_nameController, 'Full Name', Icons.person_outline),
                        const SizedBox(height: 16),
                        _buildTextField(_emailController, 'Email Address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        _buildTextField(_passwordController, 'Password', Icons.lock_outline, obscureText: true),
                        const SizedBox(height: 16),
                        _buildTextField(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
                        const SizedBox(height: 16),
                        // Row for Gender and DOB
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedGender,
                                decoration: _inputDecoration('Gender', Icons.wc_outlined),
                                items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                onChanged: (val) => setState(() => _selectedGender = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(_dobController, 'DOB (YYYY-MM-DD)', Icons.calendar_today_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(_addressController, 'Address', Icons.location_on_outlined),
                        if (_selectedRole == 'Patient') ...[
                          const SizedBox(height: 16),
                          _buildTextField(_medicalNotesController, 'Medical Notes', Icons.note_alt_outlined, maxLines: 2),
                        ],
                        const SizedBox(height: 32),
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, 
      {bool obscureText = false, TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _inputDecoration(label, icon),
      validator: (value) => value == null || value.isEmpty ? 'Please enter your $label' : null,
    );
  }

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
