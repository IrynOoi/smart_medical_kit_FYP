// lib/services/reminder_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/prescription.dart';

class ReminderService {
  static const String reminderTask = "medicationReminderTask";
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Initialize notifications
    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
    );
    await _notifications.initialize(settings);

    // Register background task
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    await Workmanager().registerPeriodicTask(
      "reminderCheck",
      reminderTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static void callbackDispatcher() {
    Workmanager().executeTask((taskName, inputData) async {
      if (taskName == reminderTask) {
        await _checkAndSendReminders();
      }
      return Future.value(true);
    });
  }

  static Future<void> _checkAndSendReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getInt('patient_id');
    if (patientId == null || patientId <= 0) return;

    final api = ApiService();
    final prescriptions = await api.getPatientMedications(patientId);
    final now = DateTime.now();

    for (final p in prescriptions) {
      if (p.currentInventory <= 0) continue; // skip if out of stock

      final nextTime = _parseNextDoseTime(p.dispenseSchedule, now);
      if (nextTime != null) {
        final diff = nextTime.difference(now);

        // 🚨 防止重复发送通知！
        // 只有当距离吃药时间 45~60 分钟内时，才触发一次提醒。
        // if (diff.inMinutes <= 60 && diff.inMinutes > 45) {
        //   await _showNotification(p.medicationName, p.dosageTablet);
        // }

        if (diff.inMinutes <= 10 && diff.inMinutes >= 0) {
          await _showNotification(p.medicationName, p.dosageTablet);
        }
      }
    }
  }

  static Future<void> _showNotification(String medName, double dosage) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'medication_channel',
          'Medication Reminders',
          channelDescription: 'Reminders to take your medicine',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '💊 Time to take your medicine',
      'Take ${dosage.toStringAsFixed(0)} tablet(s) of $medName.\nPress the button on your medical kit.',
      details,
    );
  }

  static Future<void> showNotification(String medName, double dosage) async {
    await _showNotification(medName, dosage);
  }

  // ✅ 为 FYP 定制的专属 Cron 解析器 (完美处理 "0 8 * * *")
  static DateTime? _parseNextDoseTime(String cronExpr, DateTime from) {
    try {
      // 切割 Cron 字符串: "分钟 小时 日 月 星期"
      List<String> parts = cronExpr.trim().split(RegExp(r'\s+'));
      if (parts.length != 5) return null;

      String minuteStr = parts[0];
      String hourStr = parts[1];

      // 处理日常吃药时间 (例如: 分钟和小时都有具体数字)
      if (minuteStr != '*' && hourStr != '*') {
        int minute = int.parse(minuteStr);
        int hour = int.parse(hourStr);

        // 用手机本地时间构建今天的预定吃药时间
        DateTime scheduledToday = DateTime(
          from.year,
          from.month,
          from.day,
          hour,
          minute,
        );

        // 如果今天的时间已经过了，那下一次吃药就是明天同一时间
        if (scheduledToday.isBefore(from)) {
          return scheduledToday.add(const Duration(days: 1));
        } else {
          return scheduledToday;
        }
      }
      return null;
    } catch (e) {
      print("Error manually parsing cron '$cronExpr': $e");
      return null;
    }
  }
}
