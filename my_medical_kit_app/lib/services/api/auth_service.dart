// lib/services/api/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      debugPrint("🚀 [API] Preparing to send login request to: ${ApiClient.baseUrl}/login");
      final response = await ApiClient.post('/login', body: {'email': email, 'password': password});
      debugPrint("📥 [API] Received response status code: ${response.statusCode}");
      debugPrint("📥 [API] Received raw server response: ${response.body}");
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("❌ [API] Critical error occurred: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await ApiClient.post('/register', body: userData);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String newPassword) async {
    try {
      final response = await ApiClient.post('/reset_password', body: {'email': email, 'new_password': newPassword});
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("❌ [API] Reset password error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }
}
