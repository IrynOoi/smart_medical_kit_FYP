// lib/services/api/device_service.dart
// Service class for all device-related API calls (IoT devices, prescriptions, remote control)

import 'dart:convert';
import 'api_client.dart';

class DeviceService {
  // ---------------------- Get Device for a Patient ----------------------
  /// Fetch the IoT device currently linked to a patient (via active prescription).
  /// Returns a Map with device details (id, serial, battery, IP, etc.),
  /// or an empty Map if none found or on error.
  Future<Map<String, dynamic>> getPatientDevice(int patientId) async {
    try {
      final response = await ApiClient.get('/iot_device/patient/$patientId');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return jsonResponse['data'];
      }
      return {};
    } catch (e) {
      return {}; // Return empty on any exception (network, parse, etc.)
    }
  }

  // ---------------------- Get Device IP by ID ----------------------
  /// Static method to retrieve the last known IP address of a specific device.
  /// Returns the IP as a String, or null if not found/error.
  static Future<String?> getDeviceIp(int deviceId) async {
    try {
      final response = await ApiClient.get('/device/$deviceId/ip');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return jsonResponse['ip'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------------------- List All Devices ----------------------
  /// Fetch the full list of registered IoT devices.
  /// Returns a List of device maps, or an empty list on error.
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

  // ---------------------- Get Device by ID ----------------------
  /// Retrieve a single device's details (including battery, IP, etc.).
  /// Returns a Map<String, dynamic> or null if not found/error.
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

  // ---------------------- Get Patient Linked to Device ----------------------
  /// Find the patient (patient_id) currently assigned to a given device.
  /// Returns the patient ID as int, or null if no patient linked / error.
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

  // ---------------------- Get Prescriptions for a Device ----------------------
  /// Retrieve all active prescriptions linked to medications assigned to this device.
  /// Returns a List of prescription maps (with medication, patient, schedules).
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

  // ---------------------- Create Device + Prescription in One Call ----------------------
  /// Convenience endpoint: registers a new device, links it to a medication,
  /// and creates a default prescription for a patient.
  /// Expects data: device_serial, patient_id, motor_slot, medication_id,
  ///               current_inventory (optional), refill_threshold (optional).
  /// Returns true on success, false otherwise.
  Future<bool> createDeviceWithPrescription(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post(
        '/device/create_with_prescription',
        body: data,
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------- Get Prescription for Device-Patient Pair ----------------------
  /// Fetch the specific prescription that links a given device and patient.
  /// Used to verify association or get motor_slot/inventory details.
  /// Returns a Map or null if not found/error.
  Future<Map<String, dynamic>?> getPrescriptionForDevicePatient(
    int deviceId,
    int patientId,
  ) async {
    try {
      final response = await ApiClient.get(
        '/device/$deviceId/patient/$patientId/prescription',
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return jsonResponse['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------------------- Update Device Prescription (Link) ----------------------
  /// Update or create a prescription linking a device to a patient/medication.
  /// Expects data: patient_id, motor_slot, medication_id,
  ///               current_inventory, refill_threshold.
  /// Returns true on success, false otherwise.
  Future<bool> updateDevicePrescription(
    int id, // device_id
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiClient.put(
        '/device/$id/prescription',
        body: data,
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------- Update Device Serial ----------------------
  /// Change the serial number of an existing device.
  /// Expects data: device_serial (new serial).
  /// Returns true on success, false otherwise.
  Future<bool> updateDevice(int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.put('/iot_device/$id', body: data);
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------- Delete Device ----------------------
  /// Permanently delete a device (only if not referenced by any medication).
  /// Returns true on success, false otherwise.
  Future<bool> deleteDevice(int id) async {
    try {
      final response = await ApiClient.delete('/iot_device/$id');
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------- Remote Control: LED ----------------------
  /// Send a command to turn the patient's device LED on or off.
  /// turnOn: true for 'on', false for 'off'.
  /// Returns true if the command was successfully sent and executed.
  Future<bool> controlLed(int patientId, bool turnOn) async {
    try {
      final response = await ApiClient.post(
        '/device/control/led',
        body: {'patient_id': patientId, 'action': turnOn ? 'on' : 'off'},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------- Remote Control: Buzzer ----------------------
  /// Turn the device buzzer on or off.
  /// Returns true on success.
  Future<bool> controlBuzzer(int patientId, bool turnOn) async {
    try {
      final response = await ApiClient.post(
        '/device/control/buzzer',
        body: {'patient_id': patientId, 'action': turnOn ? 'on' : 'off'},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------- Remote Control: Display ----------------------
  /// Send a display command to the ESP32 (e.g., 'hello', 'clear', 'sv').
  /// Returns true on success.
  Future<bool> controlDisplay(int patientId, String command) async {
    try {
      final response = await ApiClient.post(
        '/device/control/display',
        body: {'patient_id': patientId, 'command': command},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------- Remote Control: Stepper Motor ----------------------
  /// Control a specific stepper motor (1-3) with an action: forward/backward/90/180.
  /// Returns true on success.
  Future<bool> controlStepper(int patientId, int motor, String action) async {
    try {
      final response = await ApiClient.post(
        '/device/control/stepper',
        body: {'patient_id': patientId, 'motor': motor, 'action': action},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
