// patient_service.dart – Service class for patient‑specific API calls.
// Wraps the generic ApiClient to provide type‑safe methods for patient
// profiles, adherence logs, notifications, profile updates, reminders,
// and dose retakes.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../../models/patient.dart';
import '../../models/adherence_log.dart';
import '../../models/notification.dart';

class PatientService {
  /// Fetch the full profile of a patient (including caregiver info).
  /// GET /patient/{patientId}
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

  /// Reactivate a soft‑deleted patient (set is_active = true).
  /// PUT /patient/{patientId}/reactivate
  Future<bool> reactivatePatient(int patientId) async {
    try {
      final response = await ApiClient.put('/patient/$patientId/reactivate');
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Retrieve adherence logs for a patient, with optional limit.
  /// GET /patient/{patientId}/adherence_logs?limit={limit}
  Future<List<AdherenceLog>> getAdherenceLogs(
    int patientId, {
    int? limit,
  }) async {
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

  /// Get adherence statistics (taken, missed, upcoming, score) for a patient.
  /// GET /patient/{patientId}/adherence_stats
  Future<Map<String, dynamic>> getAdherenceStats(int patientId) async {
    try {
      final response = await ApiClient.get(
        '/patient/$patientId/adherence_stats',
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return jsonResponse['data'];
        }
      }
      // Return default stats on failure
      return {
        'taken_count': 0,
        'missed_count': 0,
        'upcoming_count': 0,
        'adherence_score': 0,
      };
    } catch (e) {
      debugPrint('Error getting adherence stats: $e');
      return {
        'taken_count': 0,
        'missed_count': 0,
        'upcoming_count': 0,
        'adherence_score': 0,
      };
    }
  }

  /// Get in‑app notifications for a patient (latest 20).
  /// GET /patient/{patientId}/notifications
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

  /// Create a new in‑app notification for a patient.
  /// POST /notifications with body: patient_id, title, message, type
  Future<bool> createNotification({
    required int patientId,
    required String title,
    required String message,
    String type = 'REMINDER',
  }) async {
    try {
      final response = await ApiClient.post(
        '/notifications',
        body: {
          'patient_id': patientId,
          'title': title,
          'message': message,
          'type': type,
        },
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('Error creating notification: $e');
      return false;
    }
  }

  /// Mark a specific notification as read.
  /// PUT /notification/{notificationId}/read
  Future<bool> markNotificationRead(int notificationId) async {
    try {
      final response = await ApiClient.put(
        '/notification/$notificationId/read',
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      return false;
    }
  }

  /// Update patient profile. Supports photo upload via multipart/form-data.
  /// PUT /update_patient/{patientId} (multipart)
  Future<Map<String, dynamic>> updatePatient(
    int patientId,
    Map<String, dynamic> formData, {
    String? photoPath,
  }) async {
    try {
      // Build multipart request
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiClient.baseUrl}/update_patient/$patientId'),
      );
      // Add all form fields
      formData.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });
      // Add photo file if provided
      if (photoPath != null && photoPath.isNotEmpty) {
        var file = await http.MultipartFile.fromPath(
          'profile_photo',
          photoPath,
        );
        request.files.add(file);
      }
      // Use default headers from ApiClient (incl. ngrok-skip-browser-warning)
      request.headers.addAll(ApiClient.defaultHeaders);
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Register a new patient (uses the /register endpoint).
  /// POST /register with patient data
  Future<Map<String, dynamic>> addPatient(
    Map<String, dynamic> patientData,
  ) async {
    try {
      final response = await ApiClient.post('/register', body: patientData);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete a patient. By default does soft delete; if hard=true, permanent.
  /// DELETE /patient/{patientId}?hard=true (optional)
  Future<bool> deletePatient(int patientId, {bool hard = false}) async {
    try {
      String endpoint = '/patient/$patientId';
      if (hard) endpoint += '?hard=true';
      final response = await ApiClient.delete(endpoint);
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Mark reminders for a specific medication as read.
  /// PUT /patient/{patientId}/reminders/read_single with {medication_name}
  Future<bool> markSingleReminderRead(
    int patientId,
    String medicationName,
  ) async {
    try {
      final response = await ApiClient.put(
        '/patient/$patientId/reminders/read_single',
        body: {'medication_name': medicationName},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('Error marking single reminder read: $e');
      return false;
    }
  }

  /// Retake a missed dose (update log to TAKEN and decrement inventory).
  /// PUT /adherence_log/{adlogId}/retake
  Future<bool> retakeMissedDose(int adlogId) async {
    try {
      final response = await ApiClient.put('/adherence_log/$adlogId/retake');
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('Retake error: $e');
      return false;
    }
  }

  /// Get dispense information for a retake (validates 30‑minute window).
  /// GET /retake_trigger/{adlogId}
  Future<Map<String, dynamic>?> triggerRetake(int adlogId) async {
    try {
      final response = await ApiClient.get('/retake_trigger/$adlogId');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return jsonResponse['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Trigger retake error: $e');
      return null;
    }
  }
}
