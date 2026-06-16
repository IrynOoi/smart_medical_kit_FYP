//ai_prediction.dart

// lib/models/ai_prediction.dart
import 'dart:convert'; // Required for jsonDecode
import 'package:flutter/foundation.dart'; // This defines debugPrint

enum RiskLevel { low, medium, high }

class AIPrediction {
  final int adId;
  final int patientId;
  final double predictionScore;
  final RiskLevel riskLevel;
  final DateTime predictedAt;
  final Map<String, dynamic>? featuresUsed;

  AIPrediction({
    required this.adId,
    required this.patientId,
    required this.predictionScore,
    required this.riskLevel,
    required this.predictedAt,
    this.featuresUsed,
  });

  factory AIPrediction.fromJson(Map<String, dynamic> json) {
    // 1. Robustly parse features_used (handles both String and Map)
    Map<String, dynamic>? parsedFeatures;
    final rawFeatures = json['features_used'];

    if (rawFeatures != null) {
      if (rawFeatures is String) {
        try {
          parsedFeatures = Map<String, dynamic>.from(jsonDecode(rawFeatures));
        } catch (e) {
          debugPrint("Error decoding features_used string: $e");
          parsedFeatures = null;
        }
      } else if (rawFeatures is Map) {
        parsedFeatures = Map<String, dynamic>.from(rawFeatures);
      }
    }

    // 2. Return the instance with safely parsed data
    return AIPrediction(
      adId: json['ad_id'] is int
          ? json['ad_id']
          : int.tryParse(json['ad_id'].toString()) ?? 0,
      patientId: json['patient_id'] is int
          ? json['patient_id']
          : int.tryParse(json['patient_id'].toString()) ?? 0,

      // Ensure we treat the score as the raw value from the database
      predictionScore: (json['prediction_score'] as num?)?.toDouble() ?? 0.0,

      riskLevel: _parseRiskLevel(json['risk_level']?.toString() ?? 'LOW'),

      predictedAt: json['predicted_at'] != null
          ? DateTime.parse(json['predicted_at'])
          : DateTime.now(),

      featuresUsed: parsedFeatures,
    );
  }

  static RiskLevel _parseRiskLevel(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':
        return RiskLevel.high;
      case 'MEDIUM':
        return RiskLevel.medium;
      case 'LOW':
      default:
        return RiskLevel.low;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'ad_id': adId,
      'patient_id': patientId,
      'prediction_score': predictionScore,
      'risk_level': riskLevel.toString().split('.').last.toUpperCase(),
      'predicted_at': predictedAt.toIso8601String(),
      'features_used': featuresUsed != null ? jsonEncode(featuresUsed) : null,
    };
  }
}
