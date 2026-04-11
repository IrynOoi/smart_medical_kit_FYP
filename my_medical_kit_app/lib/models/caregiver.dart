//caregiver.dart
class Caregiver {
  final int caregiverId;
  final String fullname;
  final String email;
  final String gender;
  final String phoneNo;
  final DateTime dateOfBirth;
  final String address;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Caregiver({
    required this.caregiverId,
    required this.fullname,
    required this.email,
    required this.gender,
    required this.phoneNo,
    required this.dateOfBirth,
    required this.address,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Caregiver.fromJson(Map<String, dynamic> json) {
    return Caregiver(
      caregiverId: json['caregiver_id'],
      fullname: json['fullname'],
      email: json['email'],
      gender: json['gender'] ?? '',
      phoneNo: json['phone_no'] ?? '',
      dateOfBirth: DateTime.parse(json['date_of_birth']),
      address: json['address'] ?? '',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'caregiver_id': caregiverId,
      'fullname': fullname,
      'email': email,
      'gender': gender,
      'phone_no': phoneNo,
      'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
      'address': address,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
