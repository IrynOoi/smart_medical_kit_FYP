// lib/screens/smart_reminder_page.dart

// Displays active medication reminders (unread notifications) for the patient.
// Each reminder card shows medication details, stock status, and actions to mark as read or dismiss.

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/services/reminder_service.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';
import 'package:my_medical_kit_app/models/notification.dart';
import 'package:my_medical_kit_app/models/prescription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// 🌟 Helper class that combines a notification with its matching prescription (if any)
class ReminderItem {
  final NotificationModel notification;
  final Prescription? prescription;

  ReminderItem({required this.notification, this.prescription});
}

class SmartReminderPage extends StatefulWidget {
  const SmartReminderPage({super.key});

  @override
  State<SmartReminderPage> createState() => _SmartReminderPageState();
}

class _SmartReminderPageState extends State<SmartReminderPage> {
  Timer?
  _autoRefreshTimer; // (currently unused, but can be used for periodic refresh)
  bool _isLoading = true;

  // 🌟 Data source for the list of reminders (each item combines notification + prescription)
  List<ReminderItem> _reminders = [];
  int _patientId = 0;

  @override
  void initState() {
    super.initState();
    _loadPatientId();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Load patient ID from shared preferences and then fetch medications/reminders
  Future<void> _loadPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('patient_id');
    if (id != null && id > 0) {
      _patientId = id;
      await _loadMedications();
    } else {
      setState(() => _isLoading = false);
    }
  }

  // Fetch all medications and notifications, then build the reminder list
  Future<void> _loadMedications({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      // Get all active prescriptions for the patient
      final allMeds = await MedicationService().getPatientMedications(
        _patientId,
      );
      // Check and send any pending reminders (this also creates notifications)
      await ReminderService.checkAndSendReminders(medications: allMeds);
      // Fetch all notifications for the patient
      final notifications = await PatientService().getNotifications(_patientId);

      // Filter only unread notifications
      final unreadNotifications = notifications
          .where((notification) => !notification.isRead)
          .toList();

      List<ReminderItem> items = [];

      // 🌟 Core logic: for each unread notification, try to find a matching prescription
      for (var notif in unreadNotifications) {
        final title = notif.title.toLowerCase();

        Prescription? matchedMed;
        try {
          // Match by checking if the notification message contains the medication name
          matchedMed = allMeds.firstWhere(
            (med) => notif.message.toLowerCase().contains(
              med.medicationName.toLowerCase(),
            ),
          );
        } catch (e) {
          // No matching medication found; keep matchedMed null
        }

        // Show the notification if it is medication/reminder related or a stock alert
        if (title.contains('medication') ||
            title.contains('reminder') ||
            notif.type == 'ALERT' ||
            notif.type == 'OUT_OF_STOCK' ||
            notif.type == 'LOW_STOCK') {
          // For medication reminders, we must have a matching prescription to show the dose button
          if ((title.contains('medication') || title.contains('reminder')) &&
              matchedMed == null) {
            continue; // Skip if no matching med for a reminder
          }

          items.add(
            ReminderItem(notification: notif, prescription: matchedMed),
          );
        } else {
          // For any other notification type, still add it (safety net)
          items.add(
            ReminderItem(notification: notif, prescription: matchedMed),
          );
        }
      }

      setState(() {
        _reminders = items; // Update UI with the new list
        _isLoading = false;
      });

      // Schedule upcoming reminders for future times (local notifications)
      try {
        await ReminderService.scheduleUpcomingMedicationReminders(
          _patientId,
          medications: allMeds,
        );
      } catch (scheduleError) {
        debugPrint('Reminder scheduling skipped: $scheduleError');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading medications: $e')),
        );
      }
    }
  }

  // (Unused method – originally for marking a dose as taken via the kit)
  Future<void> _markTaken(int prescriptionId, int? deviceId) async {
    final actualDeviceId = deviceId ?? 0;
    final success = await MedicationService().recordMedicationTaken(
      prescriptionId,
      actualDeviceId,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Dose recorded successfully!'),
          backgroundColor: Colors.teal,
        ),
      );
      _loadMedications();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to record. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // 🌟 Format a DateTime to a readable string with day/month/year and 12‑hour time
  String _formatNotificationTime(DateTime time) {
    final year = time.year.toString();
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');

    int hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$day/$month/$year at $hour:$minute $amPm';
  }

  // Convert a list of dispense times (e.g. ['08:00:00', '20:00:00']) into human‑readable format
  String _getReadableSchedule(List<String> times) {
    if (times.isEmpty) return 'No schedule';
    final formattedTimes = times.map((t) {
      final parts = t.split(':');
      if (parts.length >= 2) {
        int h = int.tryParse(parts[0]) ?? 8;
        int m = int.tryParse(parts[1]) ?? 0;
        final amPm = h >= 12 ? 'PM' : 'AM';
        int displayHour = h % 12;
        if (displayHour == 0) displayHour = 12;
        final displayMinute = m.toString().padLeft(2, '0');
        return '$displayHour:$displayMinute $amPm';
      }
      return t;
    }).toList();
    return 'Daily at ${formattedTimes.join(', ')}';
  }

  // Build the header with gradient background, back button, title, and "Read All" action
  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding + 16, 24, 32),
      decoration: const BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12), // spacing between back and title
              // Title takes the remaining space
              Expanded(
                child: Center(
                  child: const Text(
                    'Smart Reminders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // "Read All" button
              if (_reminders.isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Mark All as Read'),
                        content: Text(
                          'This will dismiss all ${_reminders.length} active reminder(s). Are you sure?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Yes, Mark All'),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;
                    if (!mounted) return;

                    // Mark every unread notification as read
                    final futures = _reminders
                        .map((item) => PatientService().markNotificationRead(
                              item.notification.notificationId,
                            ))
                        .toList();

                    final results = await Future.wait(futures);
                    if (!mounted) return;

                    final allSuccess = results.every((r) => r == true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          allSuccess
                              ? '✅ All reminders marked as read'
                              : '⚠️ Some reminders could not be marked as read',
                        ),
                        backgroundColor:
                            allSuccess ? Colors.teal : Colors.orange,
                      ),
                    );

                    await _loadMedications(showLoading: false);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Read All',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'YOUR UNREAD ALERTS',
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 1.5,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Medication Reminder',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reminders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.medication_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No active medication reminders',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadMedications(showLoading: false),
                    color: AppColors.primaryPurple,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      itemCount: _reminders.length,
                      itemBuilder: (context, index) {
                        final item = _reminders[index];
                        final notif = item.notification;
                        final med = item.prescription;

                        // If no prescription found or the notification is a generic alert/stock alert,
                        // show a simplified card with only the notification details.
                        if (med == null ||
                            notif.type == 'ALERT' ||
                            notif.type == 'OUT_OF_STOCK' ||
                            notif.type == 'LOW_STOCK') {
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withValues(
                                    alpha: 0.1,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon and title/date
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.info_outline,
                                          color: Colors.orange,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              notif.title,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Time: ${_formatNotificationTime(notif.createdAt)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Notification message
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      notif.message,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Mark as read button
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final success = await PatientService()
                                            .markNotificationRead(
                                              notif.notificationId,
                                            );
                                        if (mounted && success)
                                          _loadMedications();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.primaryPurple,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Mark as read'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // 💡 Full medication reminder card: shows prescription details and stock status
                        final isOutOfStock = med.currentInventory <= 0;
                        final isLowStock =
                            med.currentInventory > 0 &&
                            med.currentInventory <= med.refillThreshold;
                        final hasStockIssue = isOutOfStock || isLowStock;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Medication icon, name, and notification time
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryPurple
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        Icons.notifications_active,
                                        color: AppColors.primaryPurple,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            med.medicationName,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Created: ${_formatNotificationTime(notif.createdAt)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.primaryPurple,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Notification message
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Message:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notif.message,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Notification type and dispense schedule
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.label_outline,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Type: ${notif.type}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.schedule,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              _getReadableSchedule(
                                                med.dispenseTimes,
                                              ),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                // // Dosage info
                                // Row(
                                //   children: [
                                //     Icon(
                                //       Icons.medication,
                                //       size: 18,
                                //       color: Colors.grey.shade600,
                                //     ),
                                //     const SizedBox(width: 6),
                                //     Text(
                                //       '${med.dosageTablet.toStringAsFixed(0)} tablet(s) missed',
                                //       style: TextStyle(
                                //         fontSize: 14,
                                //         color: Colors.grey.shade700,
                                //       ),
                                //     ),
                                //   ],
                                // ),
                                const SizedBox(height: 12),
                                // Stock badge + "Mark as Read" button
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8.0,
                                  runSpacing: 12.0,
                                  children: [
                                    // 💡 Stock status badge: red for out-of-stock, orange for low, green for OK
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOutOfStock
                                            ? Colors.red.shade50
                                            : (isLowStock
                                                  ? Colors.orange.shade50
                                                  : Colors.green.shade50),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isOutOfStock
                                                ? Icons.error_outline
                                                : (isLowStock
                                                      ? Icons
                                                            .warning_amber_rounded
                                                      : Icons.check_circle),
                                            size: 14,
                                            color: isOutOfStock
                                                ? Colors.red
                                                : (isLowStock
                                                      ? Colors.orange.shade800
                                                      : Colors.green),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isOutOfStock
                                                ? 'Out of Stock (0 left)'
                                                : (isLowStock
                                                      ? 'Low Stock (${med.currentInventory} left)'
                                                      : 'Stock: ${med.currentInventory}'),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isOutOfStock
                                                  ? Colors.red
                                                  : (isLowStock
                                                        ? Colors.orange.shade800
                                                        : Colors
                                                              .green
                                                              .shade800),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8.0,
                                      children: [
                                        // Instruction to use physical kit
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryPurple
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.touch_app,
                                                size: 16,
                                                color: AppColors.primaryPurple,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Press Kit to Dispense',
                                                style: TextStyle(
                                                  color:
                                                      AppColors.primaryPurple,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // "Mark as Read" button (dismisses this reminder)
                                        ElevatedButton(
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                  'Dismiss reminder',
                                                ),
                                                content: Text(
                                                  'This will clear the reminder for ${med.medicationName} from ${_formatNotificationTime(notif.createdAt)}. Are you sure?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              AppColors
                                                                  .primaryPurple,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                    child: const Text('Yes'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm != true) return;

                                            final success =
                                                await PatientService()
                                                    .markNotificationRead(
                                                      notif.notificationId,
                                                    );

                                            if (!mounted) return;

                                            if (success) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${med.medicationName} reminder marked as read',
                                                  ),
                                                  backgroundColor: Colors.teal,
                                                ),
                                              );
                                              _loadMedications();
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Failed to mark as read',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.primaryPurple,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                          child: const Text(
                                            'Mark as Read',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // Bottom warning box for low/out-of-stock
                                if (hasStockIssue)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.red.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              isOutOfStock
                                                  ? 'Out of stock! Please refill immediately.'
                                                  : 'Refill soon! Only ${med.currentInventory} tablet(s) left.',
                                              style: TextStyle(
                                                color: Colors.red.shade800,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
