// lib/models/medication_log.dart

class MedicationLog {
  final int id;
  final int? patientId;
  final int? age;
  final String? dayOfWeek;
  final String? timeOfDay;
  final int? status;
  final DateTime timestamp;

  MedicationLog({
    required this.id,
    this.patientId,
    this.age,
    this.dayOfWeek,
    this.timeOfDay,
    this.status,
    required this.timestamp,
  });

  factory MedicationLog.fromJson(Map<String, dynamic> json) {
    return MedicationLog(
      id: json['id'],
      patientId: json['patient_id'],
      age: json['age'],
      dayOfWeek: json['day_of_week'],
      timeOfDay: json['time_of_day'],
      status: json['status'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'age': age,
      'day_of_week': dayOfWeek,
      'time_of_day': timeOfDay,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
