//caregiver_devices_list_page.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';
import 'package:my_medical_kit_app/services/api/device_service.dart';

class CaregiverDevicesListPage extends StatefulWidget {
  final int caregiverId;
  const CaregiverDevicesListPage({super.key, required this.caregiverId});

  @override
  State<CaregiverDevicesListPage> createState() =>
      CaregiverDevicesListPageState();
}

class CaregiverDevicesListPageState extends State<CaregiverDevicesListPage> {
  
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _medications = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchDevices(), _fetchMedications()]);
  }

  Future<void> _fetchDevices() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final patients = await CaregiverService().getCaregiverPatients(
        widget.caregiverId,
      );
      final devices = patients
          .where((p) => p['device_serial'] != null)
          .toList();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMedications() async {
    final meds = await MedicationService().getMedications();
    setState(() {
      _medications = meds.cast<Map<String, dynamic>>();
    });
  }

  // ------------------------------------------------------------------
  // Add Device Dialog (with full prescription creation)
  // ------------------------------------------------------------------
  Future<void> _showAddDeviceDialog() async {
    final serialController = TextEditingController();
    // 👇 添加监听器，自动把纯数字变成 DISP-xxx
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

    final inventoryController = TextEditingController(text: '30');
    final thresholdController = TextEditingController(text: '10');
    final formKey = GlobalKey<FormState>();

    final patients = await CaregiverService().getCaregiverPatients(widget.caregiverId);
    if (!mounted) return;
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patients available to assign device to'),
        ),
      );
      return;
    }
    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No medications found in system')),
      );
      return;
    }

    final patientOptions = patients.map((p) {
      return <String, dynamic>{
        'patient_id': p['patient_id'],
        'full_name': p['full_name'],
      };
    }).toList();

    int? selectedPatientId = patientOptions.first['patient_id'] as int?;
    int selectedMotorSlot = 1;
    int? selectedMedicationId = _medications.first['medication_id'] as int?;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add New Device & Prescription'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: serialController,
                    decoration: const InputDecoration(
                      labelText: 'Device Serial',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedPatientId,
                    items: patientOptions.map((p) {
                      return DropdownMenuItem<int>(
                        value: p['patient_id'] as int,
                        child: Text(p['full_name'] as String),
                      );
                    }).toList(),
                    onChanged: (newValue) =>
                        setStateDialog(() => selectedPatientId = newValue),
                    decoration: const InputDecoration(
                      labelText: 'Assign to Patient',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedMotorSlot,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Motor Slot 1')),
                      DropdownMenuItem(value: 2, child: Text('Motor Slot 2')),
                      DropdownMenuItem(value: 3, child: Text('Motor Slot 3')),
                    ],
                    onChanged: (newValue) =>
                        setStateDialog(() => selectedMotorSlot = newValue!),
                    decoration: const InputDecoration(labelText: 'Motor Slot'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedMedicationId,
                    items: _medications.map((med) {
                      return DropdownMenuItem<int>(
                        value: med['medication_id'] as int,
                        child: Text(med['medication_name'] as String),
                      );
                    }).toList(),
                    onChanged: (newValue) =>
                        setStateDialog(() => selectedMedicationId = newValue),
                    decoration: const InputDecoration(labelText: 'Medication'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: inventoryController,
                    decoration: const InputDecoration(
                      labelText: 'Initial Inventory',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: thresholdController,
                    decoration: const InputDecoration(
                      labelText: 'Refill Threshold',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
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
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && formKey.currentState!.validate()) {
      // All-in-one API call expected: create device, link to patient, create prescription
      final success = await DeviceService().createDeviceWithPrescription({
        'serial': serialController.text,
        'patient_id': selectedPatientId!,
        'motor_slot': selectedMotorSlot,
        'medication_id': selectedMedicationId!,
        'inventory': int.parse(inventoryController.text),
        'threshold': int.parse(thresholdController.text),
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device and prescription added')),
        );
        _fetchDevices();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add device')));
      }
    }
  }

  // ------------------------------------------------------------------
  // Edit Device (assignment + prescription details)
  // ------------------------------------------------------------------
  Future<void> _showEditAssignmentDialog(Map<String, dynamic> device) async {
    final patients = await CaregiverService().getCaregiverPatients(widget.caregiverId);

    final patientOptions = patients.map((p) {
      return <String, dynamic>{
        'patient_id': p['patient_id'],
        'full_name': p['full_name'],
      };
    }).toList();

    if (patientOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patients available to assign')),
      );
      return;
    }

    int? selectedPatientId = device['patient_id'] as int?;
    if (selectedPatientId == null && patientOptions.isNotEmpty) {
      selectedPatientId = patientOptions.first['patient_id'] as int;
    }

    int selectedMotorSlot = 1;
    int selectedMedicationId = 1;
    int currentInventory = 30;
    int refillThreshold = 10;

    // Fetch existing prescription if any
    if (selectedPatientId != null) {
      try {
        final prescription = await DeviceService().getPrescriptionForDevicePatient(
          device['device_id'] as int,
          selectedPatientId,
        );
        if (prescription != null) {
          selectedMotorSlot = (prescription['motor_slot'] as int?) ?? 1;
          selectedMedicationId = (prescription['medication_id'] as int?) ?? 1;
          currentInventory = (prescription['current_inventory'] as int?) ?? 30;
          refillThreshold = (prescription['refill_threshold'] as int?) ?? 10;
        }
      } catch (_) {}
    }

    final inventoryController = TextEditingController(
      text: currentInventory.toString(),
    );
    final thresholdController = TextEditingController(
      text: refillThreshold.toString(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Edit Device & Prescription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedPatientId,
                  items: patientOptions.map((p) {
                    return DropdownMenuItem<int>(
                      value: p['patient_id'] as int,
                      child: Text(p['full_name'] as String),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setStateDialog(() => selectedPatientId = newValue);
                    // Optionally reload prescription for new patient
                  },
                  decoration: const InputDecoration(labelText: 'Patient'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedMotorSlot,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Motor Slot 1')),
                    DropdownMenuItem(value: 2, child: Text('Motor Slot 2')),
                    DropdownMenuItem(value: 3, child: Text('Motor Slot 3')),
                  ],
                  onChanged: (newValue) =>
                      setStateDialog(() => selectedMotorSlot = newValue!),
                  decoration: const InputDecoration(labelText: 'Motor Slot'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedMedicationId,
                  items: _medications.map((med) {
                    return DropdownMenuItem<int>(
                      value: med['medication_id'] as int,
                      child: Text(med['medication_name'] as String),
                    );
                  }).toList(),
                  onChanged: (newValue) =>
                      setStateDialog(() => selectedMedicationId = newValue!),
                  decoration: const InputDecoration(labelText: 'Medication'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: inventoryController,
                  decoration: const InputDecoration(
                    labelText: 'Current Inventory',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: thresholdController,
                  decoration: const InputDecoration(
                    labelText: 'Refill Threshold',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedPatientId != null) {
      final success = await DeviceService().updateDevicePrescription(
        device['device_id'] as int,
        {
          'patient_id': selectedPatientId!,
          'motor_slot': selectedMotorSlot,
          'medication_id': selectedMedicationId,
          'current_inventory': int.parse(inventoryController.text),
          'refill_threshold': int.parse(thresholdController.text),
        },
      );
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Updated')));
        _fetchDevices();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Update failed')));
      }
    }
  }

  // ------------------------------------------------------------------
  // Edit device serial
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
            decoration: const InputDecoration(labelText: 'Device Serial'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed == true && formKey.currentState!.validate()) {
      final success = await DeviceService().updateDevice(
        device['device_id'],
        {'device_serial': controller.text},
      );
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Device updated')));
        _fetchDevices();
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Update failed')));
      }
    }
  }

  // ------------------------------------------------------------------
  // Delete device
  // ------------------------------------------------------------------
  Future<void> _confirmDelete(Map<String, dynamic> device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text(
          'Delete ${device['device_serial']}? This will also unlink it from patients.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final success = await DeviceService().deleteDevice(device['device_id']);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Device deleted')));
        _fetchDevices();
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Delete failed')));
      }
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.alphaBlend(
        AppColors.primaryPurple.withValues(alpha: 0.10),
        Colors.white,
      ),
      appBar: AppBar(
        title: const Text(
          'Devices',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDeviceDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDevices,
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
            ? const Center(child: Text('No devices registered.'))
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _devices.length,
                itemBuilder: (_, i) {
                  final d = _devices[i];
                  final battery = d['battery_level'] ?? 100;
                  final isLowBattery = battery < 20;
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.devices,
                        color: isLowBattery ? Colors.red : Colors.green,
                      ),
                      title: Text(
                        d['device_serial'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient: ${d['full_name']} • Battery: $battery%',
                          ),
                          if (d['inventory'] != null)
                            Text(
                              'Stock: ${d['inventory']} left (Threshold: ${d['refill_threshold']})',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditAssignmentDialog(d),
                          ),

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
