// lib/services/api/caregiver_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class CaregiverService {
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

  Future<List<Map<String, dynamic>>> getCaregiverPatients(
    int caregiverId,
  ) async {
    try {
      final response = await ApiClient.get('/caregiver/$caregiverId/patients');
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

  Map<String, List<double>> _emptyChartData(String period) {
    int length = period == 'Month' ? 4 : (period == 'Day' ? 6 : 7);
    return {
      'taken': List.filled(length, 0.0),
      'missed': List.filled(length, 0.0),
    };
  }

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
}
