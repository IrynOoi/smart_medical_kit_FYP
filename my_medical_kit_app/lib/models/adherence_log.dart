//adherence_log.dart
import 'medication.dart';

class AdherenceLog {
  final int adlogId;
  final int prescriptionId;
  final int deviceId;
  final DateTime scheduledTime;
  final DateTime? dispensedTime;
  final Status status;
  final DateTime recordedAt;
  final String? medicationName; // ✅ ADD THIS

  AdherenceLog({
    required this.adlogId,
    required this.prescriptionId,
    required this.deviceId,
    required this.scheduledTime,
    this.dispensedTime,
    required this.status,
    required this.recordedAt,
    this.medicationName, // ✅ ADD THIS
  });

  bool get isTaken => status == Status.taken;
  bool get isMissed => status == Status.missed;
  bool get isPending => status == Status.pending;

  factory AdherenceLog.fromJson(Map<String, dynamic> json) {
    Status parseStatus(String status) {
      switch (status.toLowerCase()) {
        case 'taken':
          return Status.taken;
        case 'missed':
          return Status.missed;
        case 'snoozed':
          return Status.snoozed;
        default:
          return Status.pending;
      }
    }

    return AdherenceLog(
      adlogId: json['adlog_id'],
      prescriptionId: json['prescription_id'],
      deviceId: json['device_id'],
      scheduledTime: DateTime.parse(json['scheduled_time']),
      dispensedTime: json['dispensed_time'] != null
          ? DateTime.parse(json['dispensed_time'])
          : null,
      status: parseStatus(json['status']),
      recordedAt: DateTime.parse(json['recorded_at']),
      medicationName: json['medication_name'], // ✅ MAP THIS
    );
  }
}
