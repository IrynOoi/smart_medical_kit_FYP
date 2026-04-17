// lib/models/adherence_log.dart

class AdherenceLog {
  final int logId;
  final int patientId;
  final String status;
  final DateTime? scheduledTime;
  final DateTime? takenTime;
  final String? medicationName;

  bool get isTaken => status.toUpperCase() == 'TAKEN';
  bool get isMissed => status.toUpperCase() == 'MISSED';

  AdherenceLog({
    required this.logId,
    required this.patientId,
    required this.status,
    this.scheduledTime,
    this.takenTime,
    this.medicationName,
  });

  factory AdherenceLog.fromJson(Map<String, dynamic> json) {
    return AdherenceLog(
      logId: json['log_id'] ?? json['id'] ?? 0,
      patientId: json['patient_id'] ?? 0,
      status: json['status'] ?? 'PENDING',
      scheduledTime: json['scheduled_time'] != null ? DateTime.tryParse(json['scheduled_time']) : null,
      takenTime: json['taken_time'] != null ? DateTime.tryParse(json['taken_time']) : null,
      medicationName: json['medication_name'] ?? json['drug_name'] ?? 'Medication',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_id': logId,
      'patient_id': patientId,
      'status': status,
      'scheduled_time': scheduledTime?.toIso8601String(),
      'taken_time': takenTime?.toIso8601String(),
      'medication_name': medicationName,
    };
  }
}