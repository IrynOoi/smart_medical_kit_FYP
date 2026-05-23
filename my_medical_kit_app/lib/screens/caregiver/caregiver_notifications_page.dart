// lib/screens/caregiver/caregiver_notifications_page.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';
import 'package:my_medical_kit_app/services/reminder_service.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaregiverNotificationsPage extends StatefulWidget {
  final int? caregiverId;

  const CaregiverNotificationsPage({super.key, this.caregiverId});

  @override
  State<CaregiverNotificationsPage> createState() =>
      _CaregiverNotificationsPageState();
}

class _CaregiverNotificationsPageState
    extends State<CaregiverNotificationsPage> {
  final CaregiverService _caregiverService = CaregiverService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _caregiverId = 0;

  @override
  void initState() {
    super.initState();
    _resolveCaregiverAndLoad();
  }

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

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _caregiverService.getCaregiverStockNotifications(
        _caregiverId,
      );

      if (!mounted) return;
      setState(() {
        _notifications = data;
        _isLoading = false;
      });

      await ReminderService.checkAndSendCaregiverStockAlerts(
        caregiverId: _caregiverId,
        notifications: data,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load stock notifications: $e';
      });
    }
  }

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
        _notifications.removeAt(index); // ✅ remove card from list
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${notif['medication_name']} alert removed'),
          backgroundColor: Colors.teal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark alert as read'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    if (_notifications.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark all as read?'),
        content: const Text('This will dismiss all stock alerts.'),
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
    final List<Map<String, dynamic>> newList = [];
    for (final notif in _notifications) {
      final notifId = _asInt(notif['notification_id']);
      if (notifId != null && !_isRead(notif['is_read'])) {
        await _caregiverService.markCaregiverNotificationRead(notifId);
      } else {
        newList.add(notif); // keep already read ones (optional)
      }
    }

    if (!mounted) return;

    setState(() {
      _notifications.clear(); // ✅ clear all (or keep read ones if you prefer)
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All alerts dismissed'),
        backgroundColor: Colors.teal,
      ),
    );
  }

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
                  : const SizedBox(width: 72),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'YOUR STOCK ALERTS',
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 1.5,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Medicine Inventory',
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
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No active stock alerts',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
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

  Widget _buildNotificationCard(Map<String, dynamic> notif, int index) {
    final isRead = _isRead(notif['is_read']);
    final isOutOfStock = notif['stock_status'] == 'OUT_OF_STOCK';
    final statusColor = isOutOfStock ? Colors.red : Colors.orange;
    final statusBackground = isOutOfStock
        ? Colors.red.shade50
        : Colors.orange.shade50;
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusBackground,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    isOutOfStock
                        ? Icons.report_problem_rounded
                        : Icons.warning_amber_rounded,
                    color: statusColor,
                    size: 28,
                  ),
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
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
                          _readableType(notif['type']),
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
                  foreground: statusColor,
                  background: statusBackground,
                ),
                _stockChip(
                  icon: Icons.low_priority_rounded,
                  label: 'Threshold: $refillThreshold',
                  foreground: AppColors.primaryPurple,
                  background: AppColors.primaryPurple.withValues(alpha: 0.1),
                ),
                _stockChip(
                  icon: isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                  label: isRead ? 'Read' : 'Unread',
                  foreground: isRead ? Colors.grey : statusColor,
                  background: isRead ? Colors.grey.shade100 : statusBackground,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(
                    isOutOfStock
                        ? Icons.priority_high_rounded
                        : Icons.warning_amber_rounded,
                    color: statusColor,
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
            if (!isRead) ...[
              const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }

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

  String _formatNotificationTime(dynamic rawValue) {
    if (rawValue == null) return 'Synced from inventory';
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

  String _readableType(dynamic type) {
    switch ((type ?? '').toString()) {
      case 'OUT_OF_STOCK':
        return 'Out of stock';
      case 'LOW_STOCK':
        return 'Low stock';
      default:
        return (type ?? 'Notification').toString();
    }
  }

  bool _isRead(dynamic value) {
    return value == true || value == 1 || value == '1' || value == 'true';
  }

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
