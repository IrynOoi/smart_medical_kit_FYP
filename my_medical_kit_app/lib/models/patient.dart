//patient.dart
enum Gender { male, female, other }

class Patient {
  final int patientId;
  final int caregiverId;
  final String fullName;
  final DateTime dateOfBirth;
  final Gender? gender;
  final String? address;
  final String? medicalNotes;
  final String? email;
  final String? phoneNo;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Patient({
    required this.patientId,
    required this.caregiverId,
    required this.fullName,
    required this.dateOfBirth,
    this.gender,
    this.address,
    this.medicalNotes,
    this.email,
    this.phoneNo,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  int get age {
    final today = DateTime.now();
    int age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      patientId: json['patient_id'],
      caregiverId: json['caregiver_id'],
      fullName: json['full_name'],
      dateOfBirth: DateTime.parse(json['date_of_birth']),
      gender: json['gender'] != null
          ? Gender.values.firstWhere(
              (e) =>
                  e.toString().split('.').last.toLowerCase() ==
                  json['gender'].toLowerCase(),
              orElse: () => Gender.other,
            )
          : null,
      address: json['address'],
      medicalNotes: json['medical_notes'],
      email: json['email'],
      phoneNo: json['phone_no'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
