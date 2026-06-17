// lib/models/user.dart

class User {
  final int userId;
  final String email;
  final String password;
  final String role; // 'patient' or 'caregiver'
  final String fullName;
  final String? phoneNo;
  final String? address;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? profilePhoto;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.userId,
    required this.email,
    required this.password,
    required this.role,
    required this.fullName,
    this.phoneNo,
    this.address,
    this.gender,
    this.dateOfBirth,
    this.profilePhoto,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] ?? 0,
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      role: json['role'] ?? '',
      fullName: json['full_name'] ?? 'Unknown User',
      phoneNo: json['phone_no'],
      address: json['address'],
      gender: json['gender'],
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'])
          : null,
      profilePhoto: json['profile_photo'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'password': password,
      'role': role,
      'full_name': fullName,
      'phone_no': phoneNo,
      'address': address,
      'gender': gender,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
      'profile_photo': profilePhoto,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
