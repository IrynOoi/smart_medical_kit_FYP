// lib/services/reminder_service.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../models/prescription.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'app_navigator.dart';

@pragma('vm:entry-point')
void reminderCallbackDispatcher() {
  ReminderService.callbackDispatcher();
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {}

class ReminderService {
  static const String reminderTask = 'medicationReminderTask';
  static const String _payloadSmartReminder = 'smart_reminder';
  static const String _payloadCaregiverStock = 'caregiver_stock_alert';
  static const String _channelId = 'medication_channel';
  static const String _channelName = 'Medication Reminders';
  static const String _channelDescription = 'Reminders to take your medicine';
  static const String _stockChannelId = 'caregiver_stock_channel';
  static const String _stockChannelName = 'Caregiver Stock Alerts';
  static const String _stockChannelDescription =
      'Low stock and out of stock medicine alerts for caregivers';
  static const String _askedExactAlarmPermissionKey =
      'asked_exact_alarm_permission';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _notificationsInitialized = false;
  static bool _timeZoneInitialized = false;

  static Future<void> init() async {
    await _initializeTimeZone();
    await _initializeNotifications();

    // await Workmanager().initialize(reminderCallbackDispatcher);
    // await Workmanager().registerPeriodicTask(
    //   'reminderCheck',
    //   reminderTask,
    //   frequency: const Duration(minutes: 15),
    // );

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final patientId = prefs.getInt('patient_id');
    if ((role == null || role == 'patient') &&
        patientId != null &&
        patientId > 0) {
      unawaited(scheduleUpcomingMedicationReminders(patientId));
    }

    final caregiverId = prefs.getInt('caregiver_id');
    if ((role == null || role == 'caregiver') &&
        caregiverId != null &&
        caregiverId > 0) {
      unawaited(checkAndSendCaregiverStockAlerts(caregiverId: caregiverId));
    }
  }

  static Future<void> _initializeTimeZone() async {
    if (_timeZoneInitialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    _timeZoneInitialized = true;
  }

  static Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final launchDetails = await _notifications
        .getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        response != null) {
      _handleNotificationResponse(response);
    }

    _notificationsInitialized = true;
  }

  static Future<bool> requestNotificationPermissions({
    bool requestExactAlarms = false,
  }) async {
    await _initializeNotifications();
    bool granted = true;

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? true;

      if (requestExactAlarms) {
        final prefs = await SharedPreferences.getInstance();
        final alreadyAsked =
            prefs.getBool(_askedExactAlarmPermissionKey) ?? false;
        if (!alreadyAsked) {
          await android.requestExactAlarmsPermission();
          await prefs.setBool(_askedExactAlarmPermissionKey, true);
        }
      }
    }
    return granted;
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload == _payloadSmartReminder) {
      unawaited(_openSmartReminderWhenReady());
      return;
    }

    if (response.payload == _payloadCaregiverStock) {
      unawaited(_openCaregiverNotificationsWhenReady());
    }
  }

  static Future<void> _openSmartReminderWhenReady() async {
    for (int i = 0; i < 12; i++) {
      if (openSmartReminderPage()) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  static Future<void> _openCaregiverNotificationsWhenReady() async {
    for (int i = 0; i < 12; i++) {
      if (openCaregiverNotificationsPage()) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((taskName, inputData) async {
      WidgetsFlutterBinding.ensureInitialized();
      await _initializeTimeZone();
      await _initializeNotifications();

      if (taskName == reminderTask) {
        await checkAndSendReminders();
      }
      return Future.value(true);
    });
  }

  static Future<void> checkAndSendReminders({
    List<Prescription>? medications,
  }) async {
    await _initializeNotifications();

    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getInt('patient_id');
    if (patientId == null || patientId <= 0) return;

    final prescriptions =
        medications ??
        await MedicationService().getPatientMedications(patientId);
    final now = DateTime.now();

    // 只检查未来 15 分钟内或者刚刚错过的药物
    final windowStart = now.subtract(const Duration(minutes: 5));
    final windowEnd = now.add(const Duration(minutes: 15));

    for (final p in prescriptions) {
      if (p.currentInventory <= 0) continue;

      final dueTimes = _doseTimesBetween(p, windowStart, windowEnd);
      for (final scheduledAt in dueTimes) {
        final recordedKey = _recordedCacheKey(p.prescriptionId, scheduledAt);
        final systemShownKey = _systemShownCacheKey(
          p.prescriptionId,
          scheduledAt,
        );

        final alreadyRecorded = prefs.getBool(recordedKey) ?? false;
        final alreadyShown = prefs.getBool(systemShownKey) ?? false;

        // 如果 WorkManager 抓到了，并且系统还没弹正点通知，补弹一次
        if (!alreadyShown &&
            scheduledAt.isBefore(now.add(const Duration(minutes: 1)))) {
          await _showNotification(
            p.medicationName,
            p.dosageTablet,
            isFrenzy: false,
          );
          await prefs.setBool(systemShownKey, true);
        }

        if (!alreadyRecorded) {
          await _createInAppNotificationOnce(
            prefs: prefs,
            patientId: patientId,
            prescription: p,
            scheduledAt: scheduledAt,
          );
        }
      }
    }
  }

  static Future<void> checkAndSendCaregiverStockAlerts({
    int? caregiverId,
    List<Map<String, dynamic>>? notifications,
  }) async {
    await _initializeNotifications();

    try {
      await requestNotificationPermissions();
    } catch (e) {
      debugPrint('Caregiver stock notification permission failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final id = caregiverId ?? prefs.getInt('caregiver_id');
    if (id == null || id <= 0) return;

    final stockAlerts =
        notifications ??
        await CaregiverService().getCaregiverStockNotifications(id);

    for (final alert in stockAlerts) {
      final type = (alert['type'] ?? '').toString();
      if (!_isStockAlertType(type) || _isRead(alert['is_read'])) continue;

      final cacheKey = _caregiverStockShownCacheKey(alert);
      if (prefs.getBool(cacheKey) ?? false) continue;

      await _showCaregiverStockNotification(alert);
      await prefs.setBool(cacheKey, true);
    }
  }

  static Future<int> scheduleUpcomingMedicationReminders(
    int patientId, {
    List<Prescription>? medications,
    int daysAhead = 7,
  }) async {
    await _initializeTimeZone();
    await _initializeNotifications();
    try {
      await requestNotificationPermissions(requestExactAlarms: true);
    } catch (e) {
      debugPrint('Reminder permission request failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final scheduledIdsKey = _scheduledIdsKey(patientId);
    final previousIds = prefs.getStringList(scheduledIdsKey) ?? <String>[];
    for (final idText in previousIds) {
      final id = int.tryParse(idText);
      if (id != null) {
        await _notifications.cancel(id);
      }
    }

    final meds =
        medications ??
        await MedicationService().getPatientMedications(patientId);
    final now = DateTime.now();
    final scheduledIds = <String>[];

    for (final med in meds) {
      if (med.currentInventory <= 0) continue;

      final times = _upcomingDoseTimesFor(med, now, daysAhead: daysAhead);

      for (final scheduledAt in times) {
        // 1. 安排准确时间的通知（正点）
        final exactId = _notificationIdFor(med.prescriptionId, scheduledAt);
        final exactScheduled = tz.TZDateTime.from(scheduledAt, tz.local);
        final exactScheduledOk = await _scheduleZonedNotification(
          id: exactId,
          title: '💊 Time to take your medicine NOW!',
          body: _systemReminderMessage(med.medicationName, med.dosageTablet),
          scheduledDate: exactScheduled,
        );
        if (exactScheduledOk) {
          scheduledIds.add(exactId.toString());
          await prefs.setBool(
            _localScheduledCacheKey(med.prescriptionId, scheduledAt),
            true,
          );
        }

        if (_isScheduledTimeActive(scheduledAt, now)) {
          await _createInAppNotificationOnce(
            prefs: prefs,
            patientId: patientId,
            prescription: med,
            scheduledAt: scheduledAt,
          );
        }

        // 🚀 2. 夺命连环 Call（提前 3、2、1 分钟狂 Push）
        for (int minutesBefore in [3, 2, 1]) {
          final advanceTime = scheduledAt.subtract(
            Duration(minutes: minutesBefore),
          );

          if (advanceTime.isAfter(now)) {
            final advId = _notificationIdFor(med.prescriptionId, advanceTime);
            final advScheduled = tz.TZDateTime.from(advanceTime, tz.local);

            // 不同的警告标题
            String pushTitle = minutesBefore == 1
                ? '🚨 Get Ready! 1 min left for ${med.medicationName}!'
                : '⚠️ Upcoming Dose in $minutesBefore mins!';

            final wasScheduledAdv = await _scheduleZonedNotification(
              id: advId,
              title: pushTitle,
              body: 'Please get closer to your MedSmart Kit.',
              scheduledDate: advScheduled,
            );
            if (wasScheduledAdv) {
              scheduledIds.add(advId.toString());
            }
          }
        }
      }
    }

    await prefs.setStringList(scheduledIdsKey, scheduledIds);
    return scheduledIds.length;
  }

  static Future<bool> _scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: _payloadSmartReminder,
      );
      return true;
    } catch (e) {
      debugPrint('Exact reminder schedule failed, using inexact mode: $e');
      return false;
    }
  }

  static Future<void> _showNotification(
    String medName,
    double dosage, {
    bool isFrenzy = false,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      isFrenzy
          ? '🚨 URGENT: Medication Reminder'
          : '💊 Time to take your medicine',
      _systemReminderMessage(medName, dosage),
      _notificationDetails,
      payload: _payloadSmartReminder,
    );
  }

  static Future<void> _showCaregiverStockNotification(
    Map<String, dynamic> alert,
  ) async {
    final type = (alert['type'] ?? '').toString();
    final medicationName = (alert['medication_name'] ?? 'Medicine').toString();
    final patientName = (alert['patient_name'] ?? 'assigned patient')
        .toString();
    final currentInventory = _asInt(alert['current_inventory']) ?? 0;
    final refillThreshold = _asInt(alert['refill_threshold']) ?? 0;
    final title = (alert['title'] ?? '').toString().trim().isNotEmpty
        ? alert['title'].toString()
        : type == 'OUT_OF_STOCK'
        ? 'Medicine Out of Stock'
        : 'Medicine Low Stock';
    final body = type == 'OUT_OF_STOCK'
        ? '$medicationName for $patientName is out of stock. Please restock immediately.'
        : '$medicationName for $patientName is running low. $currentInventory left, threshold $refillThreshold.';

    await _notifications.show(
      _caregiverStockNotificationId(alert),
      title,
      body,
      _stockNotificationDetails,
      payload: _payloadCaregiverStock,
    );
  }

  static Future<void> triggerTestDualNotification(BuildContext context) async {
    await _initializeNotifications();

    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getInt('patient_id');

    if (patientId == null || patientId <= 0) return;

    await _showNotification('Test Aspirin (Debug)', 2.0);

    final success = await PatientService().createNotification(
      patientId: patientId,
      title: 'Debug Reminder Test',
      message:
          'This is a test notification generated at ${DateTime.now().toString().substring(11, 16)}',
      type: 'REMINDER',
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '✅ Debug Notification Sent & Saved!' : '❌ DB save failed.',
        ),
        backgroundColor: success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  static List<DateTime> _doseTimesBetween(
    Prescription prescription,
    DateTime start,
    DateTime end,
  ) {
    return _upcomingDoseTimesFor(
      prescription,
      start,
      daysAhead: end.difference(start).inDays + 1,
    ).where((time) => !time.isAfter(end)).toList();
  }

  static bool isMedicationActiveNow(
    Prescription prescription, {
    DateTime? now,
  }) {
    if (prescription.currentInventory <= 0) return false;
    final reference = now ?? DateTime.now();
    final windowStart = reference.subtract(const Duration(minutes: 5));
    final windowEnd = reference.add(const Duration(minutes: 15));
    return _doseTimesBetween(prescription, windowStart, windowEnd).isNotEmpty;
  }

  static bool _isScheduledTimeActive(DateTime scheduledAt, DateTime now) {
    final windowStart = now.subtract(const Duration(minutes: 5));
    final windowEnd = now.add(const Duration(minutes: 15));
    return !scheduledAt.isBefore(windowStart) &&
        !scheduledAt.isAfter(windowEnd);
  }

  static List<DateTime> _upcomingDoseTimesFor(
    Prescription prescription,
    DateTime from, {
    int daysAhead = 7,
  }) {
    final parts = prescription.dispenseSchedule.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) return <DateTime>[];

    final minutes = _parseCronField(parts[0], min: 0, max: 59);
    final hours = _parseCronField(parts[1], min: 0, max: 23);
    final daysOfMonth = _parseCronField(parts[2], min: 1, max: 31);
    final months = _parseCronField(parts[3], min: 1, max: 12);
    final daysOfWeek = _parseCronField(
      parts[4],
      min: 0,
      max: 7,
      normalizeSunday: true,
    );

    if (minutes.isEmpty ||
        hours.isEmpty ||
        daysOfMonth.isEmpty ||
        months.isEmpty ||
        daysOfWeek.isEmpty) {
      return <DateTime>[];
    }

    final result = <DateTime>[];
    final firstDay = DateTime(from.year, from.month, from.day);
    final prescriptionStart = DateTime(
      prescription.startDate.year,
      prescription.startDate.month,
      prescription.startDate.day,
    );
    final prescriptionEnd = prescription.endDate == null
        ? null
        : DateTime(
            prescription.endDate!.year,
            prescription.endDate!.month,
            prescription.endDate!.day,
            23,
            59,
            59,
          );

    for (int dayOffset = 0; dayOffset <= daysAhead; dayOffset++) {
      final day = firstDay.add(Duration(days: dayOffset));
      final cronWeekday = day.weekday % 7;

      if (!months.contains(day.month) ||
          !daysOfMonth.contains(day.day) ||
          !daysOfWeek.contains(cronWeekday)) {
        continue;
      }

      for (final hour in hours) {
        for (final minute in minutes) {
          final candidate = DateTime(
            day.year,
            day.month,
            day.day,
            hour,
            minute,
          );
          if (!candidate.isAfter(from)) continue;
          if (candidate.isBefore(prescriptionStart)) continue;
          if (prescriptionEnd != null && candidate.isAfter(prescriptionEnd)) {
            continue;
          }
          result.add(candidate);
        }
      }
    }
    result.sort();
    return result;
  }

  static Set<int> _parseCronField(
    String field, {
    required int min,
    required int max,
    bool normalizeSunday = false,
  }) {
    if (field == '*') {
      if (normalizeSunday) return <int>{0, 1, 2, 3, 4, 5, 6};
      return {for (int i = min; i <= max; i++) i};
    }
    final values = <int>{};
    for (final rawPart in field.split(',')) {
      final value = int.tryParse(rawPart.trim());
      if (value == null) continue;
      final normalized = normalizeSunday && value == 7 ? 0 : value;
      if (normalized >= min && normalized <= max) values.add(normalized);
    }
    if (normalizeSunday) values.remove(7);
    return values;
  }

  static int _notificationIdFor(int prescriptionId, DateTime scheduledAt) {
    final minuteBucket = scheduledAt.millisecondsSinceEpoch ~/ 60000;
    return ((prescriptionId * 1000003) + minuteBucket) & 0x7fffffff;
  }

  static int _caregiverStockNotificationId(Map<String, dynamic> alert) {
    final notificationId = _asInt(alert['notification_id']);
    if (notificationId != null) {
      return (900000000 + notificationId) & 0x7fffffff;
    }

    final medicationId = _asInt(alert['medication_id']) ?? 0;
    final patientId = _asInt(alert['patient_id']) ?? 0;
    final deviceId = _asInt(alert['device_id']) ?? 0;
    return ((medicationId * 1000003) + (patientId * 1009) + deviceId) &
        0x7fffffff;
  }

  static String _scheduledIdsKey(int patientId) =>
      'scheduled_reminder_ids_$patientId';

  static String _recordedCacheKey(int prescriptionId, DateTime scheduledAt) =>
      'recorded_${prescriptionId}_${_scheduleKey(scheduledAt)}';

  static String _systemShownCacheKey(
    int prescriptionId,
    DateTime scheduledAt,
  ) => 'system_shown_${prescriptionId}_${_scheduleKey(scheduledAt)}';

  static String _localScheduledCacheKey(
    int prescriptionId,
    DateTime scheduledAt,
  ) => 'local_scheduled_${prescriptionId}_${_scheduleKey(scheduledAt)}';

  static String _caregiverStockShownCacheKey(Map<String, dynamic> alert) {
    final notificationId = _asInt(alert['notification_id']);
    if (notificationId != null) {
      return 'caregiver_stock_shown_$notificationId';
    }

    final type = (alert['type'] ?? '').toString();
    final medicationId = _asInt(alert['medication_id']) ?? 0;
    final patientId = _asInt(alert['patient_id']) ?? 0;
    final deviceId = _asInt(alert['device_id']) ?? 0;
    final currentInventory = _asInt(alert['current_inventory']) ?? 0;
    return 'caregiver_stock_shown_${type}_${medicationId}_${patientId}_${deviceId}_$currentInventory';
  }

  static String _scheduleKey(DateTime scheduledAt) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${scheduledAt.year}${two(scheduledAt.month)}${two(scheduledAt.day)}_${two(scheduledAt.hour)}${two(scheduledAt.minute)}';
  }

  static bool _isStockAlertType(String type) {
    return type == 'LOW_STOCK' || type == 'OUT_OF_STOCK';
  }

  static bool _isRead(dynamic value) {
    return value == true || value == 1 || value == '1' || value == 'true';
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static Future<void> _createInAppNotificationOnce({
    required SharedPreferences prefs,
    required int patientId,
    required Prescription prescription,
    required DateTime scheduledAt,
  }) async {
    final recordedKey = _recordedCacheKey(
      prescription.prescriptionId,
      scheduledAt,
    );
    if (prefs.getBool(recordedKey) ?? false) return;

    // final saved = await PatientService().createNotification(
    //   patientId: patientId,
    //   title: 'Medication Reminder',
    //   message: _inAppReminderMessage(prescription, scheduledAt),
    //   type: 'REMINDER',
    // );

    // if (saved) {
    //   await prefs.setBool(recordedKey, true);
    // }
    await prefs.setBool(recordedKey, true);
  }

  static String _systemReminderMessage(String medName, double dosage) {
    return 'Take ${dosage.toStringAsFixed(0)} tablet(s) of $medName.\nPress the button on your medical kit.';
  }

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      ticker: 'Medication reminder',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static const NotificationDetails _stockNotificationDetails =
      NotificationDetails(
        android: AndroidNotificationDetails(
          _stockChannelId,
          _stockChannelName,
          channelDescription: _stockChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          ticker: 'Caregiver stock alert',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
}
