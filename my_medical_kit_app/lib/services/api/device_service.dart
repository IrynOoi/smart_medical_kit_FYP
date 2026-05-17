// lib/services/api/device_service.dart
import 'dart:convert';
import 'api_client.dart';

class DeviceService {
  Future<Map<String, dynamic>> getPatientDevice(int patientId) async {
    try {
      final response = await ApiClient.get('/iot_device/patient/$patientId');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return jsonResponse['data'];
      }
      return {};
    } catch (e) {
      return {};
    }
  }

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

  Future<bool> controlLed(int patientId, bool turnOn) async {
    try {
      final response = await ApiClient.post('/device/control/led', body: {
        'patient_id': patientId,
        'action': turnOn ? 'on' : 'off',
      });
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> controlBuzzer(int patientId, bool turnOn) async {
    try {
      final response = await ApiClient.post('/device/control/buzzer', body: {
        'patient_id': patientId,
        'action': turnOn ? 'on' : 'off',
      });
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> controlDisplay(int patientId, String command) async {
    try {
      final response = await ApiClient.post('/device/control/display', body: {
        'patient_id': patientId,
        'command': command,
      });
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> controlStepper(int patientId, int motor, String action) async {
    try {
      final response = await ApiClient.post('/device/control/stepper', body: {
        'patient_id': patientId,
        'motor': motor,
        'action': action,
      });
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
