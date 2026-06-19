// lib/services/api/medication_service.dart
// medication_service.dart – Service class for medication and prescription API calls.
// All methods use ApiClient for HTTP requests, which adds default headers
// (including ngrok-skip-browser-warning) and base URL.

import 'dart:convert';
import 'api_client.dart';
import '../../models/prescription.dart';

class MedicationService {
  /// Retrieve all active prescriptions for a patient.
  /// GET /patient/{patientId}/prescriptions
  ///
  /// Returns a List<Prescription> on success, or an empty list on failure.
  Future<List<Prescription>> getPatientMedications(int patientId) async {
    try {
      final response = await ApiClient.get('/patient/$patientId/prescriptions');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          final List<dynamic> data = jsonResponse['data'];
          return data.map((json) => Prescription.fromJson(json)).toList();
        }
      }
      return []; // Return empty list on any error
    } catch (e) {
      return [];
    }
  }

  /// Alternative method returning raw JSON data for patient prescriptions.
  /// GET /patient/{patientId}/prescriptions
  ///
  /// Throws an Exception if the request fails or response indicates failure.
  Future<List<dynamic>> getPatientPrescriptions(int patientId) async {
    final response = await ApiClient.get('/patient/$patientId/prescriptions');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    throw Exception('Failed to load prescriptions');
  }

  /// Fetch the master list of all medications in the system.
  /// GET /medications
  ///
  /// Returns a List of medication objects (raw JSON) or empty list on failure.
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

  /// Add a new medication to the master catalog.
  /// POST /medications with data (medication_name, current_inventory, etc.)
  ///
  /// Returns the server response as a Map.
  Future<Map<String, dynamic>> addMedication(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post('/medications', body: data);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update an existing medication in the master catalog.
  /// PUT /medications/{id} with updated fields.
  ///
  /// Returns the server response as a Map.
  Future<Map<String, dynamic>> updateMedication(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiClient.put('/medications/$id', body: data);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete a medication from the master catalog (if unused).
  /// DELETE /medications/{id}
  ///
  /// Returns the server response as a Map.
  Future<Map<String, dynamic>> deleteMedication(int id) async {
    try {
      final response = await ApiClient.delete('/medications/$id');
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create a new prescription for a patient.
  /// POST /add_prescription with all required fields.
  ///
  /// Returns the server response as a Map.
  Future<Map<String, dynamic>> addPrescription(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiClient.post('/add_prescription', body: data);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update an existing prescription configuration.
  /// PUT /prescription/{id} with updated fields.
  ///
  /// Returns the server response as a Map.
  Future<Map<String, dynamic>> updatePrescription(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiClient.put('/prescription/$id', body: data);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete a prescription (soft delete).
  /// DELETE /prescription/{id}
  ///
  /// Returns true if the deletion was successful, false otherwise.
  Future<bool> deletePrescription(int id) async {
    try {
      final response = await ApiClient.delete('/prescription/$id');
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Record that a medication dose has been dispensed (taken) by the device.
  /// POST /record_medication with prescription_id and device_id.
  ///
  /// Returns true if the dispense was recorded successfully, false otherwise.
  Future<bool> recordMedicationTaken(int prescriptionId, int deviceId) async {
    try {
      final response = await ApiClient.post(
        '/record_medication',
        body: {'prescription_id': prescriptionId, 'device_id': deviceId},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Restock a medication's inventory by prescription ID.
  /// POST /restock_medication with prescription_id and quantity.
  ///
  /// Returns true if the restock was successful, false otherwise.
  Future<bool> restockMedication(int prescriptionId, int quantity) async {
    try {
      final response = await ApiClient.post(
        '/restock_medication',
        body: {'prescription_id': prescriptionId, 'quantity': quantity},
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
