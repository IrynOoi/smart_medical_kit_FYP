//api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient.dart';
import '../models/medication.dart';
import '../models/adherence_log.dart';
import '../models/notification.dart';
import '../models/ai_prediction.dart';

class ApiService {
  // ==========================================
  // 🔧 IMPORTANT: Change this based on where you run the app
  // ==========================================

  // For Android Emulator (use this!)
  // api_service.dart — fix this line
  static const String baseUrl =
      'http://172.20.10.9:5000'; // ← physical device IP
  // static const String baseUrl = 'http://10.0.2.2:5000'; // ← comment this out

  // For Physical Device on same WiFi/Hotspot (uncomment this, comment the above)
  // static const String baseUrl = 'http://172.20.10.9:5000';

  // For iOS Simulator (use this)
  // static const String baseUrl = 'http://localhost:5000';

  // For Testing with Chrome (web) - use your computer's IP
  // static const String baseUrl = 'http://172.20.10.9:5000';

  // ==========================================
  // 🔐 AUTHENTICATION ENDPOINTS
  // ==========================================

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      // error logged in production would go here
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      // error logging
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==========================================
  // 👤 PATIENT ENDPOINTS
  // ==========================================

  Future<Patient?> getPatient(int patientId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/patient/$patientId'));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          final patient = Patient.fromJson(jsonResponse['data']);
          return patient;
        }
      }
      return null;
    } catch (e) {
      // error logging
      return null;
    }
  }

  Future<List<Medication>> getPatientMedications(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patient/$patientId/prescriptions'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          final List<dynamic> data = jsonResponse['data'];
          return data.map((json) => Medication.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      // error logging
      return [];
    }
  }

  Future<List<AdherenceLog>> getAdherenceLogs(
    int patientId, {
    int? limit,
  }) async {
    try {
      String url = '$baseUrl/patient/$patientId/adherence_logs';
      if (limit != null) {
        url += '?limit=$limit';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          final List<dynamic> data = jsonResponse['data'];
          return data.map((json) => AdherenceLog.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      // error logging
      return [];
    }
  }

  Future<bool> recordMedicationTaken(int prescriptionId, int deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/record_medication'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prescription_id': prescriptionId,
          'device_id': deviceId,
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      // error logging
      return false;
    }
  }

  Future<List<NotificationModel>> getNotifications(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patient/$patientId/notifications'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          final List<dynamic> data = jsonResponse['data'];
          return data.map((json) => NotificationModel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      // error logging
      return [];
    }
  }

  Future<bool> markNotificationRead(int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notification/$notificationId/read'),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      // error logging
      return false;
    }
  }

  Future<AIPrediction?> getAIPrediction(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patient/$patientId/ai_prediction'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return AIPrediction.fromJson(jsonResponse['data']);
        }
      }
      return null;
    } catch (e) {
      // error logging
      return null;
    }
  }

  Future<Map<String, dynamic>> getAdherenceStats(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patient/$patientId/adherence_stats'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return jsonResponse['data'];
        }
      }
      return {
        'taken_count': 0,
        'missed_count': 0,
        'upcoming_count': 0,
        'adherence_score': 0,
      };
    } catch (e) {
      // error logging
      return {
        'taken_count': 0,
        'missed_count': 0,
        'upcoming_count': 0,
        'adherence_score': 0,
      };
    }
  }
}
