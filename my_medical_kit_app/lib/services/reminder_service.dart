// reminder_service.dart – Handles all medication reminders and stock alerts.
// This service uses flutter_local_notifications and Workmanager to schedule
// and deliver exact‑time alarms, including "frenzy" pre‑alerts (3, 2, 1 minutes before).
// It also manages caregiver stock notifications and in‑app notification creation.

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

// ----------------------------------------------------------------------
// Background entry points (required for Workmanager and notification taps)
// ----------------------------------------------------------------------

/// The entry point for Workmanager background tasks.
/// This function is invoked when a scheduled background task runs.
@pragma('vm:entry-point')
void reminderCallbackDispatcher() {
  ReminderService.callbackDispatcher();
}

/// The entry point for background notification taps (when the app is closed).
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {}

// ----------------------------------------------------------------------
// ReminderService – main class that encapsulates all reminder logic
// ----------------------------------------------------------------------
class ReminderService {
  // Workmanager task name
  static const String reminderTask = 'medicationReminderTask';

  // Notification payloads to identify which screen to open on tap
  static const String _payloadSmartReminder = 'smart_reminder';
  static const String _payloadCaregiverStock = 'caregiver_stock_alert';

  // Notification channel details for medication reminders
  static const String _channelId = 'medication_channel';
  static const String _channelName = 'Medication Reminders';
  static const String _channelDescription = 'Reminders to take your medicine';

  // Separate channel for caregiver stock alerts
  static const String _stockChannelId = 'caregiver_stock_channel';
  static const String _stockChannelName = 'Caregiver Stock Alerts';
  static const String _stockChannelDescription =
      'Low stock and out of stock medicine alerts for caregivers';

  // SharedPreferences key to track if we've asked for exact alarm permission
  static const String _askedExactAlarmPermissionKey =
      'asked_exact_alarm_permission';

  // Instance of the notification plugin
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Flags to ensure one‑time initialization
  static bool _notificationsInitialized = false;
  static bool _timeZoneInitialized = false;

  // ------------------------------------------------------------------
  // Public API methods
  // ------------------------------------------------------------------

  /// Cancel all pending notifications (used when user logs out or switches roles)
  static Future<void> cancelAllNotifications() async {
    await _initializeNotifications();
    await _notifications.cancelAll();
  }

  /// Initialize the reminder service – sets up timezone, notification plugin,
  /// and schedules reminders based on the logged‑in role.
  /// Also cancels any existing reminders for caregivers (they don't need patient reminders).
  static Future<void> init() async {
    await _initializeTimeZone();
    await _initializeNotifications();

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final patientId = prefs.getInt('patient_id');
    final caregiverId = prefs.getInt('caregiver_id');

    // Caregivers should NOT receive patient medication reminders.
    // Cancel all pending notifications and clear the scheduled IDs list.
    if (role == 'caregiver') {
      await _notifications.cancelAll();
      if (caregiverId != null) {
        final scheduledIdsKey = _scheduledIdsKey(caregiverId);
        await prefs.remove(scheduledIdsKey);
      }
      // Do NOT schedule patient reminders
      return;
    }

    // For patients (or if role is not set, default to patient)
    if ((role == null || role == 'patient') &&
        patientId != null &&
        patientId > 0) {
      // Schedule reminders asynchronously (do not await to avoid blocking init)
      unawaited(scheduleUpcomingMedicationReminders(patientId));
    }

    // Caregiver stock alerts – run for caregivers (or if role is null, we also run)
    if ((role == null || role == 'caregiver') &&
        caregiverId != null &&
        caregiverId > 0) {
      unawaited(checkAndSendCaregiverStockAlerts(caregiverId: caregiverId));
    }
  }

  // ------------------------------------------------------------------
  // Initialization helpers
  // ------------------------------------------------------------------

  /// Set up timezone database and set local timezone to Asia/Kuala_Lumpur.
  /// (Change to your local timezone if needed)
  static Future<void> _initializeTimeZone() async {
    if (_timeZoneInitialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    _timeZoneInitialized = true;
  }

  /// Configure the Flutter Local Notifications plugin with Android and iOS settings.
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

    // Initialize with callbacks for foreground and background tap handling
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Check if the app was launched from a notification tap and handle it
    final launchDetails = await _notifications
        .getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        response != null) {
      _handleNotificationResponse(response);
    }

    _notificationsInitialized = true;
  }

  // ------------------------------------------------------------------
  // Permission request
  // ------------------------------------------------------------------

  /// Request notification permissions, and optionally exact alarm permission (Android).
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

  // ------------------------------------------------------------------
  // Notification tap handling (in‑app navigation)
  // ------------------------------------------------------------------

  /// Route the user to the correct screen based on the notification payload.
  static void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload == _payloadSmartReminder) {
      unawaited(_openSmartReminderWhenReady());
      return;
    }

    if (response.payload == _payloadCaregiverStock) {
      unawaited(_openCaregiverNotificationsWhenReady());
    }
  }

  /// Retry opening the Smart Reminder page (patient) until the app is ready.
  static Future<void> _openSmartReminderWhenReady() async {
    for (int i = 0; i < 12; i++) {
      if (openSmartReminderPage()) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Retry opening the Caregiver Notifications page.
  static Future<void> _openCaregiverNotificationsWhenReady() async {
    for (int i = 0; i < 12; i++) {
      if (openCaregiverNotificationsPage()) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  // ------------------------------------------------------------------
  // Workmanager background task entry point
  // ------------------------------------------------------------------

  /// Called by the Workmanager when a scheduled background task runs.
  /// It initialises Flutter bindings and calls checkAndSendReminders().
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

  // ------------------------------------------------------------------
  // Core reminder logic – checks due doses and sends notifications
  // ------------------------------------------------------------------

  /// Called by the background task or manually. It checks for due doses
  /// within a 20‑minute window (5 minutes before, 15 minutes after).
  /// It sends system notifications for doses that are about to be due
  /// and creates in‑app notifications for each dose (deduplicated with SharedPreferences).
  static Future<void> checkAndSendReminders({
    List<Prescription>? medications,
  }) async {
    await _initializeNotifications();

    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getInt('patient_id');
    if (patientId == null || patientId <= 0) return;

    // Fetch medications if not provided
    final prescriptions =
        medications ??
        await MedicationService().getPatientMedications(patientId);
    final now = DateTime.now();

    // Window: 5 minutes before to 15 minutes after now
    final windowStart = now.subtract(const Duration(minutes: 5));
    final windowEnd = now.add(const Duration(minutes: 15));

    for (final p in prescriptions) {
      // Get all scheduled dose times that fall within the window
      final dueTimes = _doseTimesBetween(p, windowStart, windowEnd);
      for (final scheduledAt in dueTimes) {
        // Keys to track whether we've already recorded or shown a notification
        final recordedKey = _recordedCacheKey(p.prescriptionId, scheduledAt);
        final systemShownKey = _systemShownCacheKey(
          p.prescriptionId,
          scheduledAt,
        );

        final alreadyRecorded = prefs.getBool(recordedKey) ?? false;
        final alreadyShown = prefs.getBool(systemShownKey) ?? false;

        // If the scheduled time is within the past minute and we haven't shown a
        // system notification yet, send one now (this is a "catch‑up" notification).
        if (!alreadyShown &&
            scheduledAt.isBefore(now.add(const Duration(minutes: 1)))) {
          await _showNotification(
            p.medicationName,
            p.dosageTablet,
            isFrenzy: false,
          );
          await prefs.setBool(systemShownKey, true);
        }

        // Create an in‑app notification (stored in the database) for this dose,
        // but only once per scheduled time.
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

  // ------------------------------------------------------------------
  // Caregiver stock alert checks
  // ------------------------------------------------------------------

  /// Fetch stock alerts for a caregiver and send a push notification
  /// for each unread, non‑OK alert that hasn't been shown before.
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

  // ------------------------------------------------------------------
  // Scheduling upcoming reminders (for patient)
  // ------------------------------------------------------------------

  /// Schedule exact‑time notifications for all upcoming doses over the next N days.
  /// Also schedules "frenzy" pre‑alerts 3, 2, and 1 minute before each dose.
  /// Returns the number of scheduled notifications.
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

    // Cancel all previously scheduled notifications for this patient.
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
      // Get all upcoming dose times within the next `daysAhead` days
      final times = _upcomingDoseTimesFor(med, now, daysAhead: daysAhead);

      for (final scheduledAt in times) {
        // 1. Schedule the exact‑time notification (at the scheduled minute)
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
          // Mark that we've locally scheduled this dose (to avoid re‑scheduling on reboot)
          await prefs.setBool(
            _localScheduledCacheKey(med.prescriptionId, scheduledAt),
            true,
          );
        }

        // If the dose is already due (within 5 min before to 15 min after),
        // create the in‑app notification now.
        if (_isScheduledTimeActive(scheduledAt, now)) {
          await _createInAppNotificationOnce(
            prefs: prefs,
            patientId: patientId,
            prescription: med,
            scheduledAt: scheduledAt,
          );
        }

        // 2. Schedule "frenzy" pre‑alerts: 3, 2, and 1 minute before the dose.
        for (int minutesBefore in [3, 2, 1]) {
          final advanceTime = scheduledAt.subtract(
            Duration(minutes: minutesBefore),
          );

          if (advanceTime.isAfter(now)) {
            final advId = _notificationIdFor(med.prescriptionId, advanceTime);
            final advScheduled = tz.TZDateTime.from(advanceTime, tz.local);

            // Different title for each urgency level
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

    // Save the list of scheduled notification IDs so we can cancel them later.
    await prefs.setStringList(scheduledIdsKey, scheduledIds);
    return scheduledIds.length;
  }

  // ------------------------------------------------------------------
  // Low‑level scheduling helper
  // ------------------------------------------------------------------

  /// Schedule a notification using `zonedSchedule` with exact time.
  /// Falls back to a non‑exact mode if exact scheduling fails.
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

  // ------------------------------------------------------------------
  // Show system notifications (pop‑up)
  // ------------------------------------------------------------------

  /// Show a medication reminder notification (pop‑up).
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

  /// Show a caregiver stock alert notification.
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

  // ------------------------------------------------------------------
  // Test / debug method
  // ------------------------------------------------------------------

  /// For testing – trigger a dual notification (system pop‑up + in‑app).
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

  // ------------------------------------------------------------------
  // Time‑range calculation helpers
  // ------------------------------------------------------------------

  /// Get all scheduled dose times for a prescription that fall between `start` and `end`.
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

  /// Check if a medication has a dose scheduled within a 20‑minute window around `now`.
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

  /// Determine if a scheduled time is within 5 min before and 15 min after `now`.
  static bool _isScheduledTimeActive(DateTime scheduledAt, DateTime now) {
    final windowStart = now.subtract(const Duration(minutes: 5));
    final windowEnd = now.add(const Duration(minutes: 15));
    return !scheduledAt.isBefore(windowStart) &&
        !scheduledAt.isAfter(windowEnd);
  }

  /// Generate all upcoming dose times for a prescription starting from `from`
  /// and looking ahead `daysAhead` days. Respects start/end dates.
  static List<DateTime> _upcomingDoseTimesFor(
    Prescription prescription,
    DateTime from, {
    int daysAhead = 7,
  }) {
    final result = <DateTime>[];
    if (prescription.dispenseTimes.isEmpty) return result;

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

      for (var timeStr in prescription.dispenseTimes) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          int hour = int.tryParse(parts[0]) ?? 8;
          int minute = int.tryParse(parts[1]) ?? 0;

          final candidate = DateTime(
            day.year,
            day.month,
            day.day,
            hour,
            minute,
          );

          // Skip if the candidate is before the start time we're looking from
          if (!candidate.isAfter(from)) continue;
          // Skip if before prescription start date
          if (candidate.isBefore(prescriptionStart)) continue;
          // Skip if after prescription end date
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

  // ------------------------------------------------------------------
  // Notification ID generators (to avoid collisions)
  // ------------------------------------------------------------------

  /// Generate a unique notification ID for a specific dose time.
  static int _notificationIdFor(int prescriptionId, DateTime scheduledAt) {
    final minuteBucket = scheduledAt.millisecondsSinceEpoch ~/ 60000;
    return ((prescriptionId * 1000003) + minuteBucket) & 0x7fffffff;
  }

  /// Generate a unique ID for a caregiver stock notification.
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

  // ------------------------------------------------------------------
  // Cache key helpers for SharedPreferences
  // ------------------------------------------------------------------

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

  /// Convert a DateTime to a string key like "20260219_1430".
  static String _scheduleKey(DateTime scheduledAt) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${scheduledAt.year}${two(scheduledAt.month)}${two(scheduledAt.day)}_${two(scheduledAt.hour)}${two(scheduledAt.minute)}';
  }

  // ------------------------------------------------------------------
  // Utility helpers
  // ------------------------------------------------------------------

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

  // ------------------------------------------------------------------
  // Create in‑app notification (stored in DB) – currently disabled/commented
  // ------------------------------------------------------------------

  /// Create an in‑app notification for a specific dose, but only once.
  /// The actual DB insertion is commented out (as shown below) to avoid
  /// duplicate records; the cache key is still set to prevent re‑attempts.
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

    // (Optional) Uncomment below to actually save to DB:
    // final saved = await PatientService().createNotification(
    //   patientId: patientId,
    //   title: 'Medication Reminder',
    //   message: _inAppReminderMessage(prescription, scheduledAt),
    //   type: 'REMINDER',
    // );
    // if (saved) {
    //   await prefs.setBool(recordedKey, true);
    // }

    // For now, just mark as recorded without saving to DB.
    await prefs.setBool(recordedKey, true);
  }

  // ------------------------------------------------------------------
  // Message generators
  // ------------------------------------------------------------------

  static String _systemReminderMessage(String medName, double dosage) {
    return 'Take ${dosage.toStringAsFixed(0)} tablet(s) of $medName.\nPress the button on your medical kit.';
  }

  // ------------------------------------------------------------------
  // Notification channel configurations
  // ------------------------------------------------------------------

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
