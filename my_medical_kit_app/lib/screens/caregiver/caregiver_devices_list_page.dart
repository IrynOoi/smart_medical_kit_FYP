// caregiver_devices_list_page.dart
// Displays a list of all hardware devices (IoT pill dispensers) registered in the system.
// Allows caregivers to:
//   - Register a new device (with auto-formatting of serial numbers).
//   - Edit a device's serial number.
//   - Delete a device (unlinks it from any medications/patients).
// Shows battery level, online/offline status (based on last known IP), and low-battery warnings.

import 'dart:convert';
import 'package:flutter/material.dart';
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

  // ------------------------------------------------------------------
  // Add Device Dialog (Hardware Only)
  // ------------------------------------------------------------------
  Future<void> _showAddDeviceDialog() async {
    final serialController = TextEditingController();

    // Auto-prepend 'DISP-' for pure numbers (e.g., user types "3", it becomes "DISP-3")
    serialController.addListener(() {
      final text = serialController.text;
      if (text.isNotEmpty && RegExp(r'^\d+$').hasMatch(text)) {
        if (!text.startsWith('DISP-')) {
          serialController.value = TextEditingValue(
            text: 'DISP-$text',
            selection: TextSelection.collapsed(offset: ('DISP-$text').length),
          );
        }
      }
    });

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
                'Register a new hardware kit. You can assign it to a patient later in the Medications or Prescription pages.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: serialController,
                decoration: InputDecoration(
                  labelText: 'Device Serial (e.g. DISP-1)',
                  prefixIcon: const Icon(
                    Icons.router,
                    color: AppColors.primaryPurple,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Serial is required' : null,
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
        // Send a POST request to register the device with an initial battery level of 100.
        final response = await ApiClient.post(
          '/iot_device',
          body: {'device_serial': serialController.text.trim(), 'battery': 100},
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
    final controller = TextEditingController(text: device['device_serial']);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Device Serial'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Device Serial',
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
        // Send a PUT request to update only the device serial.
        final response = await ApiClient.put(
          '/iot_device/${device['device_id']}',
          body: {'device_serial': controller.text.trim()},
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
                  final battery = d['battery_level'] ?? 100;
                  final isLowBattery = battery < 20;
                  // If the device has a last_known_ip, consider it online.
                  final isOnline = d['last_known_ip'] != null;

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.router,
                        color: isOnline
                            ? (isLowBattery ? Colors.orange : Colors.green)
                            : Colors.grey,
                        size: 32,
                      ),
                      title: Text(
                        d['device_serial'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Battery: $battery%',
                            style: TextStyle(
                              color: isLowBattery ? Colors.red : Colors.black87,
                              fontWeight: isLowBattery
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            isOnline
                                ? 'IP: ${d['last_known_ip']}'
                                : 'Status: Offline',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit button: opens edit serial dialog.
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(d),
                          ),
                          // Delete button: opens confirmation dialog.
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(d),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
