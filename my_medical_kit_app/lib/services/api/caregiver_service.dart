// lib/services/api/caregiver_service.dart
// Service class for all caregiver-related API calls (profile, patients, analytics, notifications, linking)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class CaregiverService {
  // ---------------------- Get Caregiver Profile ----------------------
  /// Fetch the full profile of a caregiver (including user details).
  /// Returns a Map with 'success' and 'data' fields.
  /// On error, returns a failure Map.
  Future<Map<String, dynamic>> getCaregiverProfile(int caregiverId) async {
    try {
      final response = await ApiClient.get('/caregiver/$caregiverId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Failed to load profile'};
    } catch (e) {
      debugPrint('Error getting caregiver profile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ---------------------- Get Caregiver's Patients ----------------------
  /// Retrieve the list of patients assigned to this caregiver.
  /// Parameter `show`: 'active' (default), 'inactive', or 'all'.
  /// Returns a List of patient maps, or empty list on error.
  Future<List<Map<String, dynamic>>> getCaregiverPatients(
    int caregiverId, {
    String show = 'active',
  }) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/patients?show=$show',
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success']) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ---------------------- Get At-Risk Patients (AI) ----------------------
  /// Fetch patients flagged as 'at risk' based on AI adherence predictions.
  /// Returns a List of patient maps with risk information.
  Future<List<Map<String, dynamic>>> getAtRiskPatients(int caregiverId) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/at_risk_patients',
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success']) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting at-risk patients: $e');
      return [];
    }
  }

  // ---------------------- Get Low Stock Alerts ----------------------
  /// Retrieve current low-stock/out-of-stock alerts for all medications
  /// under this caregiver's patients.
  /// Returns a List of alert maps (with medication, patient, inventory info).
  Future<List<Map<String, dynamic>>> getLowStockAlerts(int caregiverId) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/low_stock_alerts',
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching low stock alerts: $e');
      return [];
    }
  }

  // ---------------------- Get Caregiver Overview Statistics ----------------------
  /// Returns summary stats for the caregiver dashboard:
  /// taken/missed/pending doses, total patients, low stock count, adherence score, etc.
  /// On error, returns a default zero-filled Map.
  Future<Map<String, dynamic>> getCaregiverOverview(int caregiverId) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/overview_stats',
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
      debugPrint('Error getting caregiver overview: $e');
      return {
        'taken_count': 0,
        'missed_count': 0,
        'pending_count': 0,
        'total_patients': 0,
        'low_stock_count': 0,
      };
    }
  }

  // ---------------------- Get All Recent Adherence Logs ----------------------
  /// Fetch the most recent 20 adherence log entries across all patients of this caregiver.
  /// Returns a List of log maps, or empty list on error.
  Future<List<Map<String, dynamic>>> getAllRecentLogs(int caregiverId) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/all_recent_logs?limit=20',
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success']) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ---------------------- Get Recent Alerts (for Caregiver) ----------------------
  /// Fetches a list of recent alerts (missed doses, low stock, etc.)
  /// for the caregiver. Returns List of alert maps.
  Future<List<Map<String, dynamic>>> getCaregiverAlerts(int caregiverId) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/recent_alerts',
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success']) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ---------------------- Get Chart Data (Adherence over Time) ----------------------
  /// Returns taken/missed counts for a given period ('Day', 'Week', 'Month').
  /// The response contains two lists: 'taken' and 'missed' with lengths:
  ///   - Week: 7 entries
  ///   - Month: 4 entries
  ///   - Day: 6 entries (if using 6-hour intervals)
  /// Returns empty lists on error (all zeros).
  Future<Map<String, List<double>>> getChartData(
    int caregiverId,
    String period,
  ) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/chart_data?period=$period',
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
      return _emptyChartData(period);
    }
  }

  // Helper to generate empty chart data with correct length
  Map<String, List<double>> _emptyChartData(String period) {
    int length = period == 'Month' ? 4 : (period == 'Day' ? 6 : 7);
    return {
      'taken': List.filled(length, 0.0),
      'missed': List.filled(length, 0.0),
    };
  }

  // ---------------------- Get Analytics Overview (AI Summary) ----------------------
  /// Returns a summary of AI predictions for all patients:
  /// overall_adherence_prediction (average score), high/medium risk counts,
  /// total analyzed patients. On error, returns zeros.
  Future<Map<String, dynamic>> getAnalyticsOverview(int caregiverId) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/analytics_overview',
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return jsonResponse['data'];
      }
      return {
        'overall_adherence_prediction': 0.0,
        'high_risk_patients': 0,
        'medium_risk_patients': 0,
        'total_analyzed': 0,
      };
    } catch (e) {
      return {
        'overall_adherence_prediction': 0.0,
        'high_risk_patients': 0,
        'medium_risk_patients': 0,
        'total_analyzed': 0,
      };
    }
  }

  // ---------------------- Get Caregiver Notifications (In-app) ----------------------
  /// Retrieve all in-app notifications for the caregiver (including stock alerts).
  /// Returns a List of notification maps.
  Future<List<Map<String, dynamic>>> getCaregiverNotifications(
    int caregiverId,
  ) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/notifications',
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching caregiver notifications: $e');
      return [];
    }
  }

  // ---------------------- Get Stock Notifications (Aggregated) ----------------------
  /// Returns a formatted list of stock notifications, grouped by medication,
  /// showing worst status and affected patients.
  Future<List<Map<String, dynamic>>> getCaregiverStockNotifications(
    int caregiverId,
  ) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/stock_notifications',
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching caregiver stock notifications: $e');
      return [];
    }
  }

  // ---------------------- Get Low Stock Alerts (Alternative) ----------------------
  /// Similar to getLowStockAlerts, but may return raw alert rows.
  /// (Keep for compatibility.)
  Future<List<Map<String, dynamic>>> getCaregiverLowStockAlerts(
    int caregiverId,
  ) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/low_stock_alerts',
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching low stock alerts: $e');
      return [];
    }
  }

  // ---------------------- Mark a Notification as Read ----------------------
  /// Mark a single caregiver notification as read by its notification_id.
  /// Returns true on success, false otherwise.
  Future<bool> markCaregiverNotificationRead(int notificationId) async {
    try {
      final response = await ApiClient.put(
        '/caregiver/notification/$notificationId/read',
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      return false;
    }
  }

  // ---------------------- Get Available Patients (for Linking) ----------------------
  /// Retrieve patients that are not currently assigned to this caregiver.
  /// Optional `status` filter: 'active', 'inactive', 'all' (default 'all').
  /// Returns a List of patient maps.
  Future<List<Map<String, dynamic>>> getAvailablePatients(
    int caregiverId, {
    String status = 'all',
  }) async {
    try {
      final response = await ApiClient.get(
        '/caregiver/$caregiverId/available_patients?status=$status',
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching available patients: $e');
      return [];
    }
  }

  // ---------------------- Deactivate Caregiver Account (Soft Delete) ----------------------
  /// Deactivate the caregiver account (set is_active = False).
  /// Returns true on success, false otherwise.
  Future<bool> deactivateCaregiver(int caregiverId) async {
    try {
      final response = await ApiClient.put(
        '/caregiver/$caregiverId/deactivate',
      );
      final json = jsonDecode(response.body);
      return json['success'] == true;
    } catch (e) {
      debugPrint('Error deactivating caregiver: $e');
      return false;
    }
  }

  // ---------------------- Link a Patient to Caregiver ----------------------
  /// Assign a patient to this caregiver.
  /// Returns true on success, false otherwise.
  Future<bool> linkPatient(int caregiverId, int patientId) async {
    try {
      final response = await ApiClient.post(
        '/caregiver/$caregiverId/link_patient',
        body: {'patient_id': patientId},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error linking patient: $e');
      return false;
    }
  }

  // ---------------------- Unlink a Patient from Caregiver ----------------------
  /// Remove the patient from this caregiver (set cg_id = NULL).
  /// Returns true on success, false otherwise.
  Future<bool> unlinkPatient(int caregiverId, int patientId) async {
    try {
      final response = await ApiClient.delete(
        '/caregiver/$caregiverId/unlink_patient/$patientId',
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error unlinking patient: $e');
      return false;
    }
  }
}
