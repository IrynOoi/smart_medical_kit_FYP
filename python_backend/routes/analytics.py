# analytics.py - Blueprint for AI-based adherence prediction and batch analytics

import json
import datetime
import numpy as np
from flask import Blueprint, request, jsonify
from services.ai_predictor import compute_prediction_for_patient, get_models
from models.analytics_model import get_all_active_patients_for_batch, batch_upsert_predictions

# Create Blueprint for analytics routes
analytics_bp = Blueprint('analytics', __name__)


# ---------------------- Generate Prediction for a Single Patient ----------------------
@analytics_bp.route('/predict_and_save', methods=['POST'])
def predict_and_save():
    """
    Generate an AI adherence prediction for a specific patient and save it to the database.
    Expects JSON: patient_id.
    Returns the new prediction or an error if no adherence data exists.
    """
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        
        # Call the AI service to compute a prediction for this patient.
        # The function returns a dict with prediction details (e.g., risk score, factors)
        # or None if there is insufficient adherence history.
        new_pred = compute_prediction_for_patient(patient_id)
        
        # Handle the case where no adherence data is available to make a prediction.
        if new_pred is None:
            return jsonify({
                "success": False, 
                "message": "No adherence data found. Please take medication to generate insights."
            }), 200  # 200 OK so the client doesn't treat it as a server error, but success flag is False

        # Prediction generated and saved (the service function already performs the upsert)
        return jsonify({
            "success": True,
            "message": "Prediction generated and saved",
            "data": new_pred
        })
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Batch AI Analytics Job (for all active patients) ----------------------
@analytics_bp.route('/run_ai_analytics_job', methods=['POST'])
def run_ai_analytics_job():
    """
    Run AI predictions for all active patients in the system.
    This is intended to be called as a background job (e.g., nightly cron).
    It loops through active patients, computes predictions (if data exists),
    and saves them. Returns the count of patients for whom predictions were generated.
    """
    try:
        # Get a list of all active patients (those with is_active = True)
        patients = get_all_active_patients_for_batch()
        inserted_count = 0

        # Iterate over each patient and generate a prediction
        for pat in patients:
            # Validate that the patient record is a dict with a patient_id
            if pat and isinstance(pat, dict) and 'patient_id' in pat:
                # Compute prediction; may return None if no adherence history
                result = compute_prediction_for_patient(pat['patient_id'])
                
                # Only count it if a prediction was actually generated and saved
                if result is not None:
                    inserted_count += 1
                else:
                    print(f"Skipping prediction for patient {pat['patient_id']}: No history data.")
            else:
                print(f"Skipping invalid patient data: {pat}")

        return jsonify({
            "success": True,
            "message": f"Successfully updated AI predictions for {inserted_count} patients."
        })
    except Exception as e:
        print(f"Batch AI prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500