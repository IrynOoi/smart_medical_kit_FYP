// caregiver_devices_list_page.dart
// Displays a list of all hardware devices (IoT pill dispensers) registered in the system.
// Allows caregivers to:
//   - Register a new device (with auto-formatting of serial numbers).
//   - Edit a device's serial number.
//   - Delete a device (unlinks it from any medications/patients).
// Shows battery level, online/offline status (based on last known IP), and low-battery warnings.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/api_client.dart';

class CaregiverDevicesListPage extends StatefulWidget {
  final int
  caregiverId; // Currently logged-in caregiver's ID (not used in this page, but kept for future use)

  const CaregiverDevicesListPage({super.key, required this.caregiverId});

  @override
  State<CaregiverDevicesListPage> createState() =>
      CaregiverDevicesListPageState();
}

class CaregiverDevicesListPageState extends State<CaregiverDevicesListPage> {
  List<Map<String, dynamic>> _devices = []; // List of device maps from API
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchDevices(); // Load devices when the screen is first created.
  }

  static const int _onlineThresholdHours = 24;

  // Fetches all devices from the backend via the /devices endpoint.
  // If [showLoading] is true, shows the loading indicator; otherwise refreshes silently.
  Future<void> _fetchDevices({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _isLoading = true;
      _error = '';
    });
    try {
      final response = await ApiClient.get('/devices');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          setState(() {
            _devices = List<Map<String, dynamic>>.from(json['data']);
            _isLoading = false;
          });
          return;
        }
      }
      throw Exception('Failed to load devices');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Formats a timestamp to a human-readable relative time (e.g., "2h ago", "Just now").
  String _formatLastActive(dynamic timestamp) {
    if (timestamp == null || timestamp.toString().isEmpty) return 'Never';
    try {
      final dateTime = DateTime.tryParse(timestamp.toString());
      if (dateTime == null) return 'Never';
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Determines if the device is considered online based on its last heartbeat.
  bool _isDeviceOnlineFromTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp.toString().isEmpty) return false;
    try {
      final last = DateTime.tryParse(timestamp.toString());
      if (last == null) return false;
      return DateTime.now().difference(last).inHours < _onlineThresholdHours;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Add Device Dialog (Hardware Only)
  // ------------------------------------------------------------------
  Future<void> _showAddDeviceDialog() async {
    final serialController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Register New Device',
          style: TextStyle(
            color: AppColors.primaryPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the numeric device serial ID (e.g., enter 1 for DISP-1).',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: serialController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Device Serial Number (e.g. 1)',
                  prefixIcon: const Icon(
                    Icons.router,
                    color: AppColors.primaryPurple,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Serial number is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Register'),
          ),
        ],
      ),
    );

    if (confirmed == true && formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final numInput = serialController.text.trim();
        final fullSerial = numInput.startsWith('DISP-') ? numInput : 'DISP-$numInput';

        // Send a POST request to register the device with an initial battery level of 100.
        final response = await ApiClient.post(
          '/iot_device',
          body: {'device_serial': fullSerial, 'battery': 100},
        );

        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device registered successfully!')),
          );
          _fetchDevices(); // Refresh the list after adding.
        } else {
          throw Exception(json['message'] ?? 'Failed to add device');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ------------------------------------------------------------------
  // Edit device serial ONLY (no other fields editable here)
  // ------------------------------------------------------------------
  Future<void> _showEditDialog(Map<String, dynamic> device) async {
    final existingSerial = device['device_serial']?.toString() ?? '';
    final digitsOnly = existingSerial.replaceAll(RegExp(r'[^0-9]'), '');
    final controller = TextEditingController(text: digitsOnly.isNotEmpty ? digitsOnly : existingSerial);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Device Serial'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Device Serial Number (e.g. 1)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final numInput = controller.text.trim();
        final fullSerial = numInput.startsWith('DISP-') ? numInput : 'DISP-$numInput';

        // Send a PUT request to update only the device serial.
        final response = await ApiClient.put(
          '/iot_device/${device['device_id']}',
          body: {'device_serial': fullSerial},
        );

        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device updated successfully')),
          );
          _fetchDevices(); // Refresh the list after editing.
        } else {
          throw Exception(json['message'] ?? 'Update failed');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ------------------------------------------------------------------
  // Delete device (with confirmation) – unlinks from medications/patients.
  // ------------------------------------------------------------------
  Future<void> _confirmDelete(Map<String, dynamic> device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text(
          'Delete ${device['device_serial']}? This will unlink it from any patients/medications it is attached to.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final response = await ApiClient.delete(
          '/iot_device/${device['device_id']}',
        );
        final json = jsonDecode(response.body);

        if (json['success'] == true) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Device deleted')));
          _fetchDevices(); // Refresh the list after deletion.
        } else {
          throw Exception(json['message'] ?? 'Delete failed');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.alphaBlend(
        AppColors.primaryPurple.withValues(alpha: 0.10),
        Colors.white,
      ),
      appBar: AppBar(
        title: const Text(
          'Hardware Devices',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Add device button (opens registration dialog)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDeviceDialog,
            tooltip: 'Register Device',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchDevices(showLoading: false),
        color: AppColors.primaryPurple,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchDevices,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _devices.isEmpty
            ? const Center(child: Text('No devices registered in the system.'))
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _devices.length,
                itemBuilder: (_, i) {
                  final d = _devices[i];
                  final rawBatt = d['battery_level'] ?? d['battery'];
                  final int? battery = rawBatt != null ? (rawBatt as num).toInt() : null;
                  final rawAwake = d['is_awake'];
                  final bool rawAwakeBool = !(rawAwake == false || rawAwake == 0);
                  final bool hasHeartbeat = _isDeviceOnlineFromTimestamp(d['last_active_timestamp']);
                  final isOnline = rawAwakeBool && hasHeartbeat;
                  final isLowBattery = isOnline && battery != null && battery < 20;

                  Color batteryColor;
                  if (!isOnline || battery == null) {
                    batteryColor = Colors.grey;
                  } else if (battery >= 50) {
                    batteryColor = const Color(0xFF10B981); // Green
                  } else if (battery >= 20) {
                    batteryColor = const Color(0xFFF59E0B); // Amber
                  } else {
                    batteryColor = const Color(0xFFEF4444); // Red
                  }

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? const Color(0xFFF3E8FF)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.router,
                            color: isOnline ? AppColors.primaryPurple : Colors.grey,
                            size: 24,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              d['device_serial'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            // Online/Offline Pill Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isOnline ? Colors.green : Colors.grey,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                isOnline ? 'ONLINE' : 'OFFLINE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isOnline ? Colors.green.shade700 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            // Battery & Power State Row
                            Row(
                              children: [
                                Icon(Icons.battery_std, size: 16, color: batteryColor),
                                const SizedBox(width: 4),
                                Text(
                                  isOnline && battery != null ? 'Battery: $battery%' : 'Battery: --',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isLowBattery
                                        ? Colors.red
                                        : (!isOnline || battery == null ? Colors.grey : Colors.black87),
                                    fontWeight: isLowBattery ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                if (isLowBattery) ...[
                                  const SizedBox(width: 4),
                                  const Text('⚠️', style: TextStyle(fontSize: 11)),
                                ],
                                const SizedBox(width: 12),
                                // Power status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFFE4E6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isOnline ? '⚡ Awake' : '🌙 Sleeping',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isOnline
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFFBE123C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // IP & Last Active Row
                            Row(
                              children: [
                                Text(
                                  d['last_known_ip'] != null && d['last_known_ip'].toString().isNotEmpty
                                      ? 'IP: ${d['last_known_ip']}'
                                      : 'IP: 192.168.1.100',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Colors.grey,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Sync: ${_formatLastActive(d['last_active_timestamp'])}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                              onPressed: () => _showEditDialog(d),
                              tooltip: 'Edit Serial',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => _confirmDelete(d),
                              tooltip: 'Delete Device',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
