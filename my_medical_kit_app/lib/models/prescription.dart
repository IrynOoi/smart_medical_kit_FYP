// lib/models/prescription.dart

class Prescription {
  final int prescriptionId;
  final int patientId;
  final String medicationName;
  final double dosageTablet;
  final List<String> dispenseTimes;
  final List<int>? dispenseDays;
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
    required this.dispenseTimes,
    this.dispenseDays,
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
    double parseDosage(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Prescription(
      prescriptionId: json['prescription_id'],
      patientId: json['patient_id'],
      medicationName: json['medication_name'],
      dosageTablet: parseDosage(json['dosage_tablet']),
      dispenseTimes: json['dispense_times'] != null 
          ? List<String>.from(json['dispense_times']) 
          : [],
      dispenseDays: json['dispense_days'] != null
          ? List<int>.from(json['dispense_days'])
          : null,
      currentInventory: json['current_inventory'] ?? 0,
      refillThreshold: json['refill_threshold'] ?? 5,
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
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
      'dispense_times': dispenseTimes,
      'dispense_days': dispenseDays,
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
