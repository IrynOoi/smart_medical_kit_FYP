# analytics.py
import json
import datetime
import numpy as np
from flask import Blueprint, request, jsonify
from services.ai_predictor import compute_prediction_for_patient, get_models
from models.analytics_model import get_all_active_patients_for_batch, batch_upsert_predictions

analytics_bp = Blueprint('analytics', __name__)

@analytics_bp.route('/predict_and_save', methods=['POST'])
def predict_and_save():
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        if not patient_id:
            return jsonify({"success": False, "message": "patient_id required"}), 400
        
        new_pred = compute_prediction_for_patient(patient_id)
        return jsonify({
            "success": True,
            "message": "Prediction generated and saved",
            "data": new_pred
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@analytics_bp.route('/run_ai_analytics_job', methods=['POST'])
def run_ai_analytics_job():
    """Batch run AI predictions for all active patients and store results in DB."""
    try:
        lstm_model, rf_model = get_models()
        
        patients = get_all_active_patients_for_batch()
        inserted_count = 0
        for pat in patients:
            compute_prediction_for_patient(pat['patient_id'])
            inserted_count += 1
            
        return jsonify({"success": True, "message": f"Successfully updated AI predictions for {inserted_count} patients."})
    except Exception as e:
        print(f"Batch AI prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
