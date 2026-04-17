// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient.dart';
import '../models/medication.dart';
import '../models/adherence_log.dart';
import '../models/notification.dart';
import '../models/ai_prediction.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl =
      'https://reluctant-scrambled-badge.ngrok-free.dev';

  // ==========================================
  // 🔐 AUTHENTICATION ENDPOINTS
  // ==========================================

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print("🚀 [API] Preparing to send login request to: $baseUrl/login");

      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      print("📥 [API] Received response status code: ${response.statusCode}");
      print(
        "📥 [API] Received raw server response: ${response.body}",
      ); // 👈 most important

      return jsonDecode(response.body);
    } catch (e) {
      print("❌ [API] Critical error occurred: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json,',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(userData),
      );
      return jsonDecode(response.body);
    } catch (e) {
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
          return Patient.fromJson(jsonResponse['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting patient: $e');
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
      print('Error getting medications: $e');
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
      print('Error getting adherence logs: $e');
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
      print('Error recording medication: $e');
      return false;
    }
  }

  Future<Map<String, List<double>>> getChartData(
    int caregiverId,
    String period,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/caregiver/$caregiverId/chart_data?period=$period'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['success']) {
          // 🌟 正確解析 Python 傳來的 {"taken": [...], "missed": [...]}
          final takenList = (json['data']['taken'] as List)
              .map((e) => (e as num).toDouble())
              .toList();
          final missedList = (json['data']['missed'] as List)
              .map((e) => (e as num).toDouble())
              .toList();

          return {'taken': takenList, 'missed': missedList};
        }
      }

      return _emptyChartData(period);
    } catch (e) {
      debugPrint('Error getting chart data: $e');
      return _emptyChartData(period);
    }
  }

  Future<List<dynamic>> getPatientPrescriptions(int patientId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/patient/$patientId/prescriptions'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    throw Exception('Failed to load prescriptions');
  }

  // 產生預設的空陣列，防止 UI 崩潰
  Map<String, List<double>> _emptyChartData(String period) {
    int length = period == 'Month' ? 4 : (period == 'Day' ? 6 : 7);
    return {
      'taken': List.filled(length, 0.0),
      'missed': List.filled(length, 0.0),
    };
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
      print('Error getting notifications: $e');
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
      print('Error marking notification read: $e');
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
      print('Error getting AI prediction: $e');
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
      print('Error getting adherence stats: $e');
      return {
        'taken_count': 0,
        'missed_count': 0,
        'upcoming_count': 0,
        'adherence_score': 0,
      };
    }
  }

  // ==========================================
  // 👤 CAREGIVER ENDPOINTS
  // ==========================================

  Future<Map<String, dynamic>> getCaregiverOverview(int caregiverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/caregiver/$caregiverId/overview_stats'),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success']) return json['data'];
      }
      return {
        'taken_count': 0,
        'missed_count': 0,
        'pending_count': 0,
        'total_patients': 0,
        'low_stock_count': 0,
      };
    } catch (e) {
      print('Error getting caregiver overview: $e');
      return {
        'taken_count': 0,
        'missed_count': 0,
        'pending_count': 0,
        'total_patients': 0,
        'low_stock_count': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getAllRecentLogs(int caregiverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/caregiver/$caregiverId/all_recent_logs?limit=20'),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success']) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting all logs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCaregiverPatients(
    int caregiverId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/caregiver/$caregiverId/patients'),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success']) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting caregiver patients: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCaregiverAlerts(int caregiverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/caregiver/$caregiverId/recent_alerts'),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success']) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting caregiver alerts: $e');
      return [];
    }
  }

  // ==========================================
  // 📊 AI ANALYTICS ENDPOINTS
  // ==========================================

  Future<Map<String, dynamic>> getAnalyticsOverview(int caregiverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/caregiver/$caregiverId/analytics_overview'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return jsonResponse['data'];
        }
      }
      return {
        'overall_adherence_prediction': 85.0,
        'high_risk_patients': 0,
        'medium_risk_patients': 0,
        'total_analyzed': 0,
      };
    } catch (e) {
      print('Error getting analytics overview: $e');
      return {
        'overall_adherence_prediction': 85.0,
        'high_risk_patients': 0,
        'medium_risk_patients': 0,
        'total_analyzed': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getAtRiskPatients(int caregiverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/caregiver/$caregiverId/at_risk_patients'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting at-risk patients: $e');
      return [];
    }
  }
}
