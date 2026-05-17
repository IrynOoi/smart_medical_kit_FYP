// lib/screens/smart_reminder_page.dart

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/services/reminder_service.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';
import 'package:my_medical_kit_app/models/prescription.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartReminderPage extends StatefulWidget {
  const SmartReminderPage({super.key});

  @override
  State<SmartReminderPage> createState() => _SmartReminderPageState();
}

class _SmartReminderPageState extends State<SmartReminderPage> {
  
  bool _isLoading = true;
  List<Prescription> _medications = [];
  int _patientId = 0;

  @override
  void initState() {
    super.initState();
    _loadPatientId();
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
      // 1. Fetch all prescriptions (the schedule)
      final allMeds = await MedicationService().getPatientMedications(_patientId);

      // 2. Fetch notifications to see which ones are actually unread
      final notifications = await PatientService().getNotifications(_patientId);

      // Filter to keep only unread notifications (isRead == false or 0 depending on your model)
      // We assume your NotificationModel uses a boolean or int for isRead.
      final unreadNotifications = notifications
          .where((n) => n.isRead == false)
          .toList();

      // 3. Filter the medications: only keep the card if its name is in an unread notification
      final activeReminders = allMeds.where((med) {
        return unreadNotifications.any(
          (notif) => notif.message.contains(med.medicationName),
        );
      }).toList();

      setState(() {
        _medications = activeReminders; // <-- Display the filtered list!
        _isLoading = false;
      });

      try {
        await ReminderService.scheduleUpcomingMedicationReminders(
          _patientId,
          medications: allMeds, // Keep scheduling based on the full schedule
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

  String _formatCron(String cron) {
    final parts = cron.split(' ');
    if (parts.length < 5) return cron;
    final minute = parts[0];
    final hour = parts[1];
    if (hour.contains(',')) {
      final times = hour.split(',').map((h) => '$h:$minute').join(', ');
      return 'Daily at $times';
    }
    return 'Daily at ${hour.padLeft(2, '0')}:${minute.padLeft(2, '0')}';
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

              // 把右边的按钮组合起来
              Row(
                children: [
                  // 🐛 1. 开发者测试按钮 (一键发通知)
                  GestureDetector(
                    onTap: () async {
                      // 直接触发我们的 Debug 函数
                      await ReminderService.triggerTestDualNotification(
                        context,
                      );
                      // 顺便刷新一下列表，让你能马上在 App 里看到新通知
                      _loadMedications();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10), // 和刷新按钮隔开一点
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(
                          0.8,
                        ), // 设成橘色，提示这是测试按钮
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bug_report,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),

                  // 🔄 2. 真实的时间检查按钮 (Sync)
                  GestureDetector(
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Checking schedule...')),
                      );
                      await ReminderService.checkAndSendReminders();
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
            'YOUR DAILY SCHEDULE',
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
      backgroundColor: const Color(0xFFF5F0FF), // 浅紫色背景
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () {
      //     // 按下去直接强行触发通知！
      //     ReminderService.showNotification("Aspirin (Test)", 1.0);
      //   },
      //   backgroundColor: AppColors.primaryPurple,
      //   icon: const Icon(Icons.notifications_active, color: Colors.white),
      //   label: const Text(
      //     "Test Notification",
      //     style: TextStyle(color: Colors.white),
      //   ),
      // ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _medications.isEmpty
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
                          'No medications scheduled',
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
                      itemCount: _medications.length,
                      itemBuilder: (context, index) {
                        final med = _medications[index];
                        final isLowStock =
                            med.currentInventory <= med.refillThreshold;
                        final canTake = med.currentInventory > 0;

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
                                color: AppColors.primaryPurple.withValues(alpha: 0.1),
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
                                        Icons.medication_liquid,
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
                                                _formatCron(
                                                  med.dispenseSchedule,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade700,
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
                                      '${med.dosageTablet.toStringAsFixed(0)} tablet(s) per dose',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const SizedBox(height: 12),
                                // 💡 修复 Overflow：用 Wrap 代替 Row，让空间不够时自动换行
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8.0,
                                  runSpacing: 12.0,
                                  children: [
                                    // 1. Stock Status
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

                                    // 2. Actions (Press Kit + Mark as Read)
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8.0,
                                      children: [
                                        // Press Kit hint
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

                                        // Mark as Read button
                                        // Replace your existing Mark as Read ElevatedButton (around line 290) with this:
                                        ElevatedButton(
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text(
                                                  'Dismiss ${med.medicationName} reminder',
                                                ),
                                                content: Text(
                                                  'This will clear the unread reminder for ${med.medicationName}. Are you sure?',
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

                                            // Call the new single-read API
                                            final success = await PatientService()
                                                .markSingleReminderRead(
                                                  _patientId,
                                                  med.medicationName,
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
                                              // Refresh the list to update UI
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
                                            'Mark as Read', // Updated text
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
