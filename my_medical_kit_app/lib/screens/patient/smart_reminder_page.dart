// lib/screens/smart_reminder_page.dart

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/services/reminder_service.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';
import 'package:my_medical_kit_app/models/notification.dart';
import 'package:my_medical_kit_app/models/prescription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// 🌟 新增：专门用来组合“通知”和“对应药物详情”的数据类
class ReminderItem {
  final NotificationModel notification;
  final Prescription prescription;

  ReminderItem({required this.notification, required this.prescription});
}

class SmartReminderPage extends StatefulWidget {
  const SmartReminderPage({super.key});

  @override
  State<SmartReminderPage> createState() => _SmartReminderPageState();
}

class _SmartReminderPageState extends State<SmartReminderPage> {
  Timer? _autoRefreshTimer;
  bool _isLoading = true;

  // 🌟 修改：列表数据源从 List<Prescription> 变成了 List<ReminderItem>
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

  Future<void> _loadMedications() async {
    setState(() => _isLoading = true);
    try {
      final allMeds = await MedicationService().getPatientMedications(
        _patientId,
      );
      await ReminderService.checkAndSendReminders(medications: allMeds);
      final notifications = await PatientService().getNotifications(_patientId);

      // 取出所有未读通知
      final unreadNotifications = notifications
          .where((notification) => !notification.isRead)
          .toList();

      List<ReminderItem> items = [];

      // 🌟 核心逻辑：遍历每一个未读通知，为它们各自生成一张卡片！
      for (var notif in unreadNotifications) {
        final title = notif.title.toLowerCase();
        // 只处理和吃药相关的通知
        if (title.contains('medication') || title.contains('reminder')) {
          try {
            // 在处方列表中找到这个通知对应的是哪个药
            final matchedMed = allMeds.firstWhere(
              (med) => notif.message.toLowerCase().contains(
                med.medicationName.toLowerCase(),
              ),
            );
            // 组装成一个 ReminderItem 添加到列表中
            items.add(
              ReminderItem(notification: notif, prescription: matchedMed),
            );
          } catch (e) {
            // 如果这个药已经被删除了，找不到匹配的处方，就跳过这条通知
            debugPrint(
              'Could not find prescription for notification ${notif.notificationId}',
            );
          }
        }
      }

      setState(() {
        _reminders = items; // 更新 UI
        _isLoading = false;
      });

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

  // 🌟 新增：格式化通知的具体生成时间 (方便区分 48 和 49)
  // 🌟 Modified: Format time to 12-hour (AM/PM) system
  String _formatNotificationTime(DateTime time) {
    final year = time.year.toString(); // 🌟 ADDED YEAR
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');

    int hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    // 🌟 ADDED YEAR TO THE OUTPUT STRING
    return '$day/$month/$year at $hour:$minute $amPm';
  }

  // 🌟 NEW: Translates a cron string (e.g., "53 15 * * *") into readable text
  String _getReadableSchedule(String cronExp) {
    try {
      final parts = cronExp.trim().split(RegExp(r'\s+'));
      if (parts.length < 5) return cronExp; // Fallback if format is weird

      final minuteStr = parts[0];
      final hourStr = parts[1];
      final daysOfWeekStr = parts[4];

      // Format Time
      String timeString = '';
      if (minuteStr != '*' && hourStr != '*') {
        int h = int.parse(hourStr);
        int m = int.parse(minuteStr);
        final amPm = h >= 12 ? 'PM' : 'AM';

        int displayHour = h % 12;
        if (displayHour == 0) displayHour = 12;
        final displayMinute = m.toString().padLeft(2, '0');

        timeString = '$displayHour:$displayMinute $amPm';
      } else {
        timeString = 'Various times';
      }

      // Format Days
      String daysString = '';
      if (daysOfWeekStr == '*') {
        daysString = 'Daily';
      } else {
        final dayNames = {
          '0': 'Sun',
          '1': 'Mon',
          '2': 'Tue',
          '3': 'Wed',
          '4': 'Thu',
          '5': 'Fri',
          '6': 'Sat',
          '7': 'Sun',
        };
        final dayNums = daysOfWeekStr.split(',');
        final mappedDays = dayNums.map((d) => dayNames[d.trim()] ?? d).toList();
        daysString = mappedDays.join(', ');
      }

      return '$daysString at $timeString';
    } catch (e) {
      return cronExp; // Fallback to raw cron string if parsing fails
    }
  }

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
              const Text(
                'Smart Reminders',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  // 🌟 CHANGED: Mark All As Read Text Button
                  if (_reminders.isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Mark all as read?'),
                            content: const Text(
                              'This will dismiss all active reminders.',
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
                                ),
                                child: const Text(
                                  'Yes',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm != true) return;

                        // Mark all currently displayed notifications as read
                        for (var item in _reminders) {
                          await PatientService().markNotificationRead(
                            item.notification.notificationId,
                          );
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All reminders cleared'),
                              backgroundColor: Colors.teal,
                            ),
                          );
                          _loadMedications();
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Text(
                          'Read All',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold, // 🌟 Still bold!
                            fontSize:
                                16, // Made slightly bigger since it has no background
                          ),
                        ),
                      ),
                    ),

                  // GestureDetector(
                  //   onTap: () async {
                  //     await ReminderService.triggerTestDualNotification(
                  //       context,
                  //     );
                  //     _loadMedications();
                  //   },
                  //   child: Container(
                  //     margin: const EdgeInsets.only(right: 10),
                  //     padding: const EdgeInsets.all(10),
                  //     decoration: BoxDecoration(
                  //       color: Colors.orangeAccent.withValues(alpha: 0.8),
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     child: const Icon(
                  //       Icons.bug_report,
                  //       color: Colors.white,
                  //       size: 18,
                  //     ),
                  //   ),
                  // ),
                  // GestureDetector(
                  //   onTap: () async {
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       const SnackBar(content: Text('Checking schedule...')),
                  //     );
                  //     await ReminderService.checkAndSendReminders();
                  //     if (mounted) {
                  //       await _loadMedications();
                  //     }
                  //   },
                  //   child: Container(
                  //     padding: const EdgeInsets.all(10),
                  //     decoration: BoxDecoration(
                  //       color: Colors.white.withValues(alpha: 0.2),
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     child: const Icon(
                  //       Icons.sync,
                  //       color: Colors.white,
                  //       size: 18,
                  //     ),
                  //   ),
                  // ),
                ],
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
                    onRefresh: _loadMedications,
                    color: AppColors.primaryPurple,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      itemCount: _reminders.length,
                      itemBuilder: (context, index) {
                        final item = _reminders[index];
                        final notif = item.notification;
                        final med = item.prescription;

                        // 💡 UPDATED LOGIC: Split into 3 distinct stock states
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

                                // Display Notification Message
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

                                // Display Type & Dispense Schedule
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
                                                med.dispenseSchedule,
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
                                Row(
                                  children: [
                                    Icon(
                                      Icons.medication,
                                      size: 18,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${med.dosageTablet.toStringAsFixed(0)} tablet(s) missed',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8.0,
                                  runSpacing: 12.0,
                                  children: [
                                    // 💡 UPDATED LOGIC: Stock Badge (Red = Out of Stock, Orange = Low, Green = OK)
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

                                // 💡 UPDATED LOGIC: Bottom Warning Box changes text based on severity
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
