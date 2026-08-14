# =====================================================================
# ai_predictor.py – AI prediction service using a hybrid approach:
# LSTM (neural network) + Random Forest (ensemble learning) to predict
# the probability that a patient will miss their next medication dose.
#
# The predictions are based on:
#   - Patient age
#   - Current day of week and time of day
#   - Recent adherence history (last 3 logs: 1 = taken, 0 = missed)
#
# The final risk level (LOW/MEDIUM/HIGH) is derived from the combined
# probability and stored in the database for later retrieval.
# =====================================================================

import os
import joblib
import numpy as np
import tensorflow as tf
import datetime
import json

# Import configuration for model file paths
from config import MODEL_PATHS

# Import database helper functions for retrieving patient history,
# saving predictions, and deleting old ones.
from models.analytics_model import get_patient_history_for_ai, save_hybrid_ai_prediction, delete_ai_prediction


# ─── Global Model Loading ────────────────────────────────────────────
# Attempt to load the pre‑trained LSTM and Random Forest models from disk.
# If the files are missing or loading fails, the system falls back to
# a mock probability (0.35) instead of crashing.

print("Loading Hybrid AI Models...")
lstm_model = None
rf_model = None
try:
    if os.path.exists(MODEL_PATHS['lstm_model']) and os.path.exists(MODEL_PATHS['rf_model']):
        lstm_model = tf.keras.models.load_model(MODEL_PATHS['lstm_model'])
        rf_model = joblib.load(MODEL_PATHS['rf_model'])
        print("Hybrid AI Models (LSTM & Random Forest) loaded successfully!")
    else:
        print("Model files not found. Prediction API will use mock logic.")
except Exception as e:
    print(f"Error loading models: {e}")


# ─── Main Prediction Function ────────────────────────────────────────

def compute_prediction_for_patient(patient_id):
    """
    Compute a hybrid AI prediction for a given patient using both LSTM
    and Random Forest models, then store the result in the database.

    Args:
        patient_id (int): The ID of the patient.

    Returns:
        dict or None: The newly saved prediction record (from the database)
                      if successful, otherwise None if no adherence history
                      exists (which triggers deletion of any stale prediction).
    """
    # 1. Retrieve the patient's age and the last 3 adherence logs (TAKEN=1.0, MISSED=0.0).
    #    If no logs exist, history_vals will be None.
    age, history_vals = get_patient_history_for_ai(patient_id)

    # 2. If there is no adherence history for this patient, we cannot make a prediction.
    #    Delete any old prediction record and return None.
    if history_vals is None:
        print(f"[AI] Skipping patient {patient_id}: no adherence history.")
        delete_ai_prediction(patient_id)
        return None

    # 3. Gather current temporal features: day of week and time of day (morning/afternoon/evening).
    #    These are used as input to both models.
    now = datetime.datetime.now()
    day_of_week = now.strftime('%A')
    hour = now.hour
    time_of_day = 'Morning' if 5 <= hour < 12 else 'Afternoon' if 12 <= hour < 18 else 'Evening'

    # Map string values to numeric indices for model input.
    days_map = {'Monday':0, 'Tuesday':1, 'Wednesday':2, 'Thursday':3, 'Friday':4, 'Saturday':5, 'Sunday':6}
    times_map = {'Morning':0, 'Afternoon':1, 'Evening':2}
    day_val = days_map[day_of_week]
    time_val = times_map[time_of_day]

    # 4. Run the hybrid models (or use a fallback probability if models aren't available).
    if lstm_model is None or rf_model is None:
        # Default mock probability (35% chance of missing the next dose).
        forget_prob = 0.00
    else:
        # ── LSTM model ──────────────────────────────────────────────────────
        # Prepare input: for the last 3 history entries, construct a feature vector:
        # [age/100, day/6, time/2, adherence_flag] – normalised to [0,1].
        lstm_input_data = []
        for past in history_vals[-3:]:
            lstm_input_data.append([age/100.0, day_val/6.0, time_val/2.0, float(past)])
        lstm_input_array = np.array([lstm_input_data])
        lstm_forget_prob = float(lstm_model.predict(lstm_input_array, verbose=0)[0][0])

        # ── Random Forest model ────────────────────────────────────────────
        # Features: [age, day_val, time_val, missed_count] (not normalised).
        missed_count = history_vals.count(0.0)
        rf_input_array = np.array([[age, day_val, time_val, missed_count]])
        rf_forget_prob = float(rf_model.predict_proba(rf_input_array)[0][1])

        # ── Combine both predictions with equal weight (50% each) ──────────
        forget_prob = (lstm_forget_prob * 0.50) + (rf_forget_prob * 0.50)

        # Log the intermediate results for debugging.
        print(f"\nHybrid AI Prediction for patient {patient_id}:")
        print(f"   LSTM voted: {lstm_forget_prob*100:.1f}% risk")
        print(f"   RF voted:   {rf_forget_prob*100:.1f}% risk")
        print(f"   Final Risk: {forget_prob*100:.1f}%")

    # 5. Convert the raw probability to a percentage score and determine the risk level.
    prediction_score = round(forget_prob * 100, 2)   # e.g., 0.45 → 45.00%
    if forget_prob > 0.5:
        risk_level = "HIGH"
    elif forget_prob > 0.3:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"

    # Build a dictionary of features used for the prediction (for auditability).
    features_used = {
        "age": age,
        "day_of_week": day_of_week,
        "time_of_day": time_of_day,
        "recent_history": history_vals,
        "forget_probability_raw": forget_prob,
        "ai_type": "Hybrid (LSTM + RF)"
    }

    # 6. Save (upsert) the prediction into the database using the helper function.
    #    The function will insert a new record or update the existing one for this patient.
    new_pred = save_hybrid_ai_prediction(patient_id, prediction_score, risk_level, features_used)
    return new_pred


# ─── Utility Function ──────────────────────────────────────────────

def get_models():
    """
    Return the loaded LSTM and Random Forest model objects (or None if not loaded).
    This can be used by other modules to access the models directly.
    """
    return lstm_model, rf_model