// lib/models/caregiver.dart

import 'user.dart';

class Caregiver {
  final int caregiverId;
  final User user;

  Caregiver({
    required this.caregiverId,
    required this.user,
  });

  factory Caregiver.fromJson(Map<String, dynamic> json) {
    return Caregiver(
      caregiverId: json['caregiver_id'],
      user: User.fromJson(json['user'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'caregiver_id': caregiverId,
      'user': user.toJson(),
    };
  }
}
