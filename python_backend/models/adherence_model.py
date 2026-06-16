#adherence_model.py
from db import get_db_connection

def get_patient_adherence_stats(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT 
                COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) as taken_count,
                COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) as missed_count,
                COUNT(CASE WHEN al.status = 'PENDING' THEN 1 END) as upcoming_count
            FROM adherence_logs al
            JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
            WHERE pc.patient_id = %s 
            AND al.scheduled_time >= CURRENT_DATE - INTERVAL 7 DAY
        ''', (patient_id,))
        stats = cursor.fetchone()
        cursor.close()
    return stats

def get_patient_adherence_logs(patient_id, limit):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT al.adlog_id, al.prescription_id, al.device_id, 
                   al.scheduled_time, al.dispensed_time, al.status, al.recorded_at,
                   m.medication_name
            FROM adherence_logs al
            JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
            JOIN medications m ON pc.medication_id = m.medication_id
            WHERE pc.patient_id = %s
            ORDER BY al.scheduled_time DESC
            LIMIT %s
        ''', (patient_id, limit))
        logs = cursor.fetchall()
        cursor.close()
    return logs

def get_all_recent_logs(caregiver_id, limit):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT al.adlog_id, u.full_name AS patient_name,
                   m.medication_name, al.scheduled_time, al.status
            FROM adherence_logs al
            JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
            JOIN medications m ON pc.medication_id = m.medication_id
            JOIN patient p ON pc.patient_id = p.patient_id
            JOIN users u ON p.patient_id = u.user_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            WHERE pcm.caregiver_id = %s
            ORDER BY al.scheduled_time DESC
            LIMIT %s
        ''', (caregiver_id, limit))
        logs = cursor.fetchall()
        cursor.close()
    return logs

def get_caregiver_overview_stats(caregiver_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute('''
            SELECT
                COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken_count,
                COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed_count,
                COUNT(CASE WHEN al.status = 'PENDING' THEN 1 END) AS pending_count
            FROM adherence_logs al
            JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
            JOIN patient p ON pc.patient_id = p.patient_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            WHERE pcm.caregiver_id = %s
        ''', (caregiver_id,))
        stats = cursor.fetchone()

        cursor.execute('''
            SELECT COUNT(*) AS total_patients
            FROM patient p
            JOIN users u ON p.patient_id = u.user_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            WHERE pcm.caregiver_id = %s AND u.is_active = true
        ''', (caregiver_id,))
        total_patients = cursor.fetchone()['total_patients'] or 0

        cursor.execute('''
            SELECT COUNT(*) AS low_stock_count
            FROM prescription_config pc
            JOIN medications m ON pc.medication_id = m.medication_id
            JOIN patient p ON pc.patient_id = p.patient_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            WHERE pcm.caregiver_id = %s
              AND m.current_inventory <= m.refill_threshold
        ''', (caregiver_id,))
        low = cursor.fetchone()
        low_stock_count = low['low_stock_count'] or 0

        cursor.execute('''
            SELECT COUNT(DISTINCT m.medication_id) AS low_stock_count
            FROM medications m
            JOIN (
                SELECT DISTINCT pcm.caregiver_id, med.device_id
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                JOIN prescription_config pc ON p.patient_id = pc.patient_id
                JOIN medications med ON pc.medication_id = med.medication_id
                JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
                WHERE pcm.caregiver_id = %s
                  AND u.is_active = TRUE
                  AND med.device_id IS NOT NULL
                  AND (pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE)
            ) dc ON dc.device_id = m.device_id
            WHERE m.current_inventory <= m.refill_threshold
              AND NOT EXISTS (
                  SELECT 1
                  FROM prescription_config pc2
                  JOIN patient p2 ON pc2.patient_id = p2.patient_id
                  JOIN patient_caregiver_mapping pcm2 ON p2.patient_id = pcm2.patient_id
                  WHERE pc2.medication_id = m.medication_id
                    AND pcm2.caregiver_id = dc.caregiver_id
                    AND (pc2.end_date IS NULL OR pc2.end_date >= CURRENT_DATE)
              )
        ''', (caregiver_id,))
        device_low = cursor.fetchone()
        low_stock_count += device_low['low_stock_count'] or 0

        cursor.execute('''
                    SELECT COUNT(*) AS total_prescriptions
                    FROM prescription_config pc
                    JOIN patient p ON pc.patient_id = p.patient_id
                    JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
                    JOIN users u ON p.patient_id = u.user_id   -- 🌟 1. 链接 users 表
                    WHERE pcm.caregiver_id = %s
                    AND u.is_active = true                   -- 🌟 2. 确保只计算活跃的病患
                    AND (pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE)
                ''', (caregiver_id,))
        total_rx = cursor.fetchone()['total_prescriptions'] or 0

        cursor.execute('SELECT COUNT(*) AS distinct_meds FROM medications')
        distinct_meds = cursor.fetchone()['distinct_meds'] or 0

        cursor.close()
    return stats, total_patients, low_stock_count, total_rx, distinct_meds

def get_caregiver_chart_data(caregiver_id, period):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        if period == 'Day':
            cursor.execute('''
                SELECT 
                    EXTRACT(HOUR FROM al.scheduled_time) AS hour,
                    COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken,
                    COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                JOIN patient p ON pc.patient_id = p.patient_id
                JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
                WHERE pcm.caregiver_id = %s 
                  AND DATE(al.scheduled_time) = CURRENT_DATE 
                  AND al.status IN ('TAKEN', 'MISSED')
                GROUP BY hour
                ORDER BY hour
            ''', (caregiver_id,))
            
        elif period == 'Month':
            cursor.execute('''
                SELECT 
                    CEIL(DATEDIFF(CURDATE(), DATE(al.scheduled_time)) / 7) AS week_ago,
                    COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken,
                    COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                JOIN patient p ON pc.patient_id = p.patient_id
                JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
                WHERE pcm.caregiver_id = %s 
                  AND al.scheduled_time >= CURRENT_DATE - INTERVAL 28 DAY
                  AND al.status IN ('TAKEN', 'MISSED')
                GROUP BY week_ago
                ORDER BY week_ago
            ''', (caregiver_id,))
            
        else:
            cursor.execute('''
                SELECT 
                    (WEEKDAY(al.scheduled_time) + 1) AS dow,
                    COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken,
                    COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                JOIN patient p ON pc.patient_id = p.patient_id
                JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
                WHERE pcm.caregiver_id = %s 
                  AND al.scheduled_time >= CURRENT_DATE - INTERVAL 7 DAY
                  AND al.status IN ('TAKEN', 'MISSED')
                GROUP BY dow
                ORDER BY dow
            ''', (caregiver_id,))

        rows = cursor.fetchall()
        cursor.close()
    return rows

def get_caregiver_alerts(caregiver_id, limit):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT al.adlog_id, u.full_name AS patient_name,
                med.medication_name, al.scheduled_time, al.status,
                pc.dosage_tablet, pc.dispense_schedule,
                med.current_inventory
            FROM adherence_logs al
            JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
            JOIN medications med ON pc.medication_id = med.medication_id
            JOIN patient p ON pc.patient_id = p.patient_id
            JOIN users u ON p.patient_id = u.user_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            WHERE pcm.caregiver_id = %s
            AND al.status IN ('MISSED', 'PENDING')
            ORDER BY al.scheduled_time DESC
            LIMIT %s
        ''', (caregiver_id, limit))
        alerts = cursor.fetchall()
        cursor.close()
    return alerts

def get_caregiver_analytics_overview(caregiver_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute('''
            SELECT COUNT(*) AS total_patients
            FROM patient p
            JOIN users u ON p.patient_id = u.user_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            WHERE pcm.caregiver_id = %s AND u.is_active = true
        ''', (caregiver_id,))
        total = cursor.fetchone()['total_patients']
        
        cursor.execute('''
            SELECT 
                COUNT(CASE WHEN a.risk_level = 'HIGH' THEN 1 END) AS high_risk_patients,
                COUNT(CASE WHEN a.risk_level = 'MEDIUM' THEN 1 END) AS medium_risk_patients,
                AVG(a.prediction_score) AS avg_prediction_score
            FROM patient p
            JOIN users u ON p.patient_id = u.user_id
            LEFT JOIN (
                SELECT patient_id, risk_level, prediction_score
                FROM (
                    SELECT patient_id, risk_level, prediction_score,
                           ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY predicted_at DESC) as rn
                    FROM ai_adherence_prediction
                ) ranked
                WHERE rn = 1
            ) a ON p.patient_id = a.patient_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            WHERE pcm.caregiver_id = %s AND u.is_active = true
        ''', (caregiver_id,))
        stats = cursor.fetchone()
        cursor.close()
    return total, stats

def save_medication_log(patient_id, age, day_of_week, time_of_day, status):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO medication_logs (patient_id, age, day_of_week, time_of_day, status)
            VALUES (%s, %s, %s, %s, %s)
        ''', (patient_id, age, day_of_week, time_of_day, status))
        conn.commit()
        cursor.close()

def get_all_medication_logs():
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('SELECT * FROM medication_logs ORDER BY timestamp DESC LIMIT 20')
        logs = cursor.fetchall()
        cursor.close()
    return logs

def retake_missed_dose(adlog_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        # 1. Get prescription_id, status, and scheduled_time
        cursor.execute('''
            SELECT prescription_id, status, scheduled_time
            FROM adherence_logs
            WHERE adlog_id = %s
        ''', (adlog_id,))
        row = cursor.fetchone()
        if not row:
            return False, "Log not found"
        if row['status'] != 'MISSED':
            return False, "Log not found or already taken"

        scheduled_time = row['scheduled_time']

        # 2. Check retake window: 30 minutes after scheduled_time
        cursor.execute('''
            SELECT CASE 
                WHEN NOW() <= DATE_ADD(%s, INTERVAL 30 MINUTE) THEN 1 
                ELSE 0 
            END AS within_window
        ''', (scheduled_time,))
        within = cursor.fetchone()['within_window']
        if not within:
            return False, "Retake window expired (30 minutes after scheduled time)"

        prescription_id = row['prescription_id']

        # 3. Update the log to TAKEN
        cursor.execute('''
            UPDATE adherence_logs
            SET status = 'TAKEN', dispensed_time = NOW(), recorded_at = NOW()
            WHERE adlog_id = %s
        ''', (adlog_id,))

        # 4. Decrement inventory by the prescribed dosage
        cursor.execute('''
            UPDATE medications m
            JOIN prescription_config pc ON m.medication_id = pc.medication_id
            SET m.current_inventory = m.current_inventory - pc.dosage_tablet
            WHERE pc.prescription_id = %s
        ''', (prescription_id,))

        conn.commit()
        cursor.close()
        return True, "Retake recorded successfully"