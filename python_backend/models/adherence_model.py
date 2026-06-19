# adherence_model.py - Functions for tracking and analyzing medication adherence.
# Handles individual patient adherence, caregiver aggregations, chart data,
# alerts, and retake operations.

from db import get_db_connection


# ----------------------------------------------------------------------
# Get adherence statistics for a single patient (last 7 days)
# ----------------------------------------------------------------------
def get_patient_adherence_stats(patient_id):
    """
    Retrieve counts of TAKEN, MISSED, and PENDING (upcoming) doses for a patient
    over the past 7 days.
    Returns a dict with keys: taken_count, missed_count, upcoming_count.
    """
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


# ----------------------------------------------------------------------
# Get detailed adherence logs for a patient (paginated)
# ----------------------------------------------------------------------
def get_patient_adherence_logs(patient_id, limit):
    """
    Fetch the most recent adherence log entries for a patient, including
    medication name. Limited by 'limit' parameter.
    Returns a list of dicts.
    """
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


# ----------------------------------------------------------------------
# Get recent adherence logs for all patients of a caregiver
# ----------------------------------------------------------------------
def get_all_recent_logs(caregiver_id, limit):
    """
    Fetch the most recent adherence logs (with patient name and medication name)
    for all patients under a caregiver. Used for caregiver dashboard activity feed.
    """
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


# ----------------------------------------------------------------------
# Get caregiver overview stats: adherence counts, patient count, low stock, etc.
# ----------------------------------------------------------------------
def get_caregiver_overview_stats(caregiver_id):
    """
    Returns a comprehensive set of summary statistics for a caregiver's dashboard:
      - adherence counts (taken, missed, pending)
      - total active patients
      - number of low‑stock medications (prescription + device‑only)
      - total active prescriptions
      - distinct medication types in the system

    Returns: (stats_dict, total_patients, low_stock_count, total_rx, distinct_meds)
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        # 1. Adherence counts (all time, not just last 7 days)
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

        # 2. Total active patients
        cursor.execute('''
            SELECT COUNT(*) AS total_patients
            FROM patient p
            JOIN users u ON p.patient_id = u.user_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            WHERE pcm.caregiver_id = %s AND u.is_active = true
        ''', (caregiver_id,))
        total_patients = cursor.fetchone()['total_patients'] or 0

        # 3. Low‑stock count (from prescription‑linked medications)
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

        # 4. Low‑stock from device‑only medications (no active prescription for this caregiver)
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

        # 5. Total active prescriptions for this caregiver (only for active patients)
        cursor.execute('''
            SELECT COUNT(*) AS total_prescriptions
            FROM prescription_config pc
            JOIN patient p ON pc.patient_id = p.patient_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            JOIN users u ON p.patient_id = u.user_id   -- filter active patients
            WHERE pcm.caregiver_id = %s
            AND u.is_active = true
            AND (pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE)
        ''', (caregiver_id,))
        total_rx = cursor.fetchone()['total_prescriptions'] or 0

        # 6. Distinct medication names in the entire system (global)
        cursor.execute('SELECT COUNT(*) AS distinct_meds FROM medications')
        distinct_meds = cursor.fetchone()['distinct_meds'] or 0

        cursor.close()
    return stats, total_patients, low_stock_count, total_rx, distinct_meds


# ----------------------------------------------------------------------
# Get chart data for caregiver dashboard (adherence over time)
# ----------------------------------------------------------------------
def get_caregiver_chart_data(caregiver_id, period):
    """
    Return aggregated taken/missed counts for a caregiver's patients,
    grouped by period:
      - 'Day'   : by hour of the current day (0‑23)
      - 'Month' : by week (last 4 weeks)
      - 'Week'  : by day of week (1‑7) for the past 7 days (default)
    Returns a list of rows with keys: (hour|week_ago|dow), taken, missed.
    """
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
            
        else:   # default 'Week'
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


# ----------------------------------------------------------------------
# Get alerts (missed or pending doses) for a caregiver
# ----------------------------------------------------------------------
def get_caregiver_alerts(caregiver_id, limit):
    """
    Retrieve recent alerts for a caregiver: logs with status 'MISSED' or 'PENDING',
    including patient name, medication, dosage, and current inventory.
    Used for the caregiver's "recent alerts" list.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT al.adlog_id, u.full_name AS patient_name,
                med.medication_name, al.scheduled_time, al.status,
                pc.dosage_tablet,
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


# ----------------------------------------------------------------------
# Get analytics overview for a caregiver (AI risk summary)
# ----------------------------------------------------------------------
def get_caregiver_analytics_overview(caregiver_id):
    """
    Return high‑level analytics for a caregiver:
      - total active patients
      - counts of patients with HIGH, MEDIUM risk (based on latest AI prediction)
      - analysed patients count, total score sum, average prediction score

    Returns: (total_patients, stats_dict)
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        # Total active patients
        cursor.execute('''
            SELECT COUNT(*) AS total_patients
            FROM patient p
            JOIN users u ON p.patient_id = u.user_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            WHERE pcm.caregiver_id = %s AND u.is_active = true
        ''', (caregiver_id,))
        total = cursor.fetchone()['total_patients']
        
        # AI summary: latest prediction per patient (using ROW_NUMBER to get most recent)
        cursor.execute('''
            SELECT 
                COUNT(CASE WHEN a.risk_level = 'HIGH' THEN 1 END) AS high_risk_patients,
                COUNT(CASE WHEN a.risk_level = 'MEDIUM' THEN 1 END) AS medium_risk_patients,
                COUNT(a.prediction_score) AS analysed_patients,
                SUM(a.prediction_score) AS total_score,
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
                WHERE rn = 1   -- only the most recent prediction per patient
            ) a ON p.patient_id = a.patient_id
            JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
            WHERE pcm.caregiver_id = %s AND u.is_active = true
        ''', (caregiver_id,))
        stats = cursor.fetchone()
        cursor.close()
    return total, stats


# ----------------------------------------------------------------------
# Save a manual medication log (for ML training or audit)
# ----------------------------------------------------------------------
def save_medication_log(patient_id, age, day_of_week, time_of_day, status):
    """
    Insert a record into the medication_logs table (used for ML model training).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO medication_logs (patient_id, age, day_of_week, time_of_day, status)
            VALUES (%s, %s, %s, %s, %s)
        ''', (patient_id, age, day_of_week, time_of_day, status))
        conn.commit()
        cursor.close()


# ----------------------------------------------------------------------
# Get all medication logs (latest 20)
# ----------------------------------------------------------------------
def get_all_medication_logs():
    """
    Retrieve the most recent 20 entries from the medication_logs table.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('SELECT * FROM medication_logs ORDER BY timestamp DESC LIMIT 20')
        logs = cursor.fetchall()
        cursor.close()
    return logs


# ----------------------------------------------------------------------
# Retake a missed dose (update log and adjust inventory)
# ----------------------------------------------------------------------
def retake_missed_dose(adlog_id):
    """
    Allow a patient to take a missed dose within 30 minutes of the scheduled time.
    Steps:
      1. Check if the log exists and status is 'MISSED'.
      2. Verify that the current time is within 30 minutes of scheduled_time.
      3. Update the log status to 'TAKEN' and set dispensed_time to NOW().
      4. Decrease the medication inventory by the dosage_tablet for that prescription.
    Returns: (success_bool, message_string)
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        # 1. Fetch prescription_id, status, and scheduled_time
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

        # 4. Decrement inventory by the dosage (dosage_tablet from prescription_config)
        cursor.execute('''
            UPDATE medications m
            JOIN prescription_config pc ON m.medication_id = pc.medication_id
            SET m.current_inventory = m.current_inventory - pc.dosage_tablet
            WHERE pc.prescription_id = %s
        ''', (prescription_id,))

        conn.commit()
        cursor.close()
        return True, "Retake recorded successfully"