//ai_prediction.dart
import 'package:flutter/material.dart';

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
    return AIPrediction(
      adId: json['ad_id'] ?? 0,
      patientId: json['patient_id'] ?? 0,
      predictionScore: (json['prediction_score'] ?? 85.5).toDouble(),
      riskLevel: _parseRiskLevel(json['risk_level'] ?? 'LOW'),
      predictedAt: json['predicted_at'] != null
          ? DateTime.parse(json['predicted_at'])
          : DateTime.now(),
      featuresUsed: json['features_used'] is Map
          ? Map<String, dynamic>.from(json['features_used'])
          : null,
    );
  }

  static RiskLevel _parseRiskLevel(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':
        return RiskLevel.low;
      case 'MEDIUM':
        return RiskLevel.medium;
      case 'HIGH':
        return RiskLevel.high;
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
      'features_used': featuresUsed,
    };
  }
}
