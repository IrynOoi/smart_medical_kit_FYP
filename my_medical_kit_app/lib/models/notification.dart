// lib/models/notification.dart

class NotificationModel {
  final int notificationId;
  final int patientId;
  final String title;
  final String message;
  final String type; // 🌟 Added the type property
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.patientId,
    required this.title,
    required this.message,
    required this.type, // 🌟 Added to constructor
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notification_id'],
      patientId: json['patient_id'],
      title: json['title'],
      message: json['message'],
      // 🌟 Added to JSON parser (with a fallback just in case)
      type: json['type'] ?? 'REMINDER',
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notification_id': notificationId,
      'patient_id': patientId,
      'title': title,
      'message': message,
      'type': type, // 🌟 Added to JSON output
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
