// lib/screens/caregiver/caregiver_notifications_page.dart
// Displays a list of unread notifications for the caregiver, including medication reminders,
// low-stock alerts, and out-of-stock alerts. Each notification card shows the medication,
// message, patient name, stock status, and allows marking as read. Also supports "Read All"
// and pull-to-refresh.

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';
import 'package:my_medical_kit_app/services/reminder_service.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaregiverNotificationsPage extends StatefulWidget {
  final int?
  caregiverId; // Optional caregiver ID (if not provided, fetched from session)

  const CaregiverNotificationsPage({super.key, this.caregiverId});

  @override
  State<CaregiverNotificationsPage> createState() =>
      _CaregiverNotificationsPageState();
}

class _CaregiverNotificationsPageState
    extends State<CaregiverNotificationsPage> {
  final CaregiverService _caregiverService = CaregiverService();

  List<Map<String, dynamic>> _notifications =
      []; // List of unread notifications
  bool _isLoading = true;
  String? _errorMessage;
  int _caregiverId = 0; // Resolved caregiver ID from session or widget

  @override
  void initState() {
    super.initState();
    _resolveCaregiverAndLoad(); // Load caregiver ID and then notifications
  }

  // Resolves caregiver ID from widget or SharedPreferences, then loads notifications.
  Future<void> _resolveCaregiverAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt('caregiver_id') ?? 0;
    _caregiverId = widget.caregiverId ?? savedId;

    if (_caregiverId <= 0) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Caregiver account not found. Please sign in again.';
      });
      return;
    }

    await _loadNotifications();
  }

  // Fetches unread notifications from the API and updates the UI.
  // Optionally shows a loading indicator.
  Future<void> _loadNotifications({bool showLoading = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoading) _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _caregiverService.getCaregiverNotifications(
        _caregiverId,
      );

      if (!mounted) return;
      setState(() {
        // 🔥 FILTER OUT READ NOTIFICATIONS – only unread are shown.
        _notifications = data.where((n) => !_isRead(n['is_read'])).toList();
        _isLoading = false;
      });

      // Also check for caregiver stock alerts (syncs with reminder service).
      await ReminderService.checkAndSendCaregiverStockAlerts(
        caregiverId: _caregiverId,
        notifications: _notifications,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load notifications: $e';
      });
    }
  }

  // Marks a single notification as read and removes it from the list (after successful API call).
  Future<void> _markAsRead(Map<String, dynamic> notif, int index) async {
    final notifId = _asInt(notif['notification_id']);
    if (notifId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification is still syncing. Pull to refresh.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await _caregiverService.markCaregiverNotificationRead(
      notifId,
    );
    if (!mounted) return;

    if (success) {
      setState(() {
        _notifications.removeAt(index); // remove card from list
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${notif['medication_name'] ?? 'Notification'} marked as read',
          ),
          backgroundColor: Colors.teal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark as read'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Marks all current unread notifications as read (confirmation dialog first).
  Future<void> _markAllAsRead() async {
    if (_notifications.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark all as read?'),
        content: const Text('This will dismiss all unread notifications.'),
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
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Mark each unread notification
    for (final notif in _notifications) {
      final notifId = _asInt(notif['notification_id']);
      if (notifId != null && !_isRead(notif['is_read'])) {
        await _caregiverService.markCaregiverNotificationRead(notifId);
      }
    }

    if (!mounted) return;

    // Reload to get fresh data (only unread ones will appear, which will be none)
    await _loadNotifications();
  }

  // ──────────────────────────────────────────
  // HEADER WIDGET (gradient background with title and "Read All")
  // ──────────────────────────────────────────
  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    final hasUnread = _notifications.any((n) => !_isRead(n['is_read']));

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
              // Back button
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
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
                'Notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // "Read All" button only if there are unread notifications
              hasUnread
                  ? GestureDetector(
                      onTap: _markAllAsRead,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Text(
                          'Read All',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: 72), // Spacer for alignment
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'UNREAD NOTIFICATIONS',
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 1.5,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Alerts & Reminders',
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

  // ──────────────────────────────────────────
  // BODY – shows loading, error, empty state, or list of notifications.
  // ──────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.red.shade700),
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No unread notifications',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotifications(showLoading: false),
      color: AppColors.primaryPurple,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          return _buildNotificationCard(_notifications[index], index);
        },
      ),
    );
  }

  // ──────────────────────────────────────────
  // INDIVIDUAL NOTIFICATION CARD
  // ──────────────────────────────────────────
  Widget _buildNotificationCard(Map<String, dynamic> notif, int index) {
    // We only show unread notifications, but keep the check anyway
    final isRead = _isRead(notif['is_read']);
    // If a read notification somehow appears, we still don't want to show it,
    // but the filter should prevent that. This is a safeguard.
    if (isRead) return const SizedBox.shrink();

    final String notifType = (notif['type'] ?? '').toString();
    final bool isStockAlert =
        notifType == 'LOW_STOCK' || notifType == 'OUT_OF_STOCK';
    final bool isOutOfStock = notifType == 'OUT_OF_STOCK';

    // Determine icon and colours based on notification type.
    late IconData iconData;
    late Color iconColor;
    late Color backgroundColor;

    if (isStockAlert) {
      iconData = isOutOfStock
          ? Icons.report_problem_rounded
          : Icons.warning_amber_rounded;
      iconColor = isOutOfStock ? Colors.red : Colors.orange;
      backgroundColor = isOutOfStock
          ? Colors.red.shade50
          : Colors.orange.shade50;
    } else {
      iconData = Icons.notifications_active;
      iconColor = AppColors.primaryPurple;
      backgroundColor = AppColors.primaryPurple.withOpacity(0.1);
    }

    final medicationName = (notif['medication_name'] ?? 'Medicine').toString();
    final patientName = (notif['patient_name'] ?? 'Assigned patient')
        .toString();
    final currentInventory = _asInt(notif['current_inventory']) ?? 0;
    final refillThreshold = _asInt(notif['refill_threshold']) ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            // Top row: icon, medication name, creation time, unread dot
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(iconData, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicationName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Created: ${_formatNotificationTime(notif['created_at'])}',
                        style: TextStyle(
                          fontSize: 14,
                          color: iconColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Unread indicator (always true here, but keep)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Notification message box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    (notif['message'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Patient name and notification type
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          patientName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _readableType(notifType),
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
            // For stock alerts, show stock chips and a warning/advice box.
            if (isStockAlert) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _stockChip(
                    icon: Icons.inventory_2_outlined,
                    label: isOutOfStock
                        ? 'Out of Stock'
                        : 'Low Stock ($currentInventory left)',
                    foreground: iconColor,
                    background: backgroundColor,
                  ),
                  _stockChip(
                    icon: Icons.low_priority_rounded,
                    label: 'Threshold: $refillThreshold',
                    foreground: AppColors.primaryPurple,
                    background: AppColors.primaryPurple.withOpacity(0.1),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: iconColor.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOutOfStock
                          ? Icons.priority_high_rounded
                          : Icons.warning_amber_rounded,
                      color: iconColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isOutOfStock
                            ? 'Immediate restock needed. No tablet is available for this medicine.'
                            : 'Refill soon. Only $currentInventory tablet(s) left before the threshold of $refillThreshold.',
                        style: TextStyle(
                          color: isOutOfStock
                              ? Colors.red.shade800
                              : Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // "Mark as Read" button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => _markAsRead(notif, index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Mark as Read',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build a small stock info chip.
  Widget _stockChip({
    required IconData icon,
    required String label,
    required Color foreground,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // UTILITY METHODS
  // ──────────────────────────────────────────

  // Formats a DateTime string into a human-readable "DD/MM/YYYY at HH:MM AM/PM" format.
  String _formatNotificationTime(dynamic rawValue) {
    if (rawValue == null) return 'Just now';
    try {
      final time = DateTime.parse(rawValue.toString()).toLocal();
      final year = time.year.toString();
      final month = time.month.toString().padLeft(2, '0');
      final day = time.day.toString().padLeft(2, '0');
      int hour = time.hour;
      final minute = time.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';

      hour = hour % 12;
      if (hour == 0) hour = 12;

      return '$day/$month/$year at $hour:$minute $amPm';
    } catch (_) {
      return rawValue.toString();
    }
  }

  // Converts a notification type code into a readable label.
  String _readableType(String type) {
    switch (type) {
      case 'OUT_OF_STOCK':
        return 'Out of stock';
      case 'LOW_STOCK':
        return 'Low stock';
      case 'REMINDER':
        return 'Reminder';
      case 'ALERT':
        return 'Alert';
      default:
        return type;
    }
  }

  // Checks if a notification is marked as read (handles bool/int/string variants).
  bool _isRead(dynamic value) {
    return value == true || value == 1 || value == '1' || value == 'true';
  }

  // Safely converts a dynamic value to int, returning null if not possible.
  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
