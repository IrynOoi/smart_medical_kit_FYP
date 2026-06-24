// lib/models/adherence_log.dart
class AdherenceLog {
  final int logId;
  final int patientId;
  final int? prescriptionId; // 👈 new field
  final String status;
  final DateTime? scheduledTime;
  final DateTime? takenTime;
  final DateTime? recordedAt; // 👈 new field
  final String? medicationName;
  final int? deviceId;

  bool get isTaken => status.toUpperCase() == 'TAKEN';
  bool get isMissed => status.toUpperCase() == 'MISSED';

  AdherenceLog({
    required this.logId,
    required this.patientId,
    this.prescriptionId, // 👈 new param
    required this.status,
    this.scheduledTime,
    this.takenTime,
    this.recordedAt,
    this.medicationName,
    this.deviceId,
  });

  factory AdherenceLog.fromJson(Map<String, dynamic> json) {
    return AdherenceLog(
      logId: json['adlog_id'] ?? 0,
      patientId: json['patient_id'] ?? 0,
      prescriptionId: json['prescription_id'], // 👈 parse it
      status: json['status'] ?? 'PENDING',
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.tryParse(json['scheduled_time'])
          : null,
      takenTime: json['dispensed_time'] != null
          ? DateTime.tryParse(json['dispensed_time'])
          : null,
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'])
          : null,
      medicationName: json['medication_name'] ?? 'Medication',
      deviceId: json['device_id'],
    );
  }

  // Remove the broken getter – use the field directly
}
