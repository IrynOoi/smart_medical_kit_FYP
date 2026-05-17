// lib/services/api/medication_service.dart
import 'dart:convert';
import 'api_client.dart';
import '../../models/prescription.dart';

class MedicationService {
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
      return [];
    } catch (e) {
      return [];
    }
  }

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

  Future<bool> recordMedicationTaken(int prescriptionId, int deviceId) async {
    try {
      final response = await ApiClient.post('/record_medication', body: {
        'prescription_id': prescriptionId,
        'device_id': deviceId,
      });
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> restockMedication(int prescriptionId, int quantity) async {
    try {
      final response = await ApiClient.post('/restock_medication', body: {
        'prescription_id': prescriptionId,
        'quantity': quantity,
      });
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
