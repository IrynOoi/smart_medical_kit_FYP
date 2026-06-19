// lib/screens/patient/patient_inventory_page.dart
// Patient view of their medication inventory and IoT device controls.
// Displays assigned medications with stock levels, device status (battery, online/offline),
// and provides a remote control panel for the IoT pill dispenser (LED, buzzer, display, stepper motors).
// Patients can view but NOT restock medications – that is a caregiver/admin function.

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';
import 'package:my_medical_kit_app/services/api/device_service.dart';

class PatientInventoryPage extends StatefulWidget {
  final int userId; // Patient's user ID

  const PatientInventoryPage({super.key, required this.userId});

  @override
  State<PatientInventoryPage> createState() => _PatientInventoryPageState();
}

class _PatientInventoryPageState extends State<PatientInventoryPage> {
  // State flags
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';

  // Data containers
  Map<String, dynamic> _deviceData =
      {}; // Device info from backend (serial, battery, IP, etc.)
  List<Map<String, dynamic>> _inventoryList =
      []; // List of medications with stock and prescription IDs

  // Direct device test (local IP control) – used for debugging
  int _selectedTestMotor = 1;
  String _testEspIp = '';
  final TextEditingController _espIpController = TextEditingController();

  // Threshold to consider device online (hours since last heartbeat)
  static const int _onlineThresholdHours = 24;

  @override
  void initState() {
    super.initState();
    _loadData();
    _espIpController.text = _testEspIp; // Initialise controller
  }

  // ---------------------- Load Data from API ----------------------
  Future<void> _loadData({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Get device linked to this patient
      final device = await DeviceService().getPatientDevice(widget.userId);
      _deviceData = device.isNotEmpty
          ? device
          : {
              'device_serial': 'Not connected',
              'battery_level': 0,
              'last_active_timestamp': null,
              'last_known_ip': null,
            };

      // Auto-populate the ESP IP from the device's last known IP
      final ipFromDb = _deviceData['last_known_ip'];
      if (ipFromDb != null && ipFromDb.toString().isNotEmpty) {
        _testEspIp = ipFromDb.toString();
        _espIpController.text = _testEspIp;
      }

      // 2. Get all medications (prescriptions) for this patient
      final prescriptions = await MedicationService().getPatientMedications(
        widget.userId,
      );
      // Map to a simpler format for display
      _inventoryList = prescriptions
          .map(
            (med) => {
              'prescription_id': med.prescriptionId,
              'medication_name': med.medicationName,
              'current_inventory': med.currentInventory,
              'refill_threshold': med.refillThreshold,
              'dosage_tablet': med.dosageTablet,
              'device_id': med.deviceId,
              'patient_id': widget.userId,
            },
          )
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load inventory data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _espIpController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // RESTOCK MEDICATION (Disabled for patients – this is a caregiver action)
  // The methods are kept but not used in the UI.
  // ------------------------------------------------------------
  Future<void> _showRestockDialog(
    int prescriptionId,
    String medicationName,
  ) async {
    // This dialog is NOT currently triggered in the UI (the Restock button is removed).
    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock $medicationName'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of pills to add',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a quantity';
              }
              final qty = int.tryParse(value);
              if (qty == null || qty <= 0) return 'Enter a positive number';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final quantity = int.parse(quantityController.text);
      await _restockMedication(prescriptionId, medicationName, quantity);
    }
  }

  Future<void> _restockMedication(
    int prescriptionId,
    String medicationName,
    int quantity,
  ) async {
    // This is only used if the dialog is triggered, but the Restock button is not shown.
    setState(() => _isRefreshing = true);
    try {
      final success = await MedicationService().restockMedication(
        prescriptionId,
        quantity,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Restocked $medicationName with $quantity pills!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      } else if (mounted) {
        throw Exception('Restock failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Restock failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // ------------------------------------------------------------
  // IOT CONTROL METHODS (Using Backend Proxy)
  // These send commands via the Flask backend, which forwards to the ESP32.
  // ------------------------------------------------------------
  Future<void> _controlLed(bool turnOn) async {
    final success = await DeviceService().controlLed(widget.userId, turnOn);
    _showControlResult(success, turnOn ? 'LED turned ON' : 'LED turned OFF');
  }

  Future<void> _controlBuzzer(bool turnOn) async {
    final success = await DeviceService().controlBuzzer(widget.userId, turnOn);
    _showControlResult(
      success,
      turnOn ? 'Buzzer turned ON' : 'Buzzer turned OFF',
    );
  }

  Future<void> _controlDisplay(String command) async {
    final success = await DeviceService().controlDisplay(
      widget.userId,
      command,
    );
    String message = command == 'hello'
        ? 'Displayed "Hello World"'
        : command == 'clear'
        ? 'Display cleared'
        : 'Displayed Supervisor name';
    _showControlResult(success, message);
  }

  Future<void> _controlStepper(int motor, String action) async {
    final success = await DeviceService().controlStepper(
      widget.userId,
      motor,
      action,
    );
    final actionText = action == 'forward'
        ? '360° Forward'
        : action == 'backward'
        ? '360° Backward'
        : action == '90'
        ? '90°'
        : '180°';
    _showControlResult(success, 'Motor $motor turned $actionText');
  }

  void _showControlResult(bool success, String successMessage) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ $successMessage'
              : '❌ Command failed. Device might be offline.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ------------------------------------------------------------
  // HELPER METHODS
  // ------------------------------------------------------------
  /// Formats a timestamp to a human-readable relative time (e.g., "2h ago").
  String _formatLastActive(String? timestamp) {
    if (timestamp == null) return 'Never';
    try {
      final dateTime = DateTime.parse(timestamp);
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
  bool _isDeviceOnlineFromTimestamp(String? timestamp) {
    if (timestamp == null) return false;
    try {
      final last = DateTime.parse(timestamp);
      return DateTime.now().difference(last).inHours < _onlineThresholdHours;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // UI BUILDERS
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Show loading spinner while data is being fetched.
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    // Show error message with retry option.
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(_errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Main UI: Device header, inventory summary, (optional direct test section),
    // and inventory list.
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      body: RefreshIndicator(
        onRefresh: () => _loadData(showLoading: false),
        color: AppColors.primaryPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDeviceHeader(),
              const SizedBox(height: 24),
              _buildInventorySummary(),
              const SizedBox(height: 24),
              // _buildDirectTestSection(), // (Commented out in original) Renders the full Device Control panel
              const SizedBox(height: 24),
              _buildInventorySection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // DIRECT COMMANDS TO ESP32 (using local IP, bypassing backend)
  // These are used in the "Direct Test" section for debugging.
  // ------------------------------------------------------------
  Future<void> _sendDirectCommand(String endpoint, String successMsg) async {
    if (_testEspIp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Device IP not available. Device may be offline.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final url = Uri.parse('http://$_testEspIp$endpoint');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $successMsg'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ------------------------------------------------------------
  // DIRECT TEST SECTION – Full remote control panel (Photo 1)
  // This section is called from the build but was commented out in the original.
  // It provides direct HTTP commands to the ESP32 using its IP.
  // ------------------------------------------------------------
  Widget _buildDirectTestSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with editable IP field
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.developer_board, color: Colors.blueGrey),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Device Control',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      controller: _espIpController,
                      decoration: const InputDecoration(
                        labelText: 'Device IP',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      onChanged: (value) => _testEspIp = value,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // LED & Buzzer controls
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _sendDirectCommand('/led/on', 'LED ON'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple.withValues(
                              alpha: 0.15,
                            ),
                            foregroundColor: AppColors.primaryPurple,
                            elevation: 0,
                          ),
                          child: const Text('LED ON'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _sendDirectCommand('/led/off', 'LED OFF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple.withValues(
                              alpha: 0.15,
                            ),
                            foregroundColor: AppColors.primaryPurple,
                            elevation: 0,
                          ),
                          child: const Text('LED OFF'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _sendDirectCommand('/buzzer/on', 'Buzzer ON'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple.withValues(
                              alpha: 0.15,
                            ),
                            foregroundColor: AppColors.primaryPurple,
                            elevation: 0,
                          ),
                          child: const Text('Buzzer ON'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _sendDirectCommand('/buzzer/off', 'Buzzer OFF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple.withValues(
                              alpha: 0.1,
                            ),
                            foregroundColor: AppColors.primaryPurple,
                            elevation: 0,
                          ),
                          child: const Text('Buzzer OFF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // OLED Display
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OLED Display',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            _sendDirectCommand('/display/hello', 'Hello World'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple.withOpacity(
                            0.15,
                          ),
                          foregroundColor: AppColors.primaryPurple,
                          elevation: 0,
                        ),
                        child: const Text('Hello'),
                      ),
                      ElevatedButton(
                        onPressed: () => _sendDirectCommand(
                          '/display/clear',
                          'Display cleared',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple.withOpacity(
                            0.15,
                          ),
                          foregroundColor: AppColors.primaryPurple,
                          elevation: 0,
                        ),
                        child: const Text('Clear'),
                      ),
                      ElevatedButton(
                        onPressed: () => _sendDirectCommand(
                          '/display/sv',
                          'Supervisor Name',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple.withOpacity(
                            0.15,
                          ),
                          foregroundColor: AppColors.primaryPurple,
                          elevation: 0,
                        ),
                        child: const Text('Supervisor'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Stepper Motors
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stepper Motors',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Motor:'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 1, label: Text('1')),
                            ButtonSegment(value: 2, label: Text('2')),
                            ButtonSegment(value: 3, label: Text('3')),
                          ],
                          selected: {_selectedTestMotor},
                          onSelectionChanged: (Set<int> newSelection) {
                            setState(
                              () => _selectedTestMotor = newSelection.first,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDirectMotorButton(
                        'Forward 360°',
                        '/stepper${_selectedTestMotor == 1 ? '' : _selectedTestMotor}/forward',
                      ),
                      _buildDirectMotorButton(
                        'Backward 360°',
                        '/stepper${_selectedTestMotor == 1 ? '' : _selectedTestMotor}/backward',
                      ),
                      _buildDirectMotorButton(
                        '180°',
                        '/stepper${_selectedTestMotor == 1 ? '' : _selectedTestMotor}/180',
                      ),
                      _buildDirectMotorButton(
                        '90°',
                        '/stepper${_selectedTestMotor == 1 ? '' : _selectedTestMotor}/90',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for direct test motor buttons
  Widget _buildDirectMotorButton(String label, String endpoint) {
    return ElevatedButton(
      onPressed: () => _sendDirectCommand(endpoint, label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.08),
        foregroundColor: AppColors.primaryPurple,
        elevation: 0,
      ),
      child: Text(label),
    );
  }

  // ------------------------------------------------------------
  // DEVICE HEADER – Shows device name, status, battery, and stats
  // ------------------------------------------------------------
  Widget _buildDeviceHeader() {
    final batteryLevel = _deviceData['battery_level'];
    final isLowBattery = batteryLevel != null && batteryLevel < 20;
    final deviceName = _deviceData['device_serial'] ?? 'Not Connected';
    final isOnline = _isDeviceOnlineFromTimestamp(
      _deviceData['last_active_timestamp'],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 24,
        24,
        32,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primaryPurple,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Medical Kit',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.devices_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Smart Pill Dispenser',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      deviceName,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Online/Offline badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isOnline ? Colors.green : Colors.grey).withOpacity(
                    0.2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline ? Colors.greenAccent : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      color: isOnline
                          ? Colors.greenAccent
                          : Colors.grey.shade400,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline
                            ? Colors.greenAccent
                            : Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Three stat cards: Battery, Status, Sync
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDeviceStatCard(
                'Battery',
                batteryLevel != null ? '$batteryLevel%' : 'N/A',
                Icons.battery_charging_full_rounded,
                isLowBattery ? Colors.redAccent : Colors.greenAccent,
              ),
              _buildDeviceStatCard(
                'Status',
                isOnline ? 'Online' : 'Offline',
                isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                isOnline ? Colors.blueAccent : Colors.grey,
              ),
              _buildDeviceStatCard(
                'Sync',
                _formatLastActive(_deviceData['last_active_timestamp']),
                Icons.sync_rounded,
                Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Individual stat card for the header
  Widget _buildDeviceStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // REMOTE DEVICE CONTROLS (Photo 1 style – used if uncommented)
  // These are the backend‑proxy versions.
  // ------------------------------------------------------------
  Widget _buildRemoteControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Remote Device Control',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildControlCard(
            title: 'LED',
            icon: Icons.highlight,
            color: Colors.amber,
            child: Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    'ON',
                    Colors.green,
                    () => _controlLed(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControlButton(
                    'OFF',
                    Colors.red,
                    () => _controlLed(false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildControlCard(
            title: 'Buzzer',
            icon: Icons.volume_up,
            color: Colors.deepPurple,
            child: Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    'ON',
                    Colors.green,
                    () => _controlBuzzer(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControlButton(
                    'OFF',
                    Colors.red,
                    () => _controlBuzzer(false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildControlCard(
            title: 'OLED Display',
            icon: Icons.screenshot,
            color: Colors.teal,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildDisplayButton('hello', 'Hello', Icons.text_fields),
                _buildDisplayButton('clear', 'Clear', Icons.clear),
                _buildDisplayButton('sv', 'Supervisor', Icons.person),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildControlCard(
            title: 'Stepper Motors',
            icon: Icons.settings,
            color: Colors.orange,
            child: Column(
              children: [
                _buildMotorRow(1, Colors.blue),
                const SizedBox(height: 12),
                _buildMotorRow(2, Colors.green),
                const SizedBox(height: 12),
                _buildMotorRow(3, Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for remote control buttons
  Widget _buildControlButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text),
    );
  }

  Widget _buildControlCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDisplayButton(String command, String label, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () => _controlDisplay(command),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildMotorRow(int motor, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            'Motor $motor',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMotorButton(motor, 'forward', '360°', Icons.rotate_right),
              _buildMotorButton(motor, 'backward', '360° ←', Icons.rotate_left),
              _buildMotorButton(motor, '180', '180°', Icons.pie_chart_outline),
              _buildMotorButton(motor, '90', '90°', Icons.pie_chart),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMotorButton(
    int motor,
    String action,
    String label,
    IconData icon,
  ) {
    return ElevatedButton(
      onPressed: () => _controlStepper(motor, action),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
    );
  }

  // ------------------------------------------------------------
  // INVENTORY SUMMARY (Top cards: Total, Low Stock, Out of Stock)
  // ------------------------------------------------------------
  Widget _buildInventorySummary() {
    if (_inventoryList.isEmpty) return const SizedBox.shrink();

    int totalItems = _inventoryList.length;
    int lowStockCount = _inventoryList
        .where(
          (med) =>
              (med['current_inventory'] as int) <=
              (med['refill_threshold'] as int),
        )
        .length;
    int outOfStockCount = _inventoryList
        .where((med) => (med['current_inventory'] as int) == 0)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Meds',
              totalItems.toString(),
              Icons.medication_rounded,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Low Stock',
              lowStockCount.toString(),
              Icons.warning_amber_rounded,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Out of Stock',
              outOfStockCount.toString(),
              Icons.cancel_rounded,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // INVENTORY LIST – Shows each medication with stock bar and status
  // ------------------------------------------------------------
  Widget _buildInventorySection() {
    if (_inventoryList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              'No medications assigned to you yet.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Medication Inventory',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _inventoryList.length,
            itemBuilder: (context, index) =>
                _buildInventoryCard(_inventoryList[index]),
          ),
        ],
      ),
    );
  }

  // Individual medication card with stock bar, status badge, and (removed) restock button.
  Widget _buildInventoryCard(Map<String, dynamic> med) {
    final current = med['current_inventory'] as int;
    final threshold = med['refill_threshold'] as int;
    final isLowStock = current <= threshold;
    final isOutOfStock = current == 0;

    // Compute progress bar value (clamped between 0 and 1)
    final maxInventory = (threshold * 2) > current ? (threshold * 2) : current;
    final progressValue = maxInventory > 0
        ? (current / maxInventory).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOutOfStock
              ? Colors.red.withValues(alpha: 0.3)
              : isLowStock
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? Colors.red.withValues(alpha: 0.1)
                      : isLowStock
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOutOfStock
                      ? Icons.cancel
                      : isLowStock
                      ? Icons.warning
                      : Icons.check_circle,
                  color: isOutOfStock
                      ? Colors.red
                      : isLowStock
                      ? Colors.orange
                      : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  med['medication_name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? Colors.red.withValues(alpha: 0.1)
                      : isLowStock
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOutOfStock
                      ? 'Empty'
                      : (isLowStock ? 'Low Stock' : 'Sufficient'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isOutOfStock
                        ? Colors.red
                        : (isLowStock ? Colors.orange : Colors.green),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$current left',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Threshold: $threshold',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Stock progress bar
                    LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: Colors.grey.shade200,
                      color: isOutOfStock
                          ? Colors.red
                          : (isLowStock ? Colors.orange : Colors.green),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              // ❌ RESTOCK BUTTON REMOVED – patients cannot restock.
            ],
          ),
        ],
      ),
    );
  }
}
