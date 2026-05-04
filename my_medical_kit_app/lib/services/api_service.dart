// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient.dart';
import '../models/prescription.dart';
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

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset_password'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'email': email, 'new_password': newPassword}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print("❌ [API] Reset password error: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==========================================
  // 🤖 TRIGGER FRESH HYBRID AI CALCULATION
  // ==========================================
  Future<AIPrediction?> recalculatePrediction(int patientId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict_and_save'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'patient_id': patientId}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return AIPrediction.fromJson(jsonResponse['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error recalculating prediction: $e');
      return null;
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
        print(
          'Caregiver data: ${jsonResponse['data']['caregiver']}',
        ); // 👈 添加这行
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

  Future<List<Prescription>> getPatientMedications(int patientId) async {
    try {
      print('🔵 API: getPatientMedications called for patientId: $patientId');
      final response = await http.get(
        Uri.parse('$baseUrl/patient/$patientId/prescriptions'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      print('🔵 API Response status: ${response.statusCode}');
      print('🔵 API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('🔵 Decoded response: $jsonResponse');
        if (jsonResponse['success']) {
          final List<dynamic> data = jsonResponse['data'];
          print('🔵 Found ${data.length} prescriptions');
          return data.map((json) => Prescription.fromJson(json)).toList();
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
        // ADD THESE HEADERS TO BYPASS NGROK'S WARNING PAGE
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
        },
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
        // ADD HEADERS HERE TOO
        headers: {'ngrok-skip-browser-warning': 'true'},
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

  Future<Map<String, dynamic>> getCaregiverProfile(int caregiverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/caregiver/$caregiverId'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Failed to load profile'};
    } catch (e) {
      print('Error getting caregiver profile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

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
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return jsonResponse['data'];
        }
      }
      // Return empty data - the backend will provide the real average
      return {
        'overall_adherence_prediction': 0.0, // Will be replaced by backend data
        'high_risk_patients': 0,
        'medium_risk_patients': 0,
        'total_analyzed': 0,
      };
    } catch (e) {
      print('Error getting analytics overview: $e');
      return {
        'overall_adherence_prediction': 0.0,
        'high_risk_patients': 0,
        'medium_risk_patients': 0,
        'total_analyzed': 0,
      };
    }
  }

  // ==========================================
  // 🤖 PREDICTION ENDPOINT (single patient)
  // ==========================================

  Future<Map<String, dynamic>> predictAndSaveForPatient({
    required int patientId,
    int age = 60,
    String dayOfWeek = 'Monday',
    String timeOfDay = 'Morning',
    List<int> history = const [1, 1, 1],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict_and_save'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'age': age,
          'day_of_week': dayOfWeek,
          'time_of_day': timeOfDay,
          'history': history,
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['success']) {
        return jsonResponse['data']; // contains prediction_score, risk_level
      }
      return {'error': jsonResponse['error'] ?? 'Unknown error'};
    } catch (e) {
      print('Error calling predict_and_save: $e');
      return {'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getAtRiskPatients(int caregiverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/caregiver/$caregiverId/at_risk_patients'),
        // 👇 Add these headers!
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
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

  // Add to api_service.dart

  // ==========================================
  // 🤖 AI PREDICTION ENDPOINTS
  // ==========================================

  Future<bool> predictAndSave({
    required int patientId,
    required int age,
    required String dayOfWeek,
    required String timeOfDay,
    required List<int> history,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict_and_save'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'age': age,
          'day_of_week': dayOfWeek,
          'time_of_day': timeOfDay,
          'history': history,
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      print('Error predicting for patient: $e');
      return false;
    }
  }

  Future<bool> runBatchPrediction() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/run_ai_analytics_job'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      print('Error running batch prediction: $e');
      return false;
    }
  }

  // Add this to your api_service.dart

  Future<Map<String, dynamic>> getPatientDevice(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/iot_device/patient/$patientId'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return jsonResponse['data'];
        }
      }
      return {};
    } catch (e) {
      print('Error getting device: $e');
      return {};
    }
  }

  Future<bool> restockMedication(int prescriptionId, int quantity) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/restock_medication'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'prescription_id': prescriptionId,
          'quantity': quantity,
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      print('Error restocking: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> updatePatient(
    int patientId,
    Map<String, dynamic> formData, {
    String? photoPath,
  }) async {
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/update_patient/$patientId'),
      );
      // Add text fields
      formData.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });
      // Add photo if provided
      if (photoPath != null && photoPath.isNotEmpty) {
        var file = await http.MultipartFile.fromPath(
          'profile_photo',
          photoPath,
        );
        request.files.add(file);
      }
      request.headers['ngrok-skip-browser-warning'] = 'true';
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addPatient(
    Map<String, dynamic> patientData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(patientData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> deletePatient(int patientId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/patient/$patientId'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      print('Error deleting patient: $e');
      return false;
    }
  }

  Future<bool> updatePrescription(
    int prescriptionId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await put('/prescription/$prescriptionId', data);
      return response['success'] == true;
    } catch (e) {
      print('Update prescription error: $e');
      return false;
    }
  }

  Future<bool> deletePrescription(int prescriptionId) async {
    try {
      final response = await delete('/prescription/$prescriptionId');
      return response['success'] == true;
    } catch (e) {
      print('Delete prescription error: $e');
      return false;
    }
  }

  // ==========================================
  // 🔧 HTTP HELPER METHODS
  // ==========================================

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
