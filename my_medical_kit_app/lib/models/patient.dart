//patient.dart
// lib/models/patient.dart

import 'user.dart';

class Patient {
  final int patientId;      // same as user_id
  final int? caregiverId;
  final String? medicalNotes;
  final User user;          // embedded user data

  Patient({
    required this.patientId,
    this.caregiverId,
    this.medicalNotes,
    required this.user,
  });

  String get fullName => user.fullName;
  String get email => user.email;
  String? get phoneNo => user.phoneNo;
  String? get address => user.address;
  String? get gender => user.gender;
  DateTime? get dateOfBirth => user.dateOfBirth;
  bool get isActive => user.isActive;
  String? get profilePhoto => user.profilePhoto;

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      patientId: json['patient_id'],
      caregiverId: json['caregiver_id'],
      medicalNotes: json['medical_notes'],
      user: User.fromJson(json['user'] ?? {}), // requires nested user object
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient_id': patientId,
      'caregiver_id': caregiverId,
      'medical_notes': medicalNotes,
      'user': user.toJson(),
    };
  }
}