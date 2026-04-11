//ai_prediction.dart
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
    RiskLevel parseRiskLevel(String level) {
      switch (level.toLowerCase()) {
        case 'medium':
          return RiskLevel.medium;
        case 'high':
          return RiskLevel.high;
        default:
          return RiskLevel.low;
      }
    }

    return AIPrediction(
      adId: json['ad_id'],
      patientId: json['patient_id'],
      predictionScore: json['prediction_score'].toDouble(),
      riskLevel: parseRiskLevel(json['risk_level']),
      predictedAt: DateTime.parse(json['predicted_at']),
      featuresUsed: json['features_used'] != null
          ? Map<String, dynamic>.from(json['features_used'])
          : null,
    );
  }
}
