// lib/services/api/prediction_service.dart
import 'dart:convert';
import 'api_client.dart';
import '../../models/ai_prediction.dart';

class PredictionService {
  Future<AIPrediction?> getAIPrediction(int patientId) async {
    try {
      final response = await ApiClient.get('/patient/$patientId/ai_prediction');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return AIPrediction.fromJson(jsonResponse['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<AIPrediction?> recalculatePrediction(int patientId) async {
    try {
      final response = await ApiClient.post('/predict_and_save', body: {'patient_id': patientId});
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) return AIPrediction.fromJson(jsonResponse['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> predictAndSaveForPatient({
    required int patientId,
    int age = 60,
    String dayOfWeek = 'Monday',
    String timeOfDay = 'Morning',
    List<int> history = const [1, 1, 1],
  }) async {
    try {
      final response = await ApiClient.post('/predict_and_save', body: {
        'patient_id': patientId,
        'age': age,
        'day_of_week': dayOfWeek,
        'time_of_day': timeOfDay,
        'history': history,
      });
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['success']) return jsonResponse['data'];
      return {'error': jsonResponse['error'] ?? 'Unknown error'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<bool> predictAndSave({
    required int patientId,
    required int age,
    required String dayOfWeek,
    required String timeOfDay,
    required List<int> history,
  }) async {
    try {
      final response = await ApiClient.post('/predict_and_save', body: {
        'patient_id': patientId,
        'age': age,
        'day_of_week': dayOfWeek,
        'time_of_day': timeOfDay,
        'history': history,
      });
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } catch (e) {
      return false;
    }
  }

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
