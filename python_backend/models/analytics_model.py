#analytics_model.py
import json
from db import get_db_connection

def get_latest_ai_prediction(patient_id):
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

def save_hybrid_ai_prediction(patient_id, adherence_score, risk_level, features_used):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            INSERT INTO ai_adherence_prediction (patient_id, prediction_score, risk_level, predicted_at, features_used)
            VALUES (%s, %s, %s, CURRENT_TIMESTAMP, CAST(%s AS JSON))
            ON DUPLICATE KEY UPDATE
                prediction_score = VALUES(prediction_score),
                risk_level = VALUES(risk_level),
                predicted_at = VALUES(predicted_at),
                features_used = VALUES(features_used)
        ''', (patient_id, adherence_score, risk_level, json.dumps(features_used)))
        
        cursor.execute('''
            SELECT ad_id, patient_id, prediction_score, risk_level, predicted_at, features_used
            FROM ai_adherence_prediction
            WHERE patient_id = %s
        ''', (patient_id,))
        new_pred = cursor.fetchone()
        conn.commit()
        cursor.close()
    return new_pred

def get_patient_history_for_ai(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age
            FROM users WHERE user_id = %s
        ''', (patient_id,))
        age_row = cursor.fetchone()
        age = int(age_row['age']) if age_row and age_row['age'] else 65

        cursor.execute('''
            SELECT al.status
            FROM adherence_logs al
            JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
            WHERE pc.patient_id = %s AND al.status IN ('TAKEN', 'MISSED')
            ORDER BY al.scheduled_time DESC LIMIT 3
        ''', (patient_id,))
        history_rows = cursor.fetchall()
        history_vals = [1.0 if r['status'] == 'TAKEN' else 0.0 for r in history_rows]
        while len(history_vals) < 3:
            history_vals.insert(0, 1.0)
            
        cursor.close()
    return age, history_vals

def get_all_active_patients_for_batch():
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT p.patient_id, u.date_of_birth
            FROM patient p
            JOIN users u ON p.patient_id = u.user_id
            WHERE u.is_active = true
        ''')
        patients = cursor.fetchall()
        cursor.close()
    return patients

def batch_upsert_predictions(predictions_data):
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
