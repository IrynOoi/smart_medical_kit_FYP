# server.py
#backend codes

from flask import Flask, request, jsonify
from flask_cors import CORS
from flask.json.provider import DefaultJSONProvider
import numpy as np
import tensorflow as tf
import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2 import pool
import datetime
import os
from contextlib import contextmanager

class CustomJSONProvider(DefaultJSONProvider):
    def default(self, obj):
        if isinstance(obj, (datetime.datetime, datetime.date)):
            return obj.isoformat()
        return super().default(obj)

app = Flask(__name__)
app.json = CustomJSONProvider(app)
CORS(app)

# ==========================================
# 💾 Database Configuration
# ==========================================
DB_CONFIG = {
    'host': 'localhost',
    'database': 'fyp_db',
    'user': 'postgres',
    'password': '123456',
    'port': 5433
}
db_pool = pool.SimpleConnectionPool(
    1, 10,
    **DB_CONFIG
)

@contextmanager
def get_db_connection():
    conn = None
    try:
        conn = db_pool.getconn()
        yield conn
    finally:
        if conn:
            db_pool.putconn(conn)

def init_db():
    """Test database connection"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT 1')
            cursor.close()
        print("PostgreSQL connected successfully!")
    except Exception as e:
        print(f"Failed to connect to PostgreSQL: {e}")

# ==========================================
# LSTM Model Setup
# ==========================================
print("Loading LSTM model...")
model = None
try:
    if os.path.exists('smart_pill_lstm_model.h5'):
        model = tf.keras.models.load_model('smart_pill_lstm_model.h5')
        print("LSTM model loaded successfully!")
    else:
        print("Model file not found. Prediction API will use mock logic.")
except Exception as e:
    print(f"Error loading model: {e}")
    model = None

days_map = {'Monday': 0, 'Tuesday': 1, 'Wednesday': 2, 'Thursday': 3, 'Friday': 4, 'Saturday': 5, 'Sunday': 6}
times_map = {'Morning': 0, 'Afternoon': 1, 'Evening': 2}


@app.route('/caregiver/<int:caregiver_id>/all_recent_logs', methods=['GET'])
def get_all_recent_logs(caregiver_id):
    """Return all recent adherence logs (TAKEN, MISSED, PENDING) for the caregiver"""
    try:
        limit = request.args.get('limit', default=20, type=int)
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT al.adlog_id, u.full_name AS patient_name,
                       pc.medication_name, al.scheduled_time, al.status
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                JOIN patient p ON pc.patient_id = p.patient_id
                JOIN users u ON p.patient_id = u.user_id
                WHERE p.caregiver_id = %s
                ORDER BY al.scheduled_time DESC
                LIMIT %s
            ''', (caregiver_id, limit))
            logs = cursor.fetchall()
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

# ==========================================
# 🔐 AUTHENTICATION ENDPOINTS
# ==========================================

@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')

        if not email or not password:
            return jsonify({"success": False, "message": "Email and password are required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT user_id as id, email, full_name as name, role
                FROM users 
                WHERE email = %s AND password = %s AND is_active = true
            ''', (email, password))
            user = cursor.fetchone()
            cursor.close()

        if user:
            return jsonify({"success": True, "message": f"Welcome {user['name']}", "user": user})
        else:
            return jsonify({"success": False, "message": "Invalid email or password"}), 401

    except Exception as e:
        print(f"Login error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        role = data.get('role', 'patient').lower()
        email = data.get('email')
        password = data.get('password')
        name = data.get('fullname') or data.get('full_name')
        gender = data.get('gender', 'Other')
        phone = data.get('phone_no')
        dob = data.get('date_of_birth')
        address = data.get('address')

        if not email or not password or not name:
            return jsonify({"success": False, "message": "Email, password, and name are required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO users (email, password, role, full_name, phone_no, address, gender, date_of_birth)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING user_id
            ''', (email, password, role, name, phone, address, gender, dob))
            
            user_id = cursor.fetchone()[0]
            
            if role == 'caregiver':
                cursor.execute('INSERT INTO caregiver (caregiver_id) VALUES (%s)', (user_id,))
            else:
                caregiver_id = data.get('caregiver_id', 1)
                medical_notes = data.get('medical_notes')
                cursor.execute('''
                    INSERT INTO patient (patient_id, caregiver_id, medical_notes)
                    VALUES (%s, %s, %s)
                ''', (user_id, caregiver_id, medical_notes))
            
            conn.commit()
            cursor.close()

        return jsonify({"success": True, "message": f"Registration successful as {role.capitalize()}!"})

    except psycopg2.IntegrityError:
        return jsonify({"success": False, "error": "Email already exists"}), 409
    except Exception as e:
        print(f"Registration error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ==========================================
# 👤 PATIENT ENDPOINTS
# ==========================================

@app.route('/patient/<int:patient_id>', methods=['GET'])
def get_patient(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT u.user_id as patient_id, u.email, u.full_name, u.phone_no, u.address, 
                       u.gender, u.date_of_birth, u.is_active, u.created_at, u.updated_at,
                       p.caregiver_id, p.medical_notes
                FROM users u
                JOIN patient p ON u.user_id = p.patient_id
                WHERE u.user_id = %s AND u.role = 'patient'
            ''', (patient_id,))
            patient = cursor.fetchone()
            cursor.close()

        if patient:
            return jsonify({"success": True, "data": patient})
        else:
            return jsonify({"success": False, "error": "Patient not found"}), 404
    except Exception as e:
        print(f"Get patient error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/prescriptions', methods=['GET'])
def get_patient_prescriptions(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT prescription_id, patient_id, medication_name, dosage_tablet, 
                       dispense_schedule, current_inventory, refill_threshold, 
                       start_date, end_date, created_at, updated_at, device_id
                FROM prescription_config 
                WHERE patient_id = %s AND (end_date IS NULL OR end_date >= CURRENT_DATE)
                ORDER BY start_date ASC
            ''', (patient_id,))
            prescriptions = cursor.fetchall()
            cursor.close()
        return jsonify({"success": True, "data": prescriptions})
    except Exception as e:
        print(f"Get prescriptions error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/adherence_stats', methods=['GET'])
def get_adherence_stats(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT 
                    COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) as taken_count,
                    COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) as missed_count,
                    COUNT(CASE WHEN al.status = 'PENDING' THEN 1 END) as upcoming_count
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                WHERE pc.patient_id = %s 
                AND al.scheduled_time >= CURRENT_DATE - INTERVAL '7 days'
            ''', (patient_id,))
            stats = cursor.fetchone()
            cursor.close()

        taken = stats['taken_count'] or 0
        missed = stats['missed_count'] or 0
        total = taken + missed
        score = int((taken / total) * 100) if total > 0 else 100

        return jsonify({"success": True, "data": {
            "taken_count": taken, "missed_count": missed,
            "upcoming_count": stats['upcoming_count'] or 0, "adherence_score": score
        }})
    except Exception as e:
        print(f"Get adherence stats error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/adherence_logs', methods=['GET'])
def get_adherence_logs(patient_id):
    try:
        limit = request.args.get('limit', default=20, type=int)
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT al.adlog_id, al.prescription_id, al.device_id, 
                       al.scheduled_time, al.dispensed_time, al.status, al.recorded_at,
                       pc.medication_name
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                WHERE pc.patient_id = %s
                ORDER BY al.scheduled_time DESC
                LIMIT %s
            ''', (patient_id, limit))
            logs = cursor.fetchall()
            cursor.close()
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        print(f"Get adherence logs error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/notifications', methods=['GET'])
def get_notifications(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT notification_id, patient_id, title, message, is_read, created_at
                FROM notifications WHERE patient_id = %s
                ORDER BY created_at DESC LIMIT 20
            ''', (patient_id,))
            notifications = cursor.fetchall()
            cursor.close()
        return jsonify({"success": True, "data": notifications})
    except Exception as e:
        print(f"Get notifications error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/ai_prediction', methods=['GET'])
def get_ai_prediction(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT ad_id, patient_id, prediction_score, risk_level, predicted_at, features_used
                FROM ai_adherence_prediction WHERE patient_id = %s
                ORDER BY predicted_at DESC LIMIT 1
            ''', (patient_id,))
            prediction = cursor.fetchone()
            cursor.close()

        if prediction:
            return jsonify({"success": True, "data": prediction})
        else:
            return jsonify({"success": True, "data": {"prediction_score": 85.5, "risk_level": "LOW"}})
    except Exception as e:
        print(f"Get AI prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/caregiver/<int:caregiver_id>/overview_stats', methods=['GET'])
def get_caregiver_overview(caregiver_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            
    
            cursor.execute('''
                SELECT
                    COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken_count,
                    COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed_count,
                    COUNT(CASE WHEN al.status = 'PENDING' THEN 1 END) AS pending_count
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                JOIN patient p ON pc.patient_id = p.patient_id
                WHERE p.caregiver_id = %s
                  AND al.scheduled_time >= CURRENT_DATE - INTERVAL '7 days'
            ''', (caregiver_id,))
            stats = cursor.fetchone()

            # 2. 🌟 抓取真實的病患總數
            cursor.execute('''
                SELECT COUNT(*) AS total_patients
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                WHERE p.caregiver_id = %s AND u.is_active = true
            ''', (caregiver_id,))
            total_patients_data = cursor.fetchone()
            total_patients = total_patients_data['total_patients'] if total_patients_data else 0

            # 3. 抓取庫存過低的藥物數量
            cursor.execute('''
                SELECT COUNT(*) AS low_stock_count
                FROM prescription_config pc
                JOIN patient p ON pc.patient_id = p.patient_id
                WHERE p.caregiver_id = %s
                  AND pc.current_inventory <= pc.refill_threshold
            ''', (caregiver_id,))
            low = cursor.fetchone()

            # 4. 🌟 NEW: Calculate Total Active Prescriptions for this caregiver's patients
            cursor.execute('''
                SELECT COUNT(*) AS total_prescriptions
                FROM prescription_config pc
                JOIN patient p ON pc.patient_id = p.patient_id
                WHERE p.caregiver_id = %s
                  AND (pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE)
            ''', (caregiver_id,))
            rx_data = cursor.fetchone()
            total_rx = rx_data['total_prescriptions'] if rx_data else 0
            
            cursor.close()

        # 計算達成率
        total_doses = (stats['taken_count'] or 0) + (stats['missed_count'] or 0)
        adherence_score = int((stats['taken_count'] or 0) / total_doses * 100) if total_doses > 0 else 100

        return jsonify({"success": True, "data": {
            "taken_count": stats['taken_count'] or 0,
            "missed_count": stats['missed_count'] or 0,
            "pending_count": stats['pending_count'] or 0,
            "total_patients": total_patients,
            "low_stock_count": low['low_stock_count'] or 0,
            "total_doses": total_doses,
            "adherence_score": adherence_score,
            "total_prescriptions": total_rx  # 🌟 NEW: Now sending this to Flutter!
        }})
    except Exception as e:
        print(f"Get caregiver overview error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/caregiver/<int:caregiver_id>/chart_data', methods=['GET'])
def get_chart_data(caregiver_id):
    """Return taken and missed counts for each period (Day/Week/Month)"""
    try:
        period = request.args.get('period', 'Week')
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            
            if period == 'Day':
                # 4‑hour blocks today
                cursor.execute('''
                    SELECT 
                        EXTRACT(HOUR FROM al.scheduled_time) AS hour,
                        COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken,
                        COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed
                    FROM adherence_logs al
                    JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                    JOIN patient p ON pc.patient_id = p.patient_id
                    WHERE p.caregiver_id = %s 
                      AND DATE(al.scheduled_time) = CURRENT_DATE 
                      AND al.status IN ('TAKEN', 'MISSED')
                    GROUP BY hour
                    ORDER BY hour
                ''', (caregiver_id,))
                
            elif period == 'Month':
                # 4 weekly buckets over last 28 days
                cursor.execute('''
                    SELECT 
                        WIDTH_BUCKET(CURRENT_DATE - DATE(al.scheduled_time), 0, 28, 4) AS week_ago,
                        COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken,
                        COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed
                    FROM adherence_logs al
                    JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                    JOIN patient p ON pc.patient_id = p.patient_id
                    WHERE p.caregiver_id = %s 
                      AND al.scheduled_time >= CURRENT_DATE - INTERVAL '28 days'
                      AND al.status IN ('TAKEN', 'MISSED')
                    GROUP BY week_ago
                    ORDER BY week_ago
                ''', (caregiver_id,))
                
            else:  # Week
                cursor.execute('''
                    SELECT 
                        EXTRACT(ISODOW FROM al.scheduled_time) AS dow,
                        COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken,
                        COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed
                    FROM adherence_logs al
                    JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                    JOIN patient p ON pc.patient_id = p.patient_id
                    WHERE p.caregiver_id = %s 
                      AND al.scheduled_time >= CURRENT_DATE - INTERVAL '7 days'
                      AND al.status IN ('TAKEN', 'MISSED')
                    GROUP BY dow
                    ORDER BY dow
                ''', (caregiver_id,))

            rows = cursor.fetchall()
            cursor.close()

        # Build arrays (default zero for all periods)
        if period == 'Week':
            taken = [0.0] * 7
            missed = [0.0] * 7
            for row in rows:
                idx = int(row['dow']) - 1
                if 0 <= idx < 7:
                    taken[idx] = float(row['taken'])
                    missed[idx] = float(row['missed'])
        elif period == 'Month':
            taken = [0.0] * 4
            missed = [0.0] * 4
            for row in rows:
                w = int(row['week_ago'])
                if 1 <= w <= 4:
                    taken[4-w] = float(row['taken'])
                    missed[4-w] = float(row['missed'])
        else:  # Day
            taken = [0.0] * 6
            missed = [0.0] * 6
            for row in rows:
                hour = int(row['hour'])
                idx = hour // 4
                if 0 <= idx < 6:
                    taken[idx] += float(row['taken'])
                    missed[idx] += float(row['missed'])

        return jsonify({"success": True, "data": {"taken": taken, "missed": missed}})
        
    except Exception as e:
        print(f"Chart Data Error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

        
@app.route('/caregiver/<int:caregiver_id>/recent_alerts', methods=['GET'])
def get_caregiver_alerts(caregiver_id):
    try:
        # 🌟 支援 limit 參數，讓 Details Page 可以載入更多警告紀錄
        limit = request.args.get('limit', default=20, type=int)
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT al.adlog_id, u.full_name AS patient_name,
                       pc.medication_name, al.scheduled_time, al.status
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                JOIN patient p ON pc.patient_id = p.patient_id
                JOIN users u ON p.patient_id = u.user_id
                WHERE p.caregiver_id = %s
                  AND al.status IN ('MISSED', 'PENDING')
                ORDER BY al.scheduled_time DESC
                LIMIT %s
            ''', (caregiver_id, limit))
            alerts = cursor.fetchall()
            cursor.close()
        return jsonify({"success": True, "data": alerts})
    except Exception as e:
        print(f"Get caregiver alerts error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500



@app.route('/caregiver/<int:caregiver_id>/patients', methods=['GET'])
def get_caregiver_patients(caregiver_id):
    """Get all patients under this caregiver"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT u.user_id as patient_id, u.full_name, u.date_of_birth, u.gender,
                       u.phone_no, u.address, p.medical_notes,
                       d.battery_level, d.device_serial, d.last_active_timestamp
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                LEFT JOIN iot_device d ON d.patient_id = p.patient_id
                WHERE p.caregiver_id = %s AND u.is_active = true
                ORDER BY u.full_name ASC
            ''', (caregiver_id,))
            patients = cursor.fetchall()
            cursor.close()
        return jsonify({"success": True, "data": patients})
    except Exception as e:
        print(f"Error in get_caregiver_patients: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/caregiver/<int:caregiver_id>', methods=['GET'])
def get_caregiver_profile(caregiver_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT u.user_id as caregiver_id, u.email, u.full_name, u.phone_no, u.address, 
                       u.gender, u.date_of_birth, u.is_active, u.created_at, u.updated_at
                FROM users u
                JOIN caregiver c ON u.user_id = c.caregiver_id
                WHERE u.user_id = %s AND u.role = 'caregiver'
            ''', (caregiver_id,))
            caregiver = cursor.fetchone()
            cursor.close()

        if caregiver:
            return jsonify({"success": True, "data": caregiver})
        else:
            return jsonify({"success": False, "error": "Caregiver not found"}), 404
    except Exception as e:
        print(f"Get caregiver profile error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ==========================================
# ✏️ UPDATE PROFILE ENDPOINTS
# ==========================================

@app.route('/update_patient/<int:patient_id>', methods=['PUT'])
def update_patient(patient_id):
    """Update patient profile"""
    try:
        data = request.get_json()
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE users 
                SET full_name = %s, 
                    phone_no = %s, 
                    address = %s, 
                    email = %s, 
                    gender = %s, 
                    date_of_birth = %s,
                    updated_at = CURRENT_TIMESTAMP
                WHERE user_id = %s AND role = 'patient'
            ''', (
                data.get('full_name'), 
                data.get('phone_no'), 
                data.get('address'), 
                data.get('email'),
                data.get('gender'),
                data.get('date_of_birth'),
                patient_id
            ))
            cursor.execute('''
                UPDATE patient 
                SET medical_notes = %s
                WHERE patient_id = %s
            ''', (data.get('medical_notes'), patient_id))
            conn.commit()
            cursor.close()
        return jsonify({"success": True, "message": "Profile updated successfully"})
    except Exception as e:
        print(f"Update patient error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/update_caregiver/<int:caregiver_id>', methods=['PUT'])
def update_caregiver(caregiver_id):
    """Update caregiver profile"""
    try:
        data = request.get_json()
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE users 
                SET full_name = %s, 
                    phone_no = %s, 
                    address = %s, 
                    email = %s, 
                    gender = %s, 
                    date_of_birth = %s,
                    updated_at = CURRENT_TIMESTAMP
                WHERE user_id = %s AND role = 'caregiver'
            ''', (
                data.get('full_name'), 
                data.get('phone_no'), 
                data.get('address'), 
                data.get('email'),
                data.get('gender'),
                data.get('date_of_birth'),
                caregiver_id
            ))
            conn.commit()
            cursor.close()
        return jsonify({"success": True, "message": "Profile updated successfully"})
    except Exception as e:
        print(f"Update caregiver error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ==========================================
# 💊 MEDICATION ENDPOINTS
# ==========================================

@app.route('/record_medication', methods=['POST'])
def record_medication():
    try:
        data = request.get_json()
        prescription_id = data.get('prescription_id')
        device_id = data.get('device_id')

        if not prescription_id or not device_id:
            return jsonify({"success": False, "message": "prescription_id and device_id are required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE adherence_logs 
                SET status = 'TAKEN', dispensed_time = CURRENT_TIMESTAMP, recorded_at = CURRENT_TIMESTAMP
                WHERE prescription_id = %s AND device_id = %s AND status = 'PENDING'
                  AND DATE(scheduled_time) = CURRENT_DATE
            ''', (prescription_id, device_id))

            cursor.execute('''
                UPDATE prescription_config 
                SET current_inventory = current_inventory - 1, updated_at = CURRENT_TIMESTAMP
                WHERE prescription_id = %s AND current_inventory > 0
            ''', (prescription_id,))
            conn.commit()
            cursor.close()

        return jsonify({"success": True, "message": "Medication recorded successfully!"})
    except Exception as e:
        print(f"Record medication error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ==========================================
# 📋 PRESCRIPTION SETUP ENDPOINTS
# ==========================================

@app.route('/add_prescription', methods=['POST'])
def add_prescription():
    """Create a new prescription config and return it for the setup page"""
    try:
        data = request.get_json()
        
        # Extract required fields from the frontend request
        patient_id = data.get('patient_id')
        medication_name = data.get('medication_name')
        dosage_tablet = data.get('dosage_tablet')
        dispense_schedule = data.get('dispense_schedule')  # e.g., '0 8 * * *'
        current_inventory = data.get('current_inventory', 0)
        refill_threshold = data.get('refill_threshold', 5)
        start_date = data.get('start_date') 
        device_id = data.get('device_id') # Can be None/null if not assigned yet

        # Basic validation
        if not all([patient_id, medication_name, dosage_tablet, dispense_schedule, start_date]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            
            # Insert and return the full row so the frontend can display it immediately
            cursor.execute('''
                INSERT INTO prescription_config 
                (patient_id, medication_name, dosage_tablet, dispense_schedule, current_inventory, refill_threshold, start_date, device_id)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING prescription_id, patient_id, medication_name, dosage_tablet, 
                          dispense_schedule, current_inventory, refill_threshold, 
                          start_date, end_date, created_at, updated_at, device_id
            ''', (patient_id, medication_name, dosage_tablet, dispense_schedule, current_inventory, refill_threshold, start_date, device_id))
            
            new_prescription = cursor.fetchone()
            conn.commit()
            cursor.close()

        return jsonify({
            "success": True, 
            "message": "Prescription created successfully!", 
            "data": new_prescription
        })
        
    except Exception as e:
        print(f"Add prescription error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/prescription/<int:prescription_id>', methods=['GET'])
def get_prescription_details(prescription_id):
    """View details of a specific prescription setup"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT prescription_id, patient_id, medication_name, dosage_tablet, 
                       dispense_schedule, current_inventory, refill_threshold, 
                       start_date, end_date, created_at, updated_at, device_id
                FROM prescription_config
                WHERE prescription_id = %s
            ''', (prescription_id,))
            prescription = cursor.fetchone()
            cursor.close()

        if prescription:
            return jsonify({"success": True, "data": prescription})
        else:
            return jsonify({"success": False, "error": "Prescription not found"}), 404
            
    except Exception as e:
        print(f"Get prescription details error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/predict', methods=['POST'])
def predict_forgetfulness():
    try:
        data = request.get_json()
        age = data.get('age')
        day = days_map.get(data.get('day_of_week', 'Monday'), 0)
        time = times_map.get(data.get('time_of_day', 'Morning'), 0)
        history = data.get('history', [1, 1, 1])

        if model is None:
            forget_prob = 0.35
        else:
            input_data = []
            for past_status in history[-3:]:
                feature_row = [age / 100.0, day / 6.0, time / 2.0, float(past_status)]
                input_data.append(feature_row)
            while len(input_data) < 3:
                input_data.insert(0, [age / 100.0, day / 6.0, time / 2.0, 1.0])
            input_array = np.array([input_data])
            prediction = model.predict(input_array)
            forget_prob = float(prediction[0][0])

        warning_level = "HIGH" if forget_prob > 0.6 else "MEDIUM" if forget_prob > 0.3 else "LOW"
        message = "High chance of forgetting medication. Send reminder!" if forget_prob > 0.6 else \
                  "Moderate risk. Monitor patient carefully." if forget_prob > 0.3 else \
                  "Patient adherence is stable."

        return jsonify({"success": True, "forget_probability": round(forget_prob, 2), 
                       "warning_level": warning_level, "message": message})
    except Exception as e:
        print(f"Prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/add_log', methods=['POST'])
def add_log():
    try:
        data = request.get_json()
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO medication_logs (patient_id, age, day_of_week, time_of_day, status)
                VALUES (%s, %s, %s, %s, %s)
            ''', (data['patient_id'], data['age'], data['day_of_week'], data['time_of_day'], data['status']))
            conn.commit()
            cursor.close()
        return jsonify({"success": True, "message": "Log saved successfully!"})
    except Exception as e:
        print(f"Add log error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/get_logs', methods=['GET'])
def get_logs():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('SELECT * FROM medication_logs ORDER BY timestamp DESC LIMIT 20')
            logs = cursor.fetchall()
            cursor.close()
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        print(f"Get logs error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/notification/<int:notification_id>/read', methods=['PUT'])
def mark_notification_read(notification_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('UPDATE notifications SET is_read = TRUE WHERE notification_id = %s', (notification_id,))
            conn.commit()
            cursor.close()
        return jsonify({"success": True, "message": "Notification marked as read"})
    except Exception as e:
        print(f"Mark notification read error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    try:
        with get_db_connection() as conn:
            conn.close()
        db_status = "connected"
    except:
        db_status = "disconnected"
    return jsonify({"status": "healthy", "database": db_status, "model": "loaded" if model else "not loaded"})


# ==========================================
# 🚀 Run the Flask App
# ==========================================
if __name__ == '__main__':
    init_db()
    print("\n" + "="*50)
    print("IoT-Based Smart Medical Kit API Server")
    print("="*50)
    print(f"Server running on: http://0.0.0.0:5000")
    print("="*50 + "\n")
    app.run(host='0.0.0.0', port=5000, debug=True, use_reloader=False)
 