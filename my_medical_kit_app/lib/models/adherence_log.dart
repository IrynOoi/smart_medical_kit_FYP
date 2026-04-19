// lib/models/adherence_log.dart
class AdherenceLog {
  final int logId;
  final int patientId;
  final String status;
  final DateTime? scheduledTime;
  final DateTime? takenTime; // holds dispensed_time from API
  final String? medicationName;
  final int? deviceId; // ✅ New field

  bool get isTaken => status.toUpperCase() == 'TAKEN';
  bool get isMissed => status.toUpperCase() == 'MISSED';

  AdherenceLog({
    required this.logId,
    required this.patientId,
    required this.status,
    this.scheduledTime,
    this.takenTime,
    this.medicationName,
    this.deviceId,
  });

  factory AdherenceLog.fromJson(Map<String, dynamic> json) {
    return AdherenceLog(
      logId: json['adlog_id'] ?? 0,
      patientId: json['patient_id'] ?? 0,
      status: json['status'] ?? 'PENDING',
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.tryParse(json['scheduled_time'])
          : null,
      takenTime: json['dispensed_time'] != null
          ? DateTime.tryParse(json['dispensed_time'])
          : null,
      medicationName: json['medication_name'] ?? 'Medication',
      deviceId: json['device_id'], // ✅ Parse device_id
    );
  }
}
