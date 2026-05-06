// lib/screens/inventory_management_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';

class InventoryManagementPage extends StatefulWidget {
  final String role; // 'patient' or 'caregiver'
  final int userId;

  const InventoryManagementPage({
    super.key,
    required this.role,
    required this.userId,
  });

  @override
  State<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isRefreshing = false;
  String _errorMessage = '';

  Map<String, dynamic> _deviceData = {};
  List<Map<String, dynamic>> _inventoryList = [];
  final Map<int, String> _patientNames = {};

  // For caregiver: selected patient ID to control
  int? _selectedControlPatientId;
  Map<int, String> _controlPatientOptions = {};

  // Constant for determining online/offline status
  static const int _onlineThresholdHours = 24;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (widget.role == 'patient') {
        await _loadPatientData();
        // For patient, selected control patient is themselves
        _selectedControlPatientId = widget.userId;
      } else {
        await _loadCaregiverData();
        // Build patient options for dropdown
        _controlPatientOptions = Map.fromEntries(
          _inventoryList
              .map(
                (med) => MapEntry(
                  med['patient_id'] as int,
                  med['patient_name'] as String,
                ),
              )
              .toSet(),
        );
        if (_controlPatientOptions.isNotEmpty) {
          _selectedControlPatientId = _controlPatientOptions.keys.first;
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load inventory data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPatientData() async {
    final device = await _apiService.getPatientDevice(widget.userId);
    _deviceData = device.isNotEmpty
        ? device
        : {
            'device_serial': 'Not connected',
            'battery_level': 0,
            'last_active_timestamp': null,
          };

    final prescriptions = await _apiService.getPatientMedications(
      widget.userId,
    );
    _inventoryList = prescriptions
        .map(
          (med) => {
            'prescription_id': med.prescriptionId,
            'medication_name': med.medicationName,
            'current_inventory': med.currentInventory,
            'refill_threshold': med.refillThreshold,
            'patient_name': null,
            'dosage_tablet': med.dosageTablet,
            'device_id': med.deviceId,
            'patient_id': widget.userId,
          },
        )
        .toList();
  }

  Future<void> _loadCaregiverData() async {
    final patients = await _apiService.getCaregiverPatients(widget.userId);
    for (var patient in patients) {
      _patientNames[patient['patient_id']] = patient['full_name'] ?? 'Unknown';
    }

    _inventoryList = [];
    for (var patient in patients) {
      final patientId = patient['patient_id'];
      final prescriptions = await _apiService.getPatientMedications(patientId);
      for (var med in prescriptions) {
        _inventoryList.add({
          'prescription_id': med.prescriptionId,
          'medication_name': med.medicationName,
          'current_inventory': med.currentInventory,
          'refill_threshold': med.refillThreshold,
          'patient_name': _patientNames[patientId],
          'patient_id': patientId,
          'dosage_tablet': med.dosageTablet,
          'device_id': med.deviceId,
        });
      }
    }

    // For caregiver view, device info is not shown; set a placeholder.
    _deviceData = {
      'device_serial': 'N/A',
      'battery_level': null,
      'last_active_timestamp': null,
    };
  }

  // ------------------------------------------------------------
  // RESTOCK WITH DIALOG
  // ------------------------------------------------------------
  Future<void> _showRestockDialog(
    int prescriptionId,
    String medicationName,
  ) async {
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
            onPressed: () => _testDevice(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size(70, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Test'),
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
    setState(() => _isRefreshing = true);
    try {
      final success = await _apiService.restockMedication(
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
  // TEST DEVICE (kept for compatibility)
  // ------------------------------------------------------------
  Future<void> _testDevice() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/test_device/${widget.userId}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      final result = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Test signal sent successfully.',
            ),
            backgroundColor: AppColors.primaryPurple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send test signal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------
  // NEW IoT CONTROL METHODS (using backend proxy)
  // ------------------------------------------------------------
  Future<void> _controlLed(bool turnOn) async {
    if (_selectedControlPatientId == null) return;
    final success = await _apiService.controlLed(
      _selectedControlPatientId!,
      turnOn,
    );
    _showControlResult(success, turnOn ? 'LED turned ON' : 'LED turned OFF');
  }

  Future<void> _controlBuzzer(bool turnOn) async {
    if (_selectedControlPatientId == null) return;
    final success = await _apiService.controlBuzzer(
      _selectedControlPatientId!,
      turnOn,
    );
    _showControlResult(
      success,
      turnOn ? 'Buzzer turned ON' : 'Buzzer turned OFF',
    );
  }

  Future<void> _controlDisplay(String command) async {
    if (_selectedControlPatientId == null) return;
    final success = await _apiService.controlDisplay(
      _selectedControlPatientId!,
      command,
    );
    String message = '';
    switch (command) {
      case 'hello':
        message = 'Displayed "Hello World"';
        break;
      case 'clear':
        message = 'Display cleared';
        break;
      case 'sv':
        message = 'Displayed Supervisor name';
        break;
    }
    _showControlResult(success, message);
  }

  Future<void> _controlStepper(int motor, String action) async {
    if (_selectedControlPatientId == null) return;
    final success = await _apiService.controlStepper(
      _selectedControlPatientId!,
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
        content: Text(success ? '✅ $successMessage' : '❌ Command failed'),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ------------------------------------------------------------
  // FORMAT LAST ACTIVE & ONLINE STATUS
  // ------------------------------------------------------------
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

  bool _isDeviceOnline() {
    final lastActive = _deviceData['last_active_timestamp'];
    if (lastActive == null) return false;
    try {
      final last = DateTime.parse(lastActive);
      return DateTime.now().difference(last).inHours < _onlineThresholdHours;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // BUILD METHOD
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDeviceHeader(),
              const SizedBox(height: 24),
              if (widget.role == 'patient') _buildPatientControls(),
              const SizedBox(height: 24),
              _buildInventorySummary(),
              const SizedBox(height: 16),
              _buildInventorySection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // DEVICE HEADER
  // ------------------------------------------------------------
  Widget _buildDeviceHeader() {
    final batteryLevel = _deviceData['battery_level'];
    final isLowBattery = batteryLevel != null && batteryLevel < 20;
    final deviceName = _deviceData['device_serial'] ?? 'Not Connected';
    final isOnline = _isDeviceOnline();

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
            'Inventory & Device',
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
                  color: Colors.white.withOpacity(0.2),
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
  // PATIENT CONTROLS (now includes full IoT control)
  // ------------------------------------------------------------
  Widget _buildPatientControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient selector for caregiver (only visible if role == caregiver)
          if (widget.role == 'caregiver' && _controlPatientOptions.isNotEmpty)
            _buildPatientSelector(),
          const SizedBox(height: 16),

          const Text(
            'Remote Device Control',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),

          // LED & Buzzer Row
          _buildControlCard(
            title: 'LED',
            icon: Icons.highlight,
            color: Colors.amber,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _controlLed(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('ON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _controlLed(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OFF'),
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
                  child: ElevatedButton(
                    onPressed: () => _controlBuzzer(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('ON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _controlBuzzer(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('OFF'),
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
                // Motor 1 controls
                _buildMotorRow(1, Colors.blue),
                const SizedBox(height: 12),
                // Motor 2 controls
                _buildMotorRow(2, Colors.green),
                const SizedBox(height: 12),
                // Motor 3 controls
                _buildMotorRow(3, Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Patient',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selectedControlPatientId,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            items: _controlPatientOptions.entries.map((entry) {
              return DropdownMenuItem<int>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedControlPatientId = value;
              });
            },
          ),
        ],
      ),
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
            color: Colors.black.withOpacity(0.04),
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
  // INVENTORY SUMMARY (unchanged from original)
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
            color: Colors.black.withOpacity(0.04),
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
  // INVENTORY LIST (unchanged from original)
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
              'No medications found.',
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

  Widget _buildInventoryCard(Map<String, dynamic> med) {
    final current = med['current_inventory'] as int;
    final threshold = med['refill_threshold'] as int;
    final isLowStock = current <= threshold;
    final isOutOfStock = current == 0;

    // Set max for progress bar: either threshold * 2 or current, whichever is larger (minimum 10)
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
              ? Colors.red.withOpacity(0.3)
              : isLowStock
              ? Colors.orange.withOpacity(0.3)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? Colors.red.withOpacity(0.1)
                      : isLowStock
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med['medication_name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (widget.role == 'caregiver' &&
                        med['patient_name'] != null)
                      Text(
                        'Patient: ${med['patient_name']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? Colors.red.withOpacity(0.1)
                      : isLowStock
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
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
              if (widget.role == 'caregiver' && (isLowStock || isOutOfStock))
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: ElevatedButton(
                    onPressed: _isRefreshing
                        ? null
                        : () => _showRestockDialog(
                            med['prescription_id'],
                            med['medication_name'],
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isRefreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Restock',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
