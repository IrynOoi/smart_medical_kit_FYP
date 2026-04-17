// lib/models/prescription.dart

class Prescription {
  final int prescriptionId;
  final int patientId;
  final String medicationName;
  final double dosageTablet;
  final String dispenseSchedule;
  final int currentInventory;
  final int refillThreshold;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? deviceId;

  Prescription({
    required this.prescriptionId,
    required this.patientId,
    required this.medicationName,
    required this.dosageTablet,
    required this.dispenseSchedule,
    required this.currentInventory,
    required this.refillThreshold,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.deviceId,
  });

  bool get isLowStock => currentInventory <= refillThreshold;
  bool get isOutOfStock => currentInventory <= 0;

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      prescriptionId: json['prescription_id'],
      patientId: json['patient_id'],
      medicationName: json['medication_name'],
      dosageTablet: json['dosage_tablet'].toDouble(),
      dispenseSchedule: json['dispense_schedule'],
      currentInventory: json['current_inventory'] ?? 0,
      refillThreshold: json['refill_threshold'] ?? 5,
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      deviceId: json['device_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prescription_id': prescriptionId,
      'patient_id': patientId,
      'medication_name': medicationName,
      'dosage_tablet': dosageTablet,
      'dispense_schedule': dispenseSchedule,
      'current_inventory': currentInventory,
      'refill_threshold': refillThreshold,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
    };
  }
}