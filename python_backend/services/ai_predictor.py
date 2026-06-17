#ai_predictor.py
import os
import joblib
import numpy as np
import tensorflow as tf
import datetime
import json
from config import MODEL_PATHS
from models.analytics_model import get_patient_history_for_ai, save_hybrid_ai_prediction, delete_ai_prediction

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

def compute_prediction_for_patient(patient_id):
    """
    Compute HYBRID prediction using LSTM and Random Forest, store in DB.
    """
    age, history_vals = get_patient_history_for_ai(patient_id)

    if history_vals is None:
        print(f"[AI] Skipping patient {patient_id}: no adherence history.")
        delete_ai_prediction(patient_id)
        return None

    # 3. Current day & time
    now = datetime.datetime.now()
    day_of_week = now.strftime('%A')
    hour = now.hour
    time_of_day = 'Morning' if 5 <= hour < 12 else 'Afternoon' if 12 <= hour < 18 else 'Evening'

    days_map = {'Monday':0, 'Tuesday':1, 'Wednesday':2, 'Thursday':3, 'Friday':4, 'Saturday':5, 'Sunday':6}
    times_map = {'Morning':0, 'Afternoon':1, 'Evening':2}
    day_val = days_map[day_of_week]
    time_val = times_map[time_of_day]

    # 4. Run Hybrid Models
    if lstm_model is None or rf_model is None:
        forget_prob = 0.35
    else:
        # LSTM
        lstm_input_data = []
        for past in history_vals[-3:]:
            lstm_input_data.append([age/100.0, day_val/6.0, time_val/2.0, float(past)])
        lstm_input_array = np.array([lstm_input_data])
        lstm_forget_prob = float(lstm_model.predict(lstm_input_array, verbose=0)[0][0])

        # Random Forest
        missed_count = history_vals.count(0.0)
        rf_input_array = np.array([[age, day_val, time_val, missed_count]])
        rf_forget_prob = float(rf_model.predict_proba(rf_input_array)[0][1])

        forget_prob = (lstm_forget_prob * 0.50) + (rf_forget_prob * 0.50)

        print(f"\nHybrid AI Prediction for patient {patient_id}:")
        print(f"   LSTM voted: {lstm_forget_prob*100:.1f}% risk")
        print(f"   RF voted:   {rf_forget_prob*100:.1f}% risk")
        print(f"   Final Risk: {forget_prob*100:.1f}%")

    # 5. Convert to adherence score and risk level
    prediction_score = round(forget_prob * 100, 2)
    if forget_prob > 0.5:
        risk_level = "HIGH"
    elif forget_prob > 0.3:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"

    features_used = {
        "age": age,
        "day_of_week": day_of_week,
        "time_of_day": time_of_day,
        "recent_history": history_vals,
        "forget_probability_raw": forget_prob,
        "ai_type": "Hybrid (LSTM + RF)"
    }

    # 6. Save to database (UPSERT)
    new_pred = save_hybrid_ai_prediction(patient_id, prediction_score, risk_level, features_used)
    return new_pred

def get_models():
    return lstm_model, rf_model
