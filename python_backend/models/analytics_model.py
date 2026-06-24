# analytics_model.py - Functions for AI-based adherence predictions
# and analytics for patients and caregivers.

import json
from db import get_db_connection


# ----------------------------------------------------------------------
# Get the latest AI prediction for a single patient
# ----------------------------------------------------------------------
def get_latest_ai_prediction(patient_id):
    """
    Retrieve the most recent AI adherence prediction for a given patient.
    Returns a dictionary with: ad_id, patient_id, prediction_score, risk_level,
    predicted_at, features_used. If no prediction exists, returns None.
    """
    # Safety check: if patient no longer has enough adherence logs, delete the stale prediction.
    age, history_vals = get_patient_history_for_ai(patient_id)
    if history_vals is None:
        delete_ai_prediction(patient_id)
        return None

    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT ad_id, patient_id, prediction_score, risk_level, predicted_at, features_used
            FROM ai_adherence_prediction
            WHERE patient_id = %s
            ORDER BY predicted_at DESC LIMIT 1
        ''', (patient_id,))
        prediction = cursor.fetchone()
        cursor.close()
    return prediction


# ----------------------------------------------------------------------
# Save (or update) a hybrid AI prediction for a patient
# ----------------------------------------------------------------------
def save_hybrid_ai_prediction(patient_id, adherence_score, risk_level, features_used):
    """
    Insert or update the AI prediction for a patient.
    Uses ON DUPLICATE KEY UPDATE (assuming patient_id is unique in the table).
    After inserting/updating, it fetches and returns the new record as a dict.

    :param patient_id: ID of the patient
    :param adherence_score: numeric prediction score (e.g., probability of adherence)
    :param risk_level: string like 'LOW', 'MEDIUM', 'HIGH'
    :param features_used: dictionary of features used for prediction (will be JSON-serialized)
    :return: the newly inserted/updated prediction row as a dict
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)

        # Insert or update the prediction record
        cursor.execute('''
            INSERT INTO ai_adherence_prediction (patient_id, prediction_score, risk_level, predicted_at, features_used)
            VALUES (%s, %s, %s, CURRENT_TIMESTAMP, %s)
            ON DUPLICATE KEY UPDATE
                prediction_score = VALUES(prediction_score),
                risk_level = VALUES(risk_level),
                predicted_at = VALUES(predicted_at),
                features_used = VALUES(features_used)
        ''', (patient_id, adherence_score, risk_level, json.dumps(features_used)))

        # Fetch the updated record to return it
        cursor.execute('''
            SELECT ad_id, patient_id, prediction_score, risk_level, predicted_at, features_used
            FROM ai_adherence_prediction
            WHERE patient_id = %s
        ''', (patient_id,))
        new_pred = cursor.fetchone()
        conn.commit()
        cursor.close()
    return new_pred


# ----------------------------------------------------------------------
# Get patient's age and recent adherence history for AI model input
# ----------------------------------------------------------------------
def get_patient_history_for_ai(patient_id):
    """
    Prepare feature vector for AI model:
      - Calculates patient's age from date_of_birth.
      - Retrieves the last 3 adherence log statuses (TAKEN/MISSED) for this patient.
    Returns a tuple: (age, history_values) where history_values is a list of 3 floats
    (1.0 for TAKEN, 0.0 for MISSED). If no history exists, returns (age, None)
    to signal the caller to skip prediction.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)

        # Compute age from date_of_birth
        cursor.execute('''
            SELECT TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age
            FROM users WHERE user_id = %s
        ''', (patient_id,))
        age_row = cursor.fetchone()
        age = int(age_row['age']) if age_row and age_row['age'] else 65  # default 65

        # Get the 3 most recent adherence logs (only TAKEN or MISSED)
        cursor.execute('''
            SELECT al.status
            FROM adherence_logs al
            JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
            WHERE pc.patient_id = %s AND al.status IN ('TAKEN', 'MISSED')
            ORDER BY al.scheduled_time DESC LIMIT 3
        ''', (patient_id,))
        history_rows = cursor.fetchall()
        cursor.close()

    # No history at all → signal to skip prediction
    if not history_rows:
        return age, None

    # ── Minimum data guard ─────────────────────────────────────────────
    # Require at least 3 real TAKEN/MISSED records before running the model.
    # Fewer than 3 records means the AI would be predicting on fabricated
    # (padded) data, which is unreliable and misleading.
    if len(history_rows) < 3:
        print(f"[AI] Patient {patient_id} has only {len(history_rows)} adherence log(s). "
              f"Minimum 3 required for a reliable prediction.")
        return age, None

    # Convert status strings to numeric: 1.0 for TAKEN, 0.0 for MISSED
    history_vals = [1.0 if r['status'] == 'TAKEN' else 0.0 for r in history_rows]

    return age, history_vals


# ----------------------------------------------------------------------
# Get all active patients for batch processing of AI predictions
# ----------------------------------------------------------------------
def get_all_active_patients_for_batch():
    """
    Retrieve a list of all active patients (is_active = true) with their patient_id
    and date_of_birth. Used for batch prediction runs (e.g., daily cron job).
    Returns a list of dicts, filtering out any None entries.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT p.patient_id, u.date_of_birth
            FROM patient p
            INNER JOIN users u ON p.patient_id = u.user_id  -- Ensure we get valid users
            WHERE u.is_active = true
        ''')
        patients = cursor.fetchall()
        cursor.close()
    # Filter out any accidentally null records (safety)
    return [p for p in patients if p is not None]


# ----------------------------------------------------------------------
# Batch upsert multiple AI predictions
# ----------------------------------------------------------------------
def batch_upsert_predictions(predictions_data):
    """
    Insert or update multiple AI predictions in a single transaction.
    :param predictions_data: list of tuples (patient_id, score, risk_level, features_json)
    where features_json is a JSON string (or dict, but should be string).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        for pat_id, score, risk, feats in predictions_data:
            cursor.execute('''
                INSERT INTO ai_adherence_prediction (patient_id, prediction_score, risk_level, predicted_at, features_used)
                VALUES (%s, %s, %s, CURRENT_TIMESTAMP, %s)
                ON DUPLICATE KEY UPDATE
                    prediction_score = VALUES(prediction_score),
                    risk_level = VALUES(risk_level),
                    predicted_at = VALUES(predicted_at),
                    features_used = VALUES(features_used)
            ''', (pat_id, score, risk, feats))
        conn.commit()
        cursor.close()


# ----------------------------------------------------------------------
# Get patients under a caregiver who are at risk (based on AI)
# ----------------------------------------------------------------------
def get_caregiver_at_risk_patients(caregiver_id):
    """
    For a given caregiver, fetch all linked patients and their latest AI
    prediction (if available). Returns a list of dicts with patient info,
    risk level, prediction score, and medication name (first one).
    Patients without a prediction are given a default risk level 'LOW' and score 0.0.
    Ordered by prediction score descending (highest risk first).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT 
                u.user_id,
                u.full_name,
                u.date_of_birth,
                pcm.patient_id,
                aap.risk_level,
                aap.prediction_score,
                aap.predicted_at,
                (SELECT GROUP_CONCAT(DISTINCT m.medication_name SEPARATOR ', ')
                 FROM prescription_config pc
                 JOIN medications m ON pc.medication_id = m.medication_id
                 WHERE pc.patient_id = u.user_id LIMIT 1) as medication
            FROM patient_caregiver_mapping pcm
            JOIN users u ON pcm.patient_id = u.user_id
            LEFT JOIN ai_adherence_prediction aap ON u.user_id = aap.patient_id
            WHERE pcm.caregiver_id = %s
            ORDER BY aap.prediction_score DESC, u.full_name
        ''', (caregiver_id,))
        rows = cursor.fetchall()
        cursor.close()

    # Format each row into a consistent structure
    result = []
    for row in rows:
        result.append({
            "patient_id": row["patient_id"],
            "name": row["full_name"],
            "risk_level": row["risk_level"] or "LOW",    # default LOW if no prediction
            "forget_probability": float(row["prediction_score"]) if row["prediction_score"] is not None else 0.0,
            "medication": row["medication"] or "No medication",
            "temporal_pattern": "Based on latest AI analysis"   # static placeholder
        })
    return result


# ----------------------------------------------------------------------
# Delete AI prediction for a patient (used when patient is deleted)
# ----------------------------------------------------------------------
def delete_ai_prediction(patient_id):
    """
    Remove the AI prediction record for a given patient.
    Used during patient deletion cleanup.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            DELETE FROM ai_adherence_prediction WHERE patient_id = %s
        ''', (patient_id,))
        conn.commit()
        cursor.close()