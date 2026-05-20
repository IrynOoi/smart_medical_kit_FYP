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
  String _formatNotificationTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$day/$month at $hour:$minute';
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
                  GestureDetector(
                    onTap: () async {
                      await ReminderService.triggerTestDualNotification(
                        context,
                      );
                      _loadMedications();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bug_report,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Checking schedule...')),
                      );
                      await ReminderService.checkAndSendReminders();
                      if (mounted) {
                        await _loadMedications();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
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

                        final isLowStock =
                            med.currentInventory <= med.refillThreshold;

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
                                      child: Icon(
                                        Icons
                                            .notifications_active, // 换个更符合“提醒”的图标
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
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                // 🌟 核心：显示这个通知真正发生的时间！
                                                _formatNotificationTime(
                                                  notif.createdAt,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color:
                                                      Colors.redAccent.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
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
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8.0,
                                  runSpacing: 12.0,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLowStock
                                            ? Colors.red.shade50
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isLowStock
                                                ? Icons.warning_amber_rounded
                                                : Icons.check_circle,
                                            size: 14,
                                            color: isLowStock
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isLowStock
                                                ? 'Low Stock (${med.currentInventory} left)'
                                                : 'Stock: ${med.currentInventory}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isLowStock
                                                  ? Colors.red
                                                  : Colors.green.shade800,
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
                                                title: Text('Dismiss reminder'),
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

                                            // 🌟 核心：使用单独的 markNotificationRead API，精准干掉具体的某一条 Notification!
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
                                if (isLowStock)
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
                                              'Refill soon! Only ${med.currentInventory} tablet(s) left.',
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
