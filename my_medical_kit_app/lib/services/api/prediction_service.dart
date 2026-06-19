// prediction_service.dart – Service class for AI prediction related API calls.
// Wraps the generic ApiClient to provide type‑safe methods for retrieving,
// recalculating, and saving AI adherence predictions for patients.
// Also supports batch prediction jobs for all patients.

import 'dart:convert';
import 'api_client.dart';
import '../../models/ai_prediction.dart';

class PredictionService {
  /// Fetch the latest AI prediction for a patient.
  /// Returns an AIPrediction object if found, otherwise null.
  /// GET /patient/{patientId}/ai_prediction
  Future<AIPrediction?> getAIPrediction(int patientId) async {
    try {
      // Use the generic GET method from ApiClient
      final response = await ApiClient.get('/patient/$patientId/ai_prediction');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return AIPrediction.fromJson(jsonResponse['data']);
        }
      }
      return null;
    } catch (e) {
      return null; // Return null on any error
    }
  }

  /// Force a fresh AI prediction for a patient and save it to the database.
  /// POST /predict_and_save with {patient_id}
  /// Returns the updated AIPrediction object or null on failure.
  Future<AIPrediction?> recalculatePrediction(int patientId) async {
    try {
      final response = await ApiClient.post(
        '/predict_and_save',
        body: {'patient_id': patientId},
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          return AIPrediction.fromJson(jsonResponse['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Predict and save for a patient, returning the raw server response as a Map.
  /// This method is used when the caller needs full access to the response
  /// (e.g., for error messages or custom handling).
  /// POST /predict_and_save with all required fields.
  Future<Map<String, dynamic>> predictAndSaveForPatient({
    required int patientId,
    required int age,
    required String dayOfWeek,
    required String timeOfDay,
    required List<int> history,
  }) async {
    try {
      final response = await ApiClient.post(
        '/predict_and_save',
        body: {
          'patient_id': patientId,
          'age': age,
          'day_of_week': dayOfWeek,
          'time_of_day': timeOfDay,
          'history': history,
        },
      );

      // Important: return the whole decoded JSON map (including success, data, etc.)
      return jsonDecode(response.body);
    } catch (e) {
      // Return a failure map on error
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Predict and save for a patient, returning a simple boolean success flag.
  /// POST /predict_and_save with all required fields.
  /// Useful when only success/failure is needed.
  Future<bool> predictAndSave({
    required int patientId,
    required int age,
    required String dayOfWeek,
    required String timeOfDay,
    required List<int> history,
  }) async {
    try {
      final response = await ApiClient.post(
        '/predict_and_save',
        body: {
          'patient_id': patientId,
          'age': age,
          'day_of_week': dayOfWeek,
          'time_of_day': timeOfDay,
          'history': history,
        },
      );
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Trigger a batch AI prediction job for all active patients.
  /// POST /run_ai_analytics_job (no body required).
  /// Returns true if the job was triggered successfully, false otherwise.
  Future<bool> runBatchPrediction() async {
    try {
      final response = await ApiClient.post('/run_ai_analytics_job');
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
