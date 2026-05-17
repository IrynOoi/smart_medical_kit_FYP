// lib/services/api/patient_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../../models/patient.dart';
import '../../models/adherence_log.dart';
import '../../models/notification.dart';

class PatientService {
  Future<Patient?> getPatient(int patientId) async {
    try {
      final response = await ApiClient.get('/patient/$patientId');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return Patient.fromJson(jsonResponse['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting patient: $e');
      return null;
    }
  }

  Future<List<AdherenceLog>> getAdherenceLogs(int patientId, {int? limit}) async {
    try {
      String endpoint = '/patient/$patientId/adherence_logs';
      if (limit != null) {
        endpoint += '?limit=$limit';
      }
      final response = await ApiClient.get(endpoint);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          final List<dynamic> data = jsonResponse['data'];
          return data.map((json) => AdherenceLog.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting adherence logs: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getAdherenceStats(int patientId) async {
    try {
      final response = await ApiClient.get('/patient/$patientId/adherence_stats');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return jsonResponse['data'];
        }
      }
      return {'taken_count': 0, 'missed_count': 0, 'upcoming_count': 0, 'adherence_score': 0};
    } catch (e) {
      debugPrint('Error getting adherence stats: $e');
      return {'taken_count': 0, 'missed_count': 0, 'upcoming_count': 0, 'adherence_score': 0};
    }
  }

  Future<List<NotificationModel>> getNotifications(int patientId) async {
    try {
      final response = await ApiClient.get('/patient/$patientId/notifications');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          final List<dynamic> data = jsonResponse['data'];
          return data.map((json) => NotificationModel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  Future<bool> createNotification({
    required int patientId,
    required String title,
    required String message,
    String type = 'REMINDER',
  }) async {
    try {
      final response = await ApiClient.post('/notifications', body: {
        'patient_id': patientId,
        'title': title,
        'message': message,
        'type': type,
      });
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('Error creating notification: $e');
      return false;
    }
  }

  Future<bool> markNotificationRead(int notificationId) async {
    try {
      final response = await ApiClient.put('/notification/$notificationId/read');
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> updatePatient(int patientId, Map<String, dynamic> formData, {String? photoPath}) async {
    try {
      var request = http.MultipartRequest('PUT', Uri.parse('${ApiClient.baseUrl}/update_patient/$patientId'));
      formData.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });
      if (photoPath != null && photoPath.isNotEmpty) {
        var file = await http.MultipartFile.fromPath('profile_photo', photoPath);
        request.files.add(file);
      }
      request.headers.addAll(ApiClient.defaultHeaders);
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addPatient(Map<String, dynamic> patientData) async {
    try {
      final response = await ApiClient.post('/register', body: patientData);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> deletePatient(int patientId) async {
    try {
      final response = await ApiClient.delete('/patient/$patientId');
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markSingleReminderRead(int patientId, String medicationName) async {
    try {
      final response = await ApiClient.put(
        '/patient/$patientId/reminders/read_single',
        body: {'medication_name': medicationName},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('Error marking single reminder read: \$e');
      return false;
    }
  }
}
