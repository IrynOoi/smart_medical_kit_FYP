// lib/models/patient.dart
import 'user.dart';
import 'caregiver.dart'; // 确保导入了 Caregiver 模型

class Patient {
  final int patientId;
  final int? caregiverId;
  final String? medicalNotes;
  final User user;
  final Caregiver? caregiver; // 新增字段

  Patient({
    required this.patientId,
    this.caregiverId,
    this.medicalNotes,
    required this.user,
    this.caregiver,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      patientId: json['patient_id'],
      caregiverId: json['caregiver_id'],
      medicalNotes: json['medical_notes'],
      user: User.fromJson(json['user'] ?? {}),
      caregiver: json['caregiver'] != null
          ? Caregiver.fromJson(json['caregiver'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient_id': patientId,
      'caregiver_id': caregiverId,
      'medical_notes': medicalNotes,
      'user': user.toJson(),
      'caregiver': caregiver?.toJson(),
    };
  }
}
