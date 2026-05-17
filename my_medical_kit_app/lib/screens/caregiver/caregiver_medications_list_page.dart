//medication list page
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/medication_service.dart';

class CaregiverMedicationsListPage extends StatefulWidget {
  const CaregiverMedicationsListPage({super.key});

  @override
  State<CaregiverMedicationsListPage> createState() =>
      CaregiverMedicationsListPageState();
}

class CaregiverMedicationsListPageState
    extends State<CaregiverMedicationsListPage> {
  
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final meds = await MedicationService().getMedications();
      setState(() {
        _medications = meds.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? prefixText}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primaryPurple),
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontSize: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // ------------------------------------------------------------------
  // Add medication (with inventory, device, motor slot)
  // ------------------------------------------------------------------
  Future<void> _showAddMedicationDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final inventoryController = TextEditingController(text: '0');
    final thresholdController = TextEditingController(text: '5');
    final deviceIdController = TextEditingController();
    final motorSlotController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add New Medication',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: _inputDecoration('Medication Name *', Icons.medical_services),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: inventoryController,
                  decoration: _inputDecoration('Initial Inventory', Icons.inventory),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v == null || int.tryParse(v) == null
                      ? 'Number required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: thresholdController,
                  decoration: _inputDecoration('Refill Threshold', Icons.warning_amber),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v == null || int.tryParse(v) == null
                      ? 'Number required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: deviceIdController,
                  decoration: _inputDecoration('Device ID (optional)', Icons.memory, prefixText: 'DISP '),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: motorSlotController,
                  decoration: _inputDecoration('Motor Slot (1-3, optional)', Icons.settings_applications),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed == true && formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final result = await MedicationService().addMedication({
        'medication_name': nameController.text.trim(),
        'current_inventory': int.tryParse(inventoryController.text) ?? 0,
        'refill_threshold': int.tryParse(thresholdController.text) ?? 5,
        if (deviceIdController.text.trim().isNotEmpty)
          'device_id': int.tryParse(deviceIdController.text),
        if (motorSlotController.text.trim().isNotEmpty)
          'motor_slot': int.tryParse(motorSlotController.text),
      });
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medication added successfully')),
        );
        _fetchMedications();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${result['message'] ?? result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------------
  // Edit medication (with all fields)
  // ------------------------------------------------------------------
  Future<void> _showEditDialog(Map<String, dynamic> medication) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: medication['medication_name'],
    );
    final inventoryController = TextEditingController(
      text: (medication['current_inventory'] ?? 0).toString(),
    );
    final thresholdController = TextEditingController(
      text: (medication['refill_threshold'] ?? 5).toString(),
    );
    final deviceIdController = TextEditingController(
      text: medication['device_id']?.toString() ?? '',
    );
    final motorSlotController = TextEditingController(
      text: medication['motor_slot']?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Medication',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: _inputDecoration('Medication Name *', Icons.medical_services),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: inventoryController,
                  decoration: _inputDecoration('Current Inventory', Icons.inventory),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v == null || int.tryParse(v) == null
                      ? 'Number required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: thresholdController,
                  decoration: _inputDecoration('Refill Threshold', Icons.warning_amber),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v == null || int.tryParse(v) == null
                      ? 'Number required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: deviceIdController,
                  decoration: _inputDecoration('Device ID (optional)', Icons.memory, prefixText: 'DISP '),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: motorSlotController,
                  decoration: _inputDecoration('Motor Slot (1-3, optional)', Icons.settings_applications),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final result = await MedicationService().updateMedication(
        medication['medication_id'],
        {
          'medication_name': nameController.text.trim(),
          'current_inventory': int.tryParse(inventoryController.text),
          'refill_threshold': int.tryParse(thresholdController.text),
          if (deviceIdController.text.trim().isNotEmpty)
            'device_id': int.tryParse(deviceIdController.text),
          if (motorSlotController.text.trim().isNotEmpty)
            'motor_slot': int.tryParse(motorSlotController.text),
        },
      );
      if (result['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Medication updated')));
        _fetchMedications();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${result['message'] ?? result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------------
  // Delete medication
  // ------------------------------------------------------------------
  Future<void> _confirmDelete(Map<String, dynamic> medication) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text(
          'Delete "${medication['medication_name']}"? This action cannot be undone.',
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
      setState(() => _isLoading = true);
      final result = await MedicationService().deleteMedication(
        medication['medication_id'],
      );
      if (result['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Medication deleted')));
        _fetchMedications();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? result['error'] ?? 'Delete failed',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE8FA),
      appBar: AppBar(
        title: const Text(
          'Medications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMedicationDialog,
        backgroundColor: AppColors.primaryPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMedications,
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
                      onPressed: _fetchMedications,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _medications.isEmpty
            ? const Center(child: Text('No medications found in the system.'))
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _medications.length,
                itemBuilder: (_, i) {
                  final m = _medications[i];
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryPurple.withOpacity(
                          0.1,
                        ),
                        child: const Icon(
                          Icons.medication,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      title: Text(
                        m['medication_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Inventory: ${m['current_inventory'] ?? 0}  |  Device: ${m['device_id'] ?? 'None'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(m),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(m),
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
