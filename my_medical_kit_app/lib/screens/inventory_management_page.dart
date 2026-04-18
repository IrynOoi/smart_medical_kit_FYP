// lib/screens/inventory_management_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api_service.dart';
import 'package:my_medical_kit_app/models/prescription.dart';

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
  Map<int, String> _patientNames = {};

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
      } else {
        await _loadCaregiverData();
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
  // RESTOCK WITH DIALOG (removes hardcoded quantity)
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
              if (value == null || value.isEmpty)
                return 'Please enter a quantity';
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
            ),
            child: const Text('Restock'),
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
  // TEST DEVICE (improved error handling)
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
      // Removed the SafeArea and outer Column to allow the purple header to reach the very top
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
  // DEVICE HEADER (Signal replaced with Online/Offline status)
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
  // PATIENT CONTROLS
  // ------------------------------------------------------------
  Widget _buildPatientControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Smart Kit Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primaryPurple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Buzzer & LED',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Trigger kit hardware to ensure it is working.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _testDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Test'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // INVENTORY SUMMARY
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
  // INVENTORY LIST (improved progress bar max)
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
