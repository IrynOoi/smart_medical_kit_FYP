// lib/services/api/auth_service.dart
// Service class for authentication-related API calls: login, register, password reset

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class AuthService {
  // ---------------------- User Login ----------------------
  /// Authenticate a user with email and password.
  ///
  /// Parameters:
  ///   - email: user's email address
  ///   - password: user's password (plain text, will be hashed on server)
  ///
  /// Returns a Map with 'success' and either 'user' data or 'error' message.
  /// The server response is expected to include user_id, role, full_name, etc.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Debug prints: log the request and response for troubleshooting
      debugPrint(
        "🚀 [API] Preparing to send login request to: ${ApiClient.baseUrl}/login",
      );
      final response = await ApiClient.post(
        '/login',
        body: {'email': email, 'password': password},
      );
      debugPrint(
        "📥 [API] Received response status code: ${response.statusCode}",
      );
      debugPrint("📥 [API] Received raw server response: ${response.body}");
      return jsonDecode(response.body);
    } catch (e) {
      // Catch any network or decoding errors and return a structured error
      debugPrint("❌ [API] Critical error occurred: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  // ---------------------- User Registration ----------------------
  /// Register a new user (patient or caregiver) with the provided data.
  ///
  /// Parameters:
  ///   - userData: a Map containing fields like:
  ///       role (patient/caregiver), email, password, fullname, gender,
  ///       phone_no, date_of_birth, address, caregiver_id (optional),
  ///       medical_notes (optional for patients)
  ///
  /// Returns a Map with 'success' and either a success message or 'error'.
  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await ApiClient.post('/register', body: userData);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ---------------------- Password Reset ----------------------
  /// Request to reset the password for a user by email.
  ///
  /// Parameters:
  ///   - email: the email address of the account
  ///   - newPassword: the desired new password (plain text)
  ///
  /// Returns a Map with 'success' and either a success message or 'error'.
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String newPassword,
  ) async {
    try {
      final response = await ApiClient.post(
        '/reset_password',
        body: {'email': email, 'new_password': newPassword},
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("❌ [API] Reset password error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }
}
