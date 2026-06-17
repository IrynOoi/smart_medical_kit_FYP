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
      print("📥 [API] Received raw server response: ${response.body}");

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
        print('Caregiver data: ${jsonResponse['data']['caregiver']}');
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
        headers: {'ngrok-skip-browser-warning': 'true'},
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

  Future<bool> createNotification({
    required int patientId,
    required String title,
    required String message,
    String type = 'REMINDER',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'title': title,
          'message': message,
          'type': type,
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      print('Error creating notification: $e');
      return false;
    }
  }

  Future<bool> markNotificationRead(int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notification/$notificationId/read'),
        headers: {'ngrok-skip-browser-warning': 'true'},
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

  // Future<List<Map<String, dynamic>>> getCaregiverAlerts(int caregiverId) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/caregiver/$caregiverId/recent_alerts'),
  //     );
  //     if (response.statusCode == 200) {
  //       final json = jsonDecode(response.body);
  //       if (json['success']) {
  //         return List<Map<String, dynamic>>.from(json['data']);
  //       }
  //     }
  //     return [];
  //   } catch (e) {
  //     print('Error getting caregiver alerts: $e');
  //     return [];
  //   }
  // }

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
      return {
        'overall_adherence_prediction': 0.0,
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
        return jsonResponse['data'];
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

  // ==========================================
  // 🛠️ DEVICE & INVENTORY
  // ==========================================

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

  // ==========================================
  // 🎮 HARDWARE CONTROL (via backend proxy)
  // ==========================================

  Future<bool> controlLed(int patientId, bool turnOn) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/device/control/led'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'action': turnOn ? 'on' : 'off',
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('controlLed error: $e');
      return false;
    }
  }

  Future<bool> controlBuzzer(int patientId, bool turnOn) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/device/control/buzzer'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'action': turnOn ? 'on' : 'off',
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('controlBuzzer error: $e');
      return false;
    }
  }

  Future<bool> controlDisplay(int patientId, String command) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/device/control/display'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'patient_id': patientId, 'command': command}),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('controlDisplay error: $e');
      return false;
    }
  }

  Future<bool> controlStepper(int patientId, int motor, String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/device/control/stepper'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'motor': motor,
          'action': action,
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('controlStepper error: $e');
      return false;
    }
  }

  // ==========================================
  // 👤 UPDATE & DELETE
  // ==========================================

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
      formData.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });
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

  Future<bool> updateDevice(int deviceId, String newSerial) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/iot_device/$deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'device_serial': newSerial}),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('updateDevice error: $e');
      return false;
    }
  }

  Future<bool> deleteDevice(int deviceId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/iot_device/$deviceId'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('deleteDevice error: $e');
      return false;
    }
  }

  Future<bool> addDevice(String serial, String ip, int battery) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/iot_device'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'device_serial': serial,
          'last_known_ip': ip ?? '',
          'battery': battery,
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('addDevice error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPrescriptionForDevicePatient(
    int deviceId,
    int patientId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/device/$deviceId/patient/$patientId/prescription'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return jsonResponse['data'];
      }
      return null;
    } catch (e) {
      debugPrint('getPrescriptionForDevicePatient error: $e');
      return null;
    }
  }

  Future<bool> assignPatientToDevice(
    int deviceId,
    int patientId,
    int motorSlot,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/device/$deviceId/assign_patient'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'patient_id': patientId, 'motor_slot': motorSlot}),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('assignPatientToDevice error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMedications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/medications'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('getMedications error: $e');
      return [];
    }
  }

  // Future<Map<String, dynamic>> addMedication(String name) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/medications'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'ngrok-skip-browser-warning': 'true',
  //       },
  //       body: jsonEncode({'medication_name': name}),
  //     );
  //     return jsonDecode(response.body);
  //   } catch (e) {
  //     debugPrint('addMedication error: $e');
  //     return {'success': false, 'error': e.toString()};
  //   }
  // }

  // ==========================================
  // 🏭 DEVICE + PRESCRIPTION (combined)
  // ==========================================

  Future<bool> createDeviceWithPrescription({
    required String serial,
    required int patientId,
    required int motorSlot,
    required int medicationId,
    required int inventory,
    required int threshold,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/device/create_with_prescription'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'device_serial': serial,
          'patient_id': patientId,
          'motor_slot': motorSlot,
          'medication_id': medicationId,
          'current_inventory': inventory,
          'refill_threshold': threshold,
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('createDeviceWithPrescription error: $e');
      return false;
    }
  }

  Future<bool> updateDevicePrescription({
    required int deviceId,
    required int patientId,
    required int motorSlot,
    required int medicationId,
    required int inventory,
    required int threshold,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/device/$deviceId/prescription'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'motor_slot': motorSlot,
          'medication_id': medicationId,
          'current_inventory': inventory,
          'refill_threshold': threshold,
        }),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('updateDevicePrescription error: $e');
      return false;
    }
  }

  // Future<Map<String, dynamic>> updateMedication(
  //   int medicationId,
  //   String newName,
  // ) async {
  //   try {
  //     final response = await http.put(
  //       Uri.parse('$baseUrl/medications/$medicationId'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'ngrok-skip-browser-warning': 'true',
  //       },
  //       body: jsonEncode({'medication_name': newName}),
  //     );
  //     return jsonDecode(response.body);
  //   } catch (e) {
  //     debugPrint('updateMedication error: $e');
  //     return {'success': false, 'error': e.toString()};
  //   }
  // }

  Future<Map<String, dynamic>> deleteMedication(int medicationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/medications/$medicationId'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('deleteMedication error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addPrescription(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_prescription'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('Error adding prescription: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/devices'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting devices: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getDevice(int deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/device/$deviceId'),
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

  Future<int?> getPatientIdFromDevice(int deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/device/$deviceId/patient'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] && jsonResponse['data'] != null) {
          return jsonResponse['data']['patient_id'] as int;
        }
      }
      return null;
    } catch (e) {
      print('Error getting patient from device: $e');
      return null;
    }
  }

  Future<List<Prescription>> getDevicePrescriptions(int deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/device/$deviceId/prescriptions'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          final List<dynamic> data = jsonResponse['data'];
          return data.map((json) => Prescription.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting device prescriptions: $e');
      return [];
    }
  }

  // Add medication with extra fields
  Future<Map<String, dynamic>> addMedication({
    required String name,
    int currentInventory = 0,
    int refillThreshold = 5,
    int? deviceId,
    int? motorSlot,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/medications'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'medication_name': name,
          'current_inventory': currentInventory,
          'refill_threshold': refillThreshold,
          'device_id': deviceId,
          'motor_slot': motorSlot,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Update medication with all fields
  Future<Map<String, dynamic>> updateMedication({
    required int medicationId,
    String? newName,
    int? currentInventory,
    int? refillThreshold,
    int? deviceId,
    int? motorSlot,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (newName != null) body['medication_name'] = newName;
      if (currentInventory != null) {
        body['current_inventory'] = currentInventory;
      }
      if (refillThreshold != null) body['refill_threshold'] = refillThreshold;
      if (deviceId != null) body['device_id'] = deviceId;
      if (motorSlot != null) body['motor_slot'] = motorSlot;

      final response = await http.put(
        Uri.parse('$baseUrl/medications/$medicationId'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Add this inside your ApiService class
  Future<bool> markSingleReminderRead(
    int patientId,
    String medicationName,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/patient/$patientId/reminders/read_single'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'medication_name': medicationName}),
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      print('Error marking single reminder read: $e');
      return false;
    }
  }

  Future<bool> markAllRemindersRead(int patientId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/patient/$patientId/reminders/read'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      print('Error marking all reminders read: $e');
      return false;
    }
  }
}
