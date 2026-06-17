//medication.dart
enum Status { pending, taken, missed, snoozed }

class Medication {
  final int prescriptionId;
  final int patientId;
  final String medicationName;
  final double dosageTablet;
  final List<String> dispenseTimes;
  final int currentInventory;
  final int refillThreshold;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? deviceId;

  Medication({
    required this.prescriptionId,
    required this.patientId,
    required this.medicationName,
    required this.dosageTablet,
    required this.dispenseTimes,
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

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      prescriptionId: json['prescription_id'],
      patientId: json['patient_id'],
      medicationName: json['medication_name'],
      dosageTablet: json['dosage_tablet'].toDouble(),
      dispenseTimes: json['dispense_times'] != null
          ? List<String>.from(json['dispense_times'])
          : [],
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
}
