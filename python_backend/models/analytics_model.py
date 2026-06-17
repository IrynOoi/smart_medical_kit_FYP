#analytics_model.py
# from psycopg2 import cursor
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
                    VALUES (%s, %s, %s, CURRENT_TIMESTAMP, %s)
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
        cursor.close()

    # No history → signal caller to skip prediction
    if not history_rows:
        return age, None

    history_vals = [1.0 if r['status'] == 'TAKEN' else 0.0 for r in history_rows]
    while len(history_vals) < 3:
        history_vals.insert(0, 1.0)

    return age, history_vals

def get_all_active_patients_for_batch():
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT p.patient_id, u.date_of_birth
            FROM patient p
            INNER JOIN users u ON p.patient_id = u.user_id  -- 确保使用 INNER JOIN
            WHERE u.is_active = true
        ''')
        patients = cursor.fetchall()
        cursor.close()
    # 过滤掉所有可能为空的记录
    return [p for p in patients if p is not None]

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

def get_caregiver_at_risk_patients(caregiver_id):
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
    
    # Format output
    result = []
    for row in rows:
        result.append({
            "patient_id": row["patient_id"],
            "name": row["full_name"],
            "risk_level": row["risk_level"] or "LOW",
            "forget_probability": float(row["prediction_score"]) if row["prediction_score"] is not None else 0.0,
            "medication": row["medication"] or "No medication",
            "temporal_pattern": "Based on latest AI analysis"
        })
    return result

def delete_ai_prediction(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            DELETE FROM ai_adherence_prediction WHERE patient_id = %s
        ''', (patient_id,))
        conn.commit()
        cursor.close()
