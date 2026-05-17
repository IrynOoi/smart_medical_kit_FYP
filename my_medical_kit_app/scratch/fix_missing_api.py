import os
import re

lib_dir = r"c:\Users\xienx\Desktop\UTEM\SEM 6\FYP\FYP_CODES\my_medical_kit_app\lib"
api_dir = os.path.join(lib_dir, 'services', 'api')

# 1. Update MedicationService
med_service_file = os.path.join(api_dir, 'medication_service.dart')
with open(med_service_file, 'r', encoding='utf-8') as f:
    med_content = f.read()

med_additions = """
  Future<List<dynamic>> getMedications() async {
    try {
      final response = await ApiClient.get('/medications');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return jsonResponse['data'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> addMedication(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post('/medications', body: data);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateMedication(int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.put('/medications/$id', body: data);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteMedication(int id) async {
    try {
      final response = await ApiClient.delete('/medications/$id');
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addPrescription(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post('/add_prescription', body: data);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePrescription(int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.put('/prescription/$id', body: data);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> deletePrescription(int id) async {
    try {
      final response = await ApiClient.delete('/prescription/$id');
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
"""
if 'getMedications()' not in med_content:
    med_content = med_content.replace('}\n', med_additions, 1)
    with open(med_service_file, 'w', encoding='utf-8') as f:
        f.write(med_content)
    print("Updated MedicationService")

# 2. Update DeviceService
dev_service_file = os.path.join(api_dir, 'device_service.dart')
with open(dev_service_file, 'r', encoding='utf-8') as f:
    dev_content = f.read()

dev_additions = """
  Future<List<dynamic>> getDevices() async {
    try {
      final response = await ApiClient.get('/devices');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return jsonResponse['data'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getDevice(int id) async {
    try {
      final response = await ApiClient.get('/device/$id');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return jsonResponse['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<int?> getPatientIdFromDevice(int deviceId) async {
    try {
      final response = await ApiClient.get('/device/$deviceId/patient');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] && jsonResponse['data'] != null) {
          return jsonResponse['data']['patient_id'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>> getDevicePrescriptions(int deviceId) async {
    try {
      final response = await ApiClient.get('/device/$deviceId/prescriptions');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return jsonResponse['data'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> createDeviceWithPrescription(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post('/device/create_with_prescription', body: data);
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPrescriptionForDevicePatient(int deviceId, int patientId) async {
    try {
      final response = await ApiClient.get('/device/$deviceId/patient/$patientId/prescription');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return jsonResponse['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateDevicePrescription(int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.put('/device/$id/prescription', body: data);
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateDevice(int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.put('/iot_device/$id', body: data);
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteDevice(int id) async {
    try {
      final response = await ApiClient.delete('/iot_device/$id');
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
"""

if 'getDevices()' not in dev_content:
    dev_content = dev_content.replace('}\n', dev_additions, 1)
    with open(dev_service_file, 'w', encoding='utf-8') as f:
        f.write(dev_content)
    print("Updated DeviceService")


# 3. Replace missed _apiService usages
mappings = {
    '_apiService.getMedications(': 'MedicationService().getMedications(',
    '_apiService.addMedication(': 'MedicationService().addMedication(',
    '_apiService.updateMedication(': 'MedicationService().updateMedication(',
    '_apiService.deleteMedication(': 'MedicationService().deleteMedication(',
    '_apiService.addPrescription(': 'MedicationService().addPrescription(',
    '_apiService.updatePrescription(': 'MedicationService().updatePrescription(',
    '_apiService.deletePrescription(': 'MedicationService().deletePrescription(',
    '_apiService.getDevicePrescriptions(': 'DeviceService().getDevicePrescriptions(',
    
    '_apiService.getDevices(': 'DeviceService().getDevices(',
    '_apiService.getDevice(': 'DeviceService().getDevice(',
    '_apiService.getPatientIdFromDevice(': 'DeviceService().getPatientIdFromDevice(',
    '_apiService.createDeviceWithPrescription(': 'DeviceService().createDeviceWithPrescription(',
    '_apiService.getPrescriptionForDevicePatient(': 'DeviceService().getPrescriptionForDevicePatient(',
    '_apiService.updateDevicePrescription(': 'DeviceService().updateDevicePrescription(',
    '_apiService.updateDevice(': 'DeviceService().updateDevice(',
    '_apiService.deleteDevice(': 'DeviceService().deleteDevice(',
    '_apiService.markDoseTaken(': 'MedicationService().recordMedicationTaken(',
    '_apiService.recordMedicationTaken(': 'MedicationService().recordMedicationTaken(',
    '_apiService.getPatientDevice(': 'DeviceService().getPatientDevice(',
    '_apiService.getCaregiverProfile(': 'CaregiverService().getCaregiverProfile(',
    '_apiService.getAtRiskPatients(': 'CaregiverService().getAtRiskPatients(',
}

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            file_path = os.path.join(root, file)
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            new_content = content
            for k, v in mappings.items():
                new_content = new_content.replace(k, v)

            if new_content != content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Refactored _apiService in: {file_path}")

