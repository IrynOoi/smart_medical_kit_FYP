# server.py
#backend codes
from flask.json import provider
import json 
import joblib # <--- Add this impor
from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
from flask_cors import CORS
from flask.json.provider import DefaultJSONProvider
import numpy as np
import tensorflow as tf

import mysql.connector # type: ignore
from mysql.connector.pooling import MySQLConnectionPool # type: ignore

import datetime
import os
import secrets
from datetime import timedelta 


from contextlib import contextmanager

import decimal

class CustomJSONProvider(DefaultJSONProvider):
    def default(self, obj):
        if isinstance(obj, (datetime.datetime, datetime.date)):
            return obj.isoformat()
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

app = Flask(__name__)
app.json = CustomJSONProvider(app)
CORS(app)

# ==========================================
# 💾 Database Configuration (MySQL)
# ==========================================
DB_CONFIG = {
    'host': 'servernew.syokdc.com', # Use 'localhost' if server.py is hosted on the same cPanel server
    'database': 'mytrusth_medsmart_db',
    'user': 'mytrusth',
    'password': '[-q7N5Gx9L3yEd',
    'port': 3306
}

# Create a connection pool for MySQL
db_pool = mysql.connector.pooling.MySQLConnectionPool(
    pool_name="mypool",
    pool_size=10,
    **DB_CONFIG
)

@contextmanager
def get_db_connection():
    conn = None
    try:
        conn = db_pool.get_connection()
        yield conn
    except Exception as e:
        if conn:
            conn.rollback()
        raise e
    finally:
        if conn and conn.is_connected():
            conn.close() # In mysql-connector, close() returns it to the pool
def init_db():
    """Test database connection"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT 1')
            cursor.fetchone()  # 🌟 关键修复：把结果读取出来，解决 "Unread result found" 报错
            cursor.close()
        print("✅ MySQL (cPanel) connected successfully!") # 把名字改对，不再自己吓自己
    except Exception as e:
        print(f"❌ Failed to connect to MySQL: {e}")


# ==========================================
# HYBRID AI Model Setup (LSTM + Random Forest)
# ==========================================
print("Loading Hybrid AI Models...")
lstm_model = None
rf_model = None
try:
    if os.path.exists('smart_pill_lstm_model.h5') and os.path.exists('smart_pill_rf_model.pkl'):
        lstm_model = tf.keras.models.load_model('smart_pill_lstm_model.h5')
        rf_model = joblib.load('smart_pill_rf_model.pkl')
        print("✅ Hybrid AI Models (LSTM & Random Forest) loaded successfully!")
    else:
        print("⚠️ Model files not found. Prediction API will use mock logic.")
except Exception as e:
    print(f"Error loading models: {e}")

days_map = {'Monday': 0, 'Tuesday': 1, 'Wednesday': 2, 'Thursday': 3, 'Friday': 4, 'Saturday': 5, 'Sunday': 6}
times_map = {'Morning': 0, 'Afternoon': 1, 'Evening': 2}


@app.route('/caregiver/<int:caregiver_id>/all_recent_logs', methods=['GET'])
def get_all_recent_logs(caregiver_id):
    """Return all recent adherence logs (TAKEN, MISSED, PENDING) for the caregiver"""
    try:
        limit = request.args.get('limit', default=20, type=int)
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

# 1. 在你的路由代码上方加入这个清洗函数
def clean_string(s):
    """清除 IoT 硬件传来的不可见字符 0x00"""
    if isinstance(s, str):
        return s.replace('\x00', '').replace('\u0000', '')
    return s
# 2. 修改你的 /login 接口
@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        
        # 【关键修复】清洗前端或硬件传来的字符串
        email = clean_string(data.get('email'))
        password = clean_string(data.get('password'))

        if not email or not password:
            return jsonify({"success": False, "message": "Email and password are required"}), 400

        with get_db_connection() as conn:
            # ✅ CHANGED: MySQL syntax for dictionary cursor
            cursor = conn.cursor(dictionary=True) 
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
            
            user_id = cursor.lastrowid
            
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

    except mysql.connector.errors.IntegrityError:
        return jsonify({"success": False, "error": "Email already exists"}), 409
    except Exception as e:
        print(f"Registration error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500



@app.route('/reset_password', methods=['POST'])
def reset_password():
    try:
        data = request.get_json()
        
        # Clean strings to prevent hidden characters from IoT devices
        email = clean_string(data.get('email'))
        new_password = clean_string(data.get('new_password'))

        if not email or not new_password:
            return jsonify({"success": False, "message": "Email and new password are required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # First, check if the email exists
            cursor.execute('SELECT user_id FROM users WHERE email = %s', (email,))
            user = cursor.fetchone()

            if not user:
                cursor.close()
                return jsonify({"success": False, "message": "Email not found"}), 404

            # Update to the new password
            cursor.execute('''
                UPDATE users 
                SET password = %s, updated_at = CURRENT_TIMESTAMP 
                WHERE email = %s
            ''', (new_password, email))
            
            conn.commit()
            cursor.close()

        return jsonify({"success": True, "message": "Password reset successfully!"})
        
    except Exception as e:
        print(f"Reset password error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
# ==========================================
# 👤 PATIENT ENDPOINTS
# ==========================================

@app.route('/patient/<int:patient_id>', methods=['GET'])
def get_patient(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT 
                    p.patient_id, p.caregiver_id, p.medical_notes,
                    u.user_id, u.email, u.full_name, u.phone_no, u.address,
                    u.gender, u.date_of_birth, u.is_active, u.created_at, u.updated_at, u.profile_photo,
                    c.caregiver_id AS cg_id, cu.full_name AS cg_full_name, cu.email AS cg_email,
                    cu.phone_no AS cg_phone_no, cu.address AS cg_address, cu.gender AS cg_gender,
                    cu.date_of_birth AS cg_date_of_birth, cu.is_active AS cg_is_active,
                    cu.created_at AS cg_created_at, cu.updated_at AS cg_updated_at, cu.profile_photo AS cg_profile_photo
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                LEFT JOIN caregiver c ON p.caregiver_id = c.caregiver_id
                LEFT JOIN users cu ON c.caregiver_id = cu.user_id
                WHERE p.patient_id = %s AND u.role = 'patient'
            ''', (patient_id,))
            row = cursor.fetchone()
            cursor.close()

        if row:
            patient_data = {
                "patient_id": row["patient_id"],
                "caregiver_id": row["caregiver_id"],
                "medical_notes": row["medical_notes"],
                "user": {
                    "user_id": row["user_id"],
                    "email": row["email"],
                    "full_name": row["full_name"],
                    "phone_no": row["phone_no"],
                    "address": row["address"],
                    "gender": row["gender"],
                    "date_of_birth": row["date_of_birth"],
                    "is_active": row["is_active"],
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                    "profile_photo": row["profile_photo"]
                }
            }
            # 构建照顾者信息（如果存在）
            if row["cg_id"] is not None:
                patient_data["caregiver"] = {
                    "caregiver_id": row["cg_id"],
                    "user": {
                        "user_id": row["cg_id"],
                        "email": row["cg_email"],
                        "full_name": row["cg_full_name"],
                        "phone_no": row["cg_phone_no"],
                        "address": row["cg_address"],
                        "gender": row["cg_gender"],
                        "date_of_birth": row["cg_date_of_birth"],
                        "is_active": row["cg_is_active"],
                        "created_at": row["cg_created_at"],
                        "updated_at": row["cg_updated_at"],
                        "profile_photo": row["cg_profile_photo"]
                    }
                }
            else:
                patient_data["caregiver"] = None

            return jsonify({"success": True, "data": patient_data})
        else:
            return jsonify({"success": False, "error": "Patient not found"}), 404
    except Exception as e:
        print(f"Get patient error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/patient/<int:patient_id>/prescriptions', methods=['GET'])
def get_patient_prescriptions(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
    SELECT pc.prescription_id, pc.patient_id, m.medication_name,
           pc.dosage_tablet, pc.dispense_schedule,
           m.current_inventory, m.refill_threshold,
           pc.start_date, pc.end_date,
           pc.created_at, pc.updated_at,
           m.device_id, m.motor_slot
    FROM prescription_config pc
    JOIN medications m ON pc.medication_id = m.medication_id
    WHERE pc.patient_id = %s 
      AND (pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE)
    ORDER BY pc.start_date ASC
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
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        print(f"Get adherence logs error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/notifications', methods=['GET'])
def get_notifications(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
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
    """
    Fetch the LATEST existing prediction from PostgreSQL without recalculating.
    """
    try:
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
            
        if prediction:
            return jsonify({
                "success": True,
                "data": prediction
            })
        else:
            return jsonify({
                "success": False, 
                "error": "No prediction found in database for this patient"
            }), 404
            
    except Exception as e:
        print(f"Get AI prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500





@app.route('/caregiver/<int:caregiver_id>/overview_stats', methods=['GET'])
def get_caregiver_overview(caregiver_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            
            # 👇 REMOVED THE 7-DAY INTERVAL FILTER 👇
            cursor.execute('''
                SELECT
                    COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken_count,
                    COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed_count,
                    COUNT(CASE WHEN al.status = 'PENDING' THEN 1 END) AS pending_count
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                JOIN patient p ON pc.patient_id = p.patient_id
                WHERE p.caregiver_id = %s
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
    JOIN medications m ON pc.medication_id = m.medication_id
    JOIN patient p ON pc.patient_id = p.patient_id
    WHERE p.caregiver_id = %s
      AND m.current_inventory <= m.refill_threshold
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

            # Inside get_caregiver_overview, after the `rx_data` query, add:
            cursor.execute('SELECT COUNT(*) AS distinct_meds FROM medications')
            distinct_meds = cursor.fetchone()['distinct_meds'] or 0



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
            "total_prescriptions": total_rx,  # 🌟 NEW: Now sending this to Flutter!
            "distinct_medications": distinct_meds
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
            cursor = conn.cursor(dictionary=True)
            
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
                        CEIL(DATEDIFF(CURDATE(), DATE(al.scheduled_time)) / 7) AS week_ago,
                        COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken,
                        COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed
                    FROM adherence_logs al
                    JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                    JOIN patient p ON pc.patient_id = p.patient_id
                    WHERE p.caregiver_id = %s 
                      AND al.scheduled_time >= CURRENT_DATE - INTERVAL 28 DAY
                      AND al.status IN ('TAKEN', 'MISSED')
                    GROUP BY week_ago
                    ORDER BY week_ago
                ''', (caregiver_id,))
                
            else:  # Week
                cursor.execute('''
                    SELECT 
                        (WEEKDAY(al.scheduled_time) + 1) AS dow,
                        COUNT(CASE WHEN al.status = 'TAKEN' THEN 1 END) AS taken,
                        COUNT(CASE WHEN al.status = 'MISSED' THEN 1 END) AS missed
                    FROM adherence_logs al
                    JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                    JOIN patient p ON pc.patient_id = p.patient_id
                    WHERE p.caregiver_id = %s 
                      AND al.scheduled_time >= CURRENT_DATE - INTERVAL 7 DAY
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
        limit = request.args.get('limit', default=20, type=int)
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



def compute_prediction_for_patient(patient_id):
    """
    Compute HYBRID prediction using LSTM and Random Forest, store in DB.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)

        # 1. Get patient age
        cursor.execute('''
            SELECT TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age
            FROM users WHERE user_id = %s
        ''', (patient_id,))
        age_row = cursor.fetchone()
        age = int(age_row['age']) if age_row and age_row['age'] else 65

        # 2. Get last 3 adherence statuses
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

            print(f"\n🔮 Hybrid AI Prediction for patient {patient_id}:")
            print(f"   LSTM voted: {lstm_forget_prob*100:.1f}% risk")
            print(f"   RF voted:   {rf_forget_prob*100:.1f}% risk")
            print(f"   Final Risk: {forget_prob*100:.1f}%")

        # 5. Convert to adherence score and risk level
        adherence_score = round((1 - forget_prob) * 100, 2)
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
        return new_pred

@app.route('/caregiver/<int:caregiver_id>/patients', methods=['GET'])
def get_caregiver_patients(caregiver_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                WITH RankedPatients AS (
                    SELECT 
                        u.user_id as patient_id,
                        u.email,
                        u.full_name,
                        u.date_of_birth,
                        u.gender,
                        u.phone_no,
                        u.address,
                        p.medical_notes,
                        u.profile_photo,
                        d.device_id,
                        d.last_reported_battery AS battery_level,
                        d.device_serial,
                        d.last_battery_report AS last_active_timestamp,
                        d.last_known_ip,
                        m.current_inventory AS inventory,
                        m.refill_threshold AS refill_threshold,
                        ROW_NUMBER() OVER (PARTITION BY p.patient_id ORDER BY pc.created_at DESC) as rn
                    FROM patient p
                    JOIN users u ON p.patient_id = u.user_id
                    LEFT JOIN prescription_config pc ON pc.patient_id = p.patient_id
                    LEFT JOIN medications m ON pc.medication_id = m.medication_id
                    LEFT JOIN iot_device d ON m.device_id = d.device_id
                    WHERE p.caregiver_id = %s AND u.is_active = true
                )
                SELECT patient_id, email, full_name, date_of_birth, gender, phone_no, address,
                       medical_notes, profile_photo, device_id, battery_level, device_serial,
                       last_active_timestamp, last_known_ip, inventory, refill_threshold
                FROM RankedPatients WHERE rn = 1
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
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT u.user_id as caregiver_id, u.email, u.full_name, u.phone_no, u.address, 
                       u.gender, u.date_of_birth, u.is_active, u.created_at, u.updated_at,u.profile_photo
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
    """Update patient profile with Multipart Form Data"""
    try:
        # CRITICAL FIX: Use request.form instead of request.get_json()
        # request.form reads text fields from a multipart/form-data request
        full_name = request.form.get('full_name')
        phone_no = request.form.get('phone_no')
        address = request.form.get('address')
        email = request.form.get('email')
        gender = request.form.get('gender')
        date_of_birth = request.form.get('date_of_birth')
        medical_notes = request.form.get('medical_notes')

        # 2. Handle Image Upload
        photo_url = None
        if 'profile_photo' in request.files:
            file = request.files['profile_photo']
            if file.filename != '':
                # Secure the filename and save to static/profiles
                filename = secure_filename(f"patient_{patient_id}_{file.filename}")
                filepath = os.path.join('static', 'profiles')
                os.makedirs(filepath, exist_ok=True)
                file.save(os.path.join(filepath, filename))
                
                # Generate URL accessible via your ngrok domain
                # photo_url = f"{request.host_url}static/profiles/{filename}"
                photo_url = f"/static/profiles/{filename}"

        # 3. Update Database
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Dynamic SQL based on whether a photo was uploaded
            update_query = '''
                UPDATE users 
                SET full_name = %s, phone_no = %s, address = %s, 
                    email = %s, gender = %s, date_of_birth = %s, updated_at = CURRENT_TIMESTAMP
            '''
            params = [full_name, phone_no, address, email, gender, date_of_birth]

            if photo_url:
                update_query += ", profile_photo = %s"
                params.append(photo_url)

            update_query += " WHERE user_id = %s AND role = 'patient'"
            params.append(patient_id)

            # Update Users table
            cursor.execute(update_query, tuple(params))
            
            # Update Patient table
            cursor.execute('''
                UPDATE patient 
                SET medical_notes = %s
                WHERE patient_id = %s
            ''', (medical_notes, patient_id))
            
            conn.commit()
            cursor.close()
            
        return jsonify({"success": True, "message": "Profile updated successfully", "photo_url": photo_url})
    except Exception as e:
        print(f"Update patient error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/update_caregiver/<int:caregiver_id>', methods=['PUT'])
def update_caregiver(caregiver_id):
    """Update caregiver profile with Multipart Form Data"""
    try:
        # CRITICAL FIX: Use request.form
        full_name = request.form.get('full_name')
        phone_no = request.form.get('phone_no')
        address = request.form.get('address')
        email = request.form.get('email')
        gender = request.form.get('gender')
        date_of_birth = request.form.get('date_of_birth')

        # Handle Image Upload
        photo_url = None
        if 'profile_photo' in request.files:
            file = request.files['profile_photo']
            if file.filename != '':
                filename = secure_filename(f"caregiver_{caregiver_id}_{file.filename}")
                filepath = os.path.join('static', 'profiles')
                os.makedirs(filepath, exist_ok=True)
                file.save(os.path.join(filepath, filename))
                
                photo_url = f"{request.host_url}static/profiles/{filename}"

        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            update_query = '''
                UPDATE users 
                SET full_name = %s, phone_no = %s, address = %s, 
                    email = %s, gender = %s, date_of_birth = %s, updated_at = CURRENT_TIMESTAMP
            '''
            params = [full_name, phone_no, address, email, gender, date_of_birth]

            if photo_url:
                update_query += ", profile_photo = %s"
                params.append(photo_url)

            update_query += " WHERE user_id = %s AND role = 'caregiver'"
            params.append(caregiver_id)

            cursor.execute(update_query, tuple(params))
            conn.commit()
            cursor.close()
            
        return jsonify({"success": True, "message": "Profile updated successfully", "photo_url": photo_url})
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
# First, get medication_id from the prescription
            cursor.execute('SELECT medication_id FROM prescription_config WHERE prescription_id = %s', (prescription_id,))
            med_id = cursor.fetchone()[0]
                        # Then update the medication's inventory
            cursor.execute('''
                            UPDATE medications
                            SET current_inventory = current_inventory - 1, updated_at = CURRENT_TIMESTAMP
                            WHERE medication_id = %s AND current_inventory > 0
                        ''', (med_id,))
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
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        medication_name = data.get('medication_name')
        dosage_tablet = data.get('dosage_tablet')
        dispense_schedule = data.get('dispense_schedule')
        current_inventory = data.get('current_inventory', 0)
        refill_threshold = data.get('refill_threshold', 5)
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        device_id = data.get('device_id')

        if not all([patient_id, medication_name, dosage_tablet, dispense_schedule, start_date]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            
            # 1. Get medication_id from medications table
            cursor.execute('SELECT medication_id FROM medications WHERE medication_name = %s', (medication_name,))
            med_row = cursor.fetchone()
            if not med_row:
                return jsonify({"success": False, "message": f"Medication '{medication_name}' not found"}), 400
            medication_id = med_row['medication_id']

            # 2. Insert prescription 
            cursor.execute('''
                INSERT INTO prescription_config 
                (patient_id, medication_id, dosage_tablet, dispense_schedule, start_date, end_date)
                VALUES (%s, %s, %s, %s, %s, %s)
            ''', (patient_id, medication_id, dosage_tablet, dispense_schedule, start_date, end_date))
            new_prescription_id = cursor.lastrowid

            # 3. Update medication inventory/device if provided
            if current_inventory is not None:
                cursor.execute('UPDATE medications SET current_inventory = %s WHERE medication_id = %s',
                            (current_inventory, medication_id))
            if device_id is not None:
                cursor.execute('UPDATE medications SET device_id = %s WHERE medication_id = %s',
                            (device_id, medication_id))
            if refill_threshold is not None:
                cursor.execute('UPDATE medications SET refill_threshold = %s WHERE medication_id = %s',
                            (refill_threshold, medication_id))
            
            # ==========================================
            # 🌟 NEW: AUTO-GENERATE NOTIFICATION
            # ==========================================
            notification_title = "New Prescription Added"
            notification_message = f"Your caregiver has added a new prescription for {medication_name}. Please check your updated schedule."
            
            cursor.execute('''
                INSERT INTO notifications (patient_id, title, message)
                VALUES (%s, %s, %s)
            ''', (patient_id, notification_title, notification_message))
            # ==========================================

            new_prescription = {
                "prescription_id": new_prescription_id,
                "patient_id": patient_id,
                "medication_id": medication_id,
                "medication_name": medication_name,
                "dosage_tablet": dosage_tablet,
                "dispense_schedule": dispense_schedule,
                "start_date": start_date,
                "end_date": end_date,
                "created_at": datetime.datetime.now(),
                "updated_at": datetime.datetime.now()
            }
            conn.commit()
            cursor.close()

        return jsonify({"success": True, "message": "Prescription created successfully!", "data": new_prescription})
    except Exception as e:
        print(f"Add prescription error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/prescription/<int:prescription_id>', methods=['GET'])
def get_prescription_details(prescription_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT pc.prescription_id, pc.patient_id, m.medication_name,
                       pc.dosage_tablet, pc.dispense_schedule,
                       m.current_inventory, m.refill_threshold,
                       pc.start_date, pc.end_date,
                       pc.created_at, pc.updated_at,
                       m.device_id, m.motor_slot
                FROM prescription_config pc
                JOIN medications m ON pc.medication_id = m.medication_id
                WHERE pc.prescription_id = %s
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

@app.route('/predict_and_save', methods=['POST'])
def predict_and_save():
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        if not patient_id:
            return jsonify({"success": False, "message": "patient_id required"}), 400
        
        # Use the helper – it will compute and store a fresh prediction
        new_pred = compute_prediction_for_patient(patient_id)
        return jsonify({
            "success": True,
            "message": "Prediction generated and saved",
            "data": new_pred
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/run_ai_analytics_job', methods=['POST'])
def run_ai_analytics_job():
    """Batch run AI predictions for all active patients and store results in DB."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            
            cursor.execute('''
                SELECT p.patient_id, u.date_of_birth
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                WHERE u.is_active = true
            ''')
            patients = cursor.fetchall()
            
            inserted_count = 0
            current_day = datetime.datetime.now().strftime('%A')
            hour = datetime.datetime.now().hour
            time_category = 'Morning' if 5 <= hour < 12 else 'Afternoon' if 12 <= hour < 18 else 'Evening'

            days_map_local = {'Monday': 0, 'Tuesday': 1, 'Wednesday': 2, 'Thursday': 3, 'Friday': 4, 'Saturday': 5, 'Sunday': 6}
            times_map_local = {'Morning': 0, 'Afternoon': 1, 'Evening': 2}
            
            for pat in patients:
                pid = pat['patient_id']
                dob = pat['date_of_birth']
                age = 65
                if dob:
                    age = (datetime.date.today() - dob).days // 365
                
                cursor.execute('''
                    SELECT status 
                    FROM adherence_logs al
                    JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                    WHERE pc.patient_id = %s AND al.status IN ('TAKEN', 'MISSED')
                    ORDER BY al.scheduled_time DESC LIMIT 3
                ''', (pid,))
                history_rows = cursor.fetchall()
                history_vals = [1.0 if r['status'] == 'TAKEN' else 0.0 for r in history_rows]
                while len(history_vals) < 3:
                    history_vals.insert(0, 1.0)
                
                day_val = days_map_local.get(current_day, 0)
                time_val = times_map_local.get(time_category, 0)
                
                if lstm_model is None or rf_model is None:
                    forget_prob = 0.35
                else:
                    lstm_input_data = []
                    for past_status in history_vals[-3:]:
                        feature_row = [age / 100.0, day_val / 6.0, time_val / 2.0, float(past_status)]
                        lstm_input_data.append(feature_row)
                    lstm_input_array = np.array([lstm_input_data])
                    lstm_prob = float(lstm_model.predict(lstm_input_array, verbose=0)[0][0])
                    
                    missed_count = history_vals.count(0.0)
                    rf_input_array = np.array([[age, day_val, time_val, missed_count]])
                    rf_prob = float(rf_model.predict_proba(rf_input_array)[0][1])
                    forget_prob = (lstm_prob * 0.5) + (rf_prob * 0.5)
                
                prediction_score_val = (1 - forget_prob) * 100.0
                risk_level_val = "HIGH" if forget_prob > 0.6 else "MEDIUM" if forget_prob > 0.3 else "LOW"
                
                features_used_json = json.dumps({
                    "age": age,
                    "day": current_day,
                    "time": time_category,
                    "recent_adherence": history_vals,
                    "temporal_pattern": "Pattern extracted from LSTM"
                })
                
                # ✅ FIX: Use ON CONFLICT to update existing records
                cursor.execute('''
                    INSERT INTO ai_adherence_prediction (patient_id, prediction_score, risk_level, predicted_at, features_used)
                    VALUES (%s, %s, %s, CURRENT_TIMESTAMP, %s)
                    ON DUPLICATE KEY UPDATE
                        prediction_score = VALUES(prediction_score),
                        risk_level = VALUES(risk_level),
                        predicted_at = VALUES(predicted_at),
                        features_used = VALUES(features_used)
                ''', (pid, round(prediction_score_val, 2), risk_level_val, features_used_json))
                
                inserted_count += 1
                
            conn.commit()
            cursor.close()
            
        return jsonify({"success": True, "message": f"Successfully updated AI predictions for {inserted_count} patients."})
    except Exception as e:
        print(f"Batch AI prediction error: {e}")
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
            cursor = conn.cursor(dictionary=True)
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
            cursor.execute('UPDATE notifications SET is_read = 1 WHERE notification_id = %s', (notification_id,))
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
    return jsonify({"status": "healthy", "database": db_status, "model": "loaded" if lstm_model else "not loaded"})

@app.route('/caregiver/<int:caregiver_id>/analytics_overview', methods=['GET'])
def get_analytics_overview(caregiver_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            
            # First, get total number of patients under this caregiver
            cursor.execute('''
                SELECT COUNT(*) AS total_patients
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                WHERE p.caregiver_id = %s AND u.is_active = true
            ''', (caregiver_id,))
            total = cursor.fetchone()['total_patients']
            
            # Then, get risk counts and average prediction score from REAL predictions
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
                WHERE p.caregiver_id = %s AND u.is_active = true
            ''', (caregiver_id,))
            stats = cursor.fetchone()
            cursor.close()

        # Calculate average score - if no predictions exist, use 85.0 as fallback
        avg_score = stats['avg_prediction_score']
        if avg_score is None:
            avg_score = 85.0  # Only fallback when NO predictions exist
        else:
            avg_score = float(avg_score)
        
        return jsonify({
            "success": True,
            "data": {
                "overall_adherence_prediction": round(avg_score, 1),
                "high_risk_patients": stats['high_risk_patients'] or 0,
                "medium_risk_patients": stats['medium_risk_patients'] or 0,
                "total_analyzed": total,
            }
        })
    except Exception as e:
        print(f"Analytics overview error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500



@app.route('/patient/<int:patient_id>', methods=['DELETE'])
def delete_patient(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            # Delete dependent records (adjust if your DB has CASCADE)
            cursor.execute('DELETE FROM ai_adherence_prediction WHERE patient_id = %s', (patient_id,))
            cursor.execute('DELETE FROM notifications WHERE patient_id = %s', (patient_id,))
            cursor.execute('''
                DELETE FROM adherence_logs 
                WHERE prescription_id IN (SELECT prescription_id FROM prescription_config WHERE patient_id = %s)
            ''', (patient_id,))
            cursor.execute('DELETE FROM prescription_config WHERE patient_id = %s', (patient_id,))
            # cursor.execute('DELETE FROM iot_device WHERE patient_id = %s', (patient_id,))
            cursor.execute('DELETE FROM patient WHERE patient_id = %s', (patient_id,))
            cursor.execute('DELETE FROM users WHERE user_id = %s AND role = %s', (patient_id, 'patient'))
            conn.commit()
            cursor.close()
        return jsonify({"success": True, "message": "Patient deleted successfully"})
    except Exception as e:
        print(f"Delete patient error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/iot_device/patient/<int:patient_id>', methods=['GET'])
def get_patient_device(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT d.device_id, d.device_serial, 
                    d.last_reported_battery AS battery_level, 
                    d.last_battery_report AS last_active_timestamp,
                    d.last_known_ip AS last_known_ip
                FROM prescription_config pc
                JOIN medications m ON pc.medication_id = m.medication_id
                JOIN iot_device d ON m.device_id = d.device_id
                WHERE pc.patient_id = %s AND m.device_id IS NOT NULL
                AND (pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE)
                LIMIT 1
            ''', (patient_id,))
            device = cursor.fetchone()
            cursor.close()
        
        if device:
            return jsonify({"success": True, "data": device})
        else:
            return jsonify({"success": True, "data": {}})
    except Exception as e:
        print(f"Get device error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/restock_medication', methods=['POST'])
def restock_medication():
    """Restock medication by calling add_inventory_refill"""
    try:
        data = request.get_json()
        prescription_id = data.get('prescription_id')
        quantity = data.get('quantity', 30)
        
        if not prescription_id:
            return jsonify({"success": False, "message": "prescription_id required"}), 400
        
        # Call the existing function
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT add_inventory_refill(%s, %s, %s)', 
                          (prescription_id, quantity, 'caregiver_restock'))
            conn.commit()
            cursor.close()
        
        return jsonify({"success": True, "message": f"Added {quantity} pills to inventory"})
    except Exception as e:
        print(f"Restock error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/test_device/<int:user_id>', methods=['POST'])
def test_device(user_id):
    """Simulate testing the IoT device"""
    # In a real implementation, this would send a signal to the actual hardware
    return jsonify({"success": True, "message": "Buzzer Signal Sent to Kit! 🔊"})



# ==========================================
# 📋 UPDATE & DELETE PRESCRIPTION
# ==========================================

@app.route('/prescription/<int:prescription_id>', methods=['PUT'])
def update_prescription(prescription_id):
    try:
        data = request.get_json()
        medication_name = data.get('medication_name')
        dosage_tablet = data.get('dosage_tablet')
        dispense_schedule = data.get('dispense_schedule')
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        current_inventory = data.get('current_inventory')
        refill_threshold = data.get('refill_threshold')
        device_id = data.get('device_id')
        
        if not all([medication_name, dosage_tablet, dispense_schedule]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get medication_id
            cursor.execute('SELECT medication_id FROM medications WHERE medication_name = %s', (medication_name,))
            med_row = cursor.fetchone()
            if not med_row:
                return jsonify({"success": False, "message": f"Medication '{medication_name}' not found"}), 400
            medication_id = med_row[0]
            
            cursor.execute('''
                UPDATE prescription_config 
                SET medication_id = %s, dosage_tablet = %s, dispense_schedule = %s, 
                    start_date = %s, end_date = %s, updated_at = CURRENT_TIMESTAMP
                WHERE prescription_id = %s
            ''', (medication_id, dosage_tablet, dispense_schedule, start_date, end_date, prescription_id))
            
            # Update medications table for inventory, threshold, device_id
            updates = []
            params = []
            if current_inventory is not None:
                updates.append('current_inventory = %s')
                params.append(current_inventory)
            if refill_threshold is not None:
                updates.append('refill_threshold = %s')
                params.append(refill_threshold)
            if device_id is not None:
                updates.append('device_id = %s')
                params.append(device_id)
            else:
                if 'device_id' in data: # allow clearing device_id if passed explicitly as null
                    updates.append('device_id = NULL')
            
            if updates:
                query = f"UPDATE medications SET {', '.join(updates)} WHERE medication_id = %s"
                params.append(medication_id)
                cursor.execute(query, tuple(params))
            
            conn.commit()
            cursor.close()

        return jsonify({"success": True, "message": "Prescription updated successfully!"})
    except Exception as e:
        print(f"Update prescription error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/prescription/<int:prescription_id>', methods=['DELETE'])
def delete_prescription(prescription_id):
    """Delete a prescription and its associated logs, and notify the patient"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            
            # 1. Fetch the patient_id and medication_name BEFORE we delete it
            cursor.execute('''
                SELECT pc.patient_id, m.medication_name 
                FROM prescription_config pc
                JOIN medications m ON pc.medication_id = m.medication_id
                WHERE pc.prescription_id = %s
            ''', (prescription_id,))
            rx_data = cursor.fetchone()
            
            # 2. Delete associated adherence logs first
            cursor.execute('DELETE FROM adherence_logs WHERE prescription_id = %s', (prescription_id,))
            
            # 3. Delete the prescription itself
            cursor.execute('DELETE FROM prescription_config WHERE prescription_id = %s', (prescription_id,))
            
            # ==========================================
            # 🌟 NEW: AUTO-GENERATE DELETION NOTIFICATION
            # ==========================================
            if rx_data:
                patient_id = rx_data['patient_id']
                med_name = rx_data['medication_name']
                notification_title = "Prescription Removed"
                notification_message = f"Your caregiver has removed your prescription for {med_name}."
                
                cursor.execute('''
                    INSERT INTO notifications (patient_id, title, message)
                    VALUES (%s, %s, %s)
                ''', (patient_id, notification_title, notification_message))
            # ==========================================

            conn.commit()
            cursor.close()

        return jsonify({"success": True, "message": "Prescription deleted and patient notified!"})
    except Exception as e:
        print(f"Delete prescription error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/device/heartbeat', methods=['POST'])
def device_heartbeat():
    """Called by ESP32 to report its current state"""
    try:
        data = request.get_json()
        device_serial = data.get('device_serial')
        battery = data.get('battery', 100)
        wifi_rssi = data.get('rssi')
        # Get the device's public IP as seen by the server
        device_ip = request.remote_addr

        if not device_serial:
            return jsonify({"success": False, "message": "device_serial required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()
            # 👇 CHANGED TO MYSQL SYNTAX 👇
            cursor.execute('''
                INSERT INTO iot_device (device_serial, last_reported_battery, last_known_ip, last_battery_report, wifi_rssi)
                VALUES (%s, %s, %s, CURRENT_TIMESTAMP, %s)
                ON DUPLICATE KEY UPDATE 
                    last_reported_battery = VALUES(last_reported_battery),
                    last_known_ip = VALUES(last_known_ip),
                    last_battery_report = VALUES(last_battery_report),
                    wifi_rssi = VALUES(wifi_rssi)
            ''', (device_serial, battery, device_ip, wifi_rssi))
            conn.commit()
            cursor.close()

        return jsonify({"success": True, "message": "Heartbeat received"})
    except Exception as e:
        print(f"Heartbeat error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ==========================================
# 🎮 HARDWARE CONTROL PROXY ENDPOINTS
# ==========================================

def _forward_to_esp(device_ip, endpoint, method='GET', json_data=None):
    """Helper to forward a request to the ESP32."""
    import requests
    url = f"http://{device_ip}{endpoint}"
    try:
        if method == 'GET':
            resp = requests.get(url, timeout=5)
        else:
            resp = requests.post(url, json=json_data, timeout=5)
        return resp.status_code, resp.text
    except Exception as e:
        return None, str(e)

@app.route('/device/control/led', methods=['POST'])
def control_led():
    data = request.get_json()
    patient_id = data.get('patient_id')
    action = data.get('action')
    if not patient_id or action not in ('on', 'off'):
        return jsonify({"success": False, "message": "patient_id and action (on/off) required"}), 400

    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
    SELECT d.last_known_ip
    FROM iot_device d
    JOIN medications m ON d.device_id = m.device_id
    JOIN prescription_config pc ON m.medication_id = pc.medication_id
    WHERE pc.patient_id = %s
    LIMIT 1
''', (patient_id,))
        device = cursor.fetchone()
        cursor.close()

    if not device or not device['last_known_ip']:
        return jsonify({"success": False, "message": "Device IP not known"}), 404

    status_code, response = _forward_to_esp(device['last_known_ip'], f"/led/{action}")
    if status_code == 200:
        return jsonify({"success": True, "message": f"LED turned {action}"})
    else:
        return jsonify({"success": False, "message": f"ESP32 error: {response}"}), 500


@app.route('/device/control/buzzer', methods=['POST'])
def control_buzzer():
    data = request.get_json()
    patient_id = data.get('patient_id')
    action = data.get('action')
    if not patient_id or action not in ('on', 'off'):
        return jsonify({"success": False, "message": "patient_id and action (on/off) required"}), 400

    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
    SELECT d.last_known_ip
    FROM iot_device d
    JOIN medications m ON d.device_id = m.device_id
    JOIN prescription_config pc ON m.medication_id = pc.medication_id
    WHERE pc.patient_id = %s
    LIMIT 1
''', (patient_id,))
        device = cursor.fetchone()
        cursor.close()

    if not device or not device['last_known_ip']:
        return jsonify({"success": False, "message": "Device IP not known"}), 404

    status_code, response = _forward_to_esp(device['last_known_ip'], f"/buzzer/{action}")
    if status_code == 200:
        return jsonify({"success": True, "message": f"Buzzer turned {action}"})
    else:
        return jsonify({"success": False, "message": f"ESP32 error: {response}"}), 500

@app.route('/device/control/display', methods=['POST'])
def control_display():
    data = request.get_json()
    patient_id = data.get('patient_id')
    command = data.get('command')   # 'hello', 'clear', 'sv'
    if not patient_id or command not in ('hello', 'clear', 'sv'):
        return jsonify({"success": False, "message": "patient_id and command (hello/clear/sv) required"}), 400

    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
        SELECT d.last_known_ip
        FROM iot_device d
        JOIN medications m ON d.device_id = m.device_id
        JOIN prescription_config pc ON m.medication_id = pc.medication_id
        WHERE pc.patient_id = %s
        LIMIT 1
    ''', (patient_id,))
        device = cursor.fetchone()
        cursor.close()

    if not device or not device['last_known_ip']:
        return jsonify({"success": False, "message": "Device IP not known"}), 404

    status_code, response = _forward_to_esp(device['last_known_ip'], f"/display/{command}")
    if status_code == 200:
        return jsonify({"success": True, "message": f"Display command '{command}' sent"})
    else:
        return jsonify({"success": False, "message": f"ESP32 error: {response}"}), 500

@app.route('/device/control/stepper', methods=['POST'])
def control_stepper():
    data = request.get_json()
    patient_id = data.get('patient_id')
    motor = data.get('motor')      # 1, 2, or 3
    action = data.get('action')    # 'forward', 'backward', '90', '180'
    if not patient_id or motor not in (1,2,3) or action not in ('forward','backward','90','180'):
        return jsonify({"success": False, "message": "patient_id, motor(1-3), action(forward/backward/90/180) required"}), 400

    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
    SELECT d.last_known_ip
    FROM iot_device d
    JOIN medications m ON d.device_id = m.device_id
    JOIN prescription_config pc ON m.medication_id = pc.medication_id
    WHERE pc.patient_id = %s
    LIMIT 1
''', (patient_id,))
        device = cursor.fetchone()
        cursor.close()

    if not device or not device['last_known_ip']:
        return jsonify({"success": False, "message": "Device IP not known"}), 404

    # Map motor number to endpoint prefix
    motor_prefix = "" if motor == 1 else str(motor)   # /stepper, /stepper2, /stepper3
    endpoint = f"/stepper{motor_prefix}/{action}"
    status_code, response = _forward_to_esp(device['last_known_ip'], endpoint)
    if status_code == 200:
        return jsonify({"success": True, "message": f"Motor {motor} {action} command sent"})
    else:
        return jsonify({"success": False, "message": f"ESP32 error: {response}"}), 500


@app.route('/iot_device/<int:device_id>', methods=['PUT'])
def update_device(device_id):
    data = request.get_json()
    new_serial = data.get('device_serial')
    if not new_serial:
        return jsonify({"success": False, "message": "device_serial required"}), 400
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('UPDATE iot_device SET device_serial = %s WHERE device_id = %s', (new_serial, device_id))
        conn.commit()
    return jsonify({"success": True, "message": "Device updated"})

@app.route('/iot_device/<int:device_id>', methods=['DELETE'])
def delete_device(device_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('DELETE FROM iot_device WHERE device_id = %s', (device_id,))
        conn.commit()
    return jsonify({"success": True, "message": "Device deleted"})



@app.route('/iot_device', methods=['POST'])
def add_device():
    data = request.get_json()
    device_serial = data.get('device_serial')
    last_known_ip = data.get('last_known_ip')
    battery = data.get('battery', 100)

    if not device_serial:
        return jsonify({"success": False, "message": "device_serial required"}), 400

    # Convert empty string to None
    if not last_known_ip:
        last_known_ip = None

    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO iot_device (device_serial, last_known_ip, last_reported_battery, last_battery_report)
            VALUES (%s, %s, %s, CURRENT_TIMESTAMP)
        ''', (device_serial, last_known_ip, battery))
        new_id = cursor.lastrowid
        conn.commit()
    return jsonify({"success": True, "message": "Device added", "device_id": new_id})


@app.route('/medications', methods=['GET'])
def get_medications():
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT medication_id, medication_name, current_inventory, refill_threshold,
                       device_id, motor_slot, created_at, updated_at
                FROM medications ORDER BY medication_name
            ''')
            meds = cursor.fetchall()
        return jsonify({"success": True, "data": meds})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/medications', methods=['POST'])
def add_medication():
    try:
        data = request.get_json()
        medication_name = data.get('medication_name')
        current_inventory = data.get('current_inventory', 0)
        refill_threshold = data.get('refill_threshold', 5)
        device_id = data.get('device_id')
        motor_slot = data.get('motor_slot')

        if not medication_name:
            return jsonify({"success": False, "message": "Medication name is required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Check if medication already exists
            cursor.execute('SELECT medication_id FROM medications WHERE medication_name = %s', (medication_name,))
            if cursor.fetchone():
                return jsonify({"success": False, "message": "Medication already exists"}), 400

            cursor.execute('''
                INSERT INTO medications (medication_name, current_inventory, refill_threshold, device_id, motor_slot)
                VALUES (%s, %s, %s, %s, %s)
            ''', (medication_name, current_inventory, refill_threshold, device_id, motor_slot))
            medication_id = cursor.lastrowid
            conn.commit()

        return jsonify({
            "success": True,
            "data": {
                "medication_id": medication_id,
                "medication_name": medication_name,
                "current_inventory": current_inventory,
                "refill_threshold": refill_threshold,
                "device_id": device_id,
                "motor_slot": motor_slot
            }
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/device/create_with_prescription', methods=['POST'])
def create_device_with_prescription():
    data = request.get_json()
    device_serial = data.get('device_serial')
    patient_id = data.get('patient_id')
    motor_slot = data.get('motor_slot')
    medication_id = data.get('medication_id')
    inventory = data.get('current_inventory', 30)
    threshold = data.get('refill_threshold', 10)

    if not all([device_serial, patient_id, motor_slot, medication_id]):
        return jsonify({"success": False, "message": "Missing required fields"}), 400

    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Insert device
        cursor.execute('''
            INSERT INTO iot_device (device_serial, last_reported_battery, last_battery_report)
            VALUES (%s, 100, CURRENT_TIMESTAMP)
        ''', (device_serial,))
        device_id = cursor.lastrowid

        # Create prescription (without device/motor/inventory columns)
        cursor.execute('''
            INSERT INTO prescription_config
            (patient_id, medication_id, dosage_tablet, dispense_schedule, start_date)
            VALUES (%s, %s, 1.0, '0 8 * * *', CURRENT_DATE)
        ''', (patient_id, medication_id))

        # Update medication with device, motor slot, inventory, threshold
        cursor.execute('''
            UPDATE medications
            SET device_id = %s, motor_slot = %s,
                current_inventory = %s, refill_threshold = %s
            WHERE medication_id = %s
        ''', (device_id, motor_slot, inventory, threshold, medication_id))

        conn.commit()
    return jsonify({"success": True, "message": "Device and prescription created"})

@app.route('/device/<int:device_id>/prescription', methods=['PUT'])
def update_device_prescription(device_id):
    data = request.get_json()
    patient_id = data.get('patient_id')
    motor_slot = data.get('motor_slot')
    medication_id = data.get('medication_id')
    inventory = data.get('current_inventory')
    threshold = data.get('refill_threshold')

    with get_db_connection() as conn:
        cursor = conn.cursor()

        # Ensure a prescription exists for this patient (or create one)
        cursor.execute('''
            INSERT INTO prescription_config (patient_id, medication_id, dosage_tablet, dispense_schedule, start_date)
            VALUES (%s, %s, 1.0, '0 8 * * *', CURRENT_DATE)
            ON CONFLICT (prescription_id) DO NOTHING
        ''', (patient_id, medication_id))

        # Update medication with device, motor slot, inventory, threshold
        cursor.execute('''
            UPDATE medications
            SET device_id = %s, motor_slot = %s,
                current_inventory = %s, refill_threshold = %s
            WHERE medication_id = %s
        ''', (device_id, motor_slot, inventory, threshold, medication_id))

        conn.commit()
    return jsonify({"success": True, "message": "Prescription updated"})



@app.route('/device/<int:device_id>/patient/<int:patient_id>/prescription', methods=['GET'])
def get_prescription_for_device_patient(device_id, patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT pc.prescription_id, m.motor_slot, m.medication_id,
                       m.current_inventory, m.refill_threshold
                FROM prescription_config pc
                JOIN medications m ON pc.medication_id = m.medication_id
                WHERE pc.patient_id = %s AND m.device_id = %s
                LIMIT 1
            ''', (patient_id, device_id))
            result = cursor.fetchone()
            return jsonify({"success": True, "data": result})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/medications/<int:medication_id>', methods=['PUT'])
def update_medication(medication_id):
    try:
        data = request.get_json()
        new_name = data.get('medication_name')
        current_inventory = data.get('current_inventory')
        refill_threshold = data.get('refill_threshold')
        device_id = data.get('device_id')
        motor_slot = data.get('motor_slot')

        if not new_name and current_inventory is None and refill_threshold is None and device_id is None and motor_slot is None:
            return jsonify({"success": False, "message": "No fields to update"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()
            # Build dynamic SET clause
            updates = []
            params = []
            if new_name:
                updates.append("medication_name = %s")
                params.append(new_name)
            if current_inventory is not None:
                updates.append("current_inventory = %s")
                params.append(current_inventory)
            if refill_threshold is not None:
                updates.append("refill_threshold = %s")
                params.append(refill_threshold)
            if device_id is not None:
                updates.append("device_id = %s")
                params.append(device_id)
            if motor_slot is not None:
                updates.append("motor_slot = %s")
                params.append(motor_slot)

            params.append(medication_id)
            query = f"UPDATE medications SET {', '.join(updates)}, updated_at = CURRENT_TIMESTAMP WHERE medication_id = %s"
            cursor.execute(query, tuple(params))
            
            if cursor.rowcount > 0:
                cursor.execute('SELECT medication_id, medication_name, current_inventory, refill_threshold, device_id, motor_slot FROM medications WHERE medication_id = %s', (medication_id,))
                updated = cursor.fetchone()
                conn.commit()
                return jsonify({
                    "success": True,
                    "data": {
                        "medication_id": updated[0],
                        "medication_name": updated[1],
                        "current_inventory": updated[2],
                        "refill_threshold": updated[3],
                        "device_id": updated[4],
                        "motor_slot": updated[5]
                    }
                })
            else:
                conn.commit()
                return jsonify({"success": False, "message": "Medication not found"}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/medications/<int:medication_id>', methods=['DELETE'])
def delete_medication(medication_id):
    """Delete a medication if not referenced by any prescription."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            # Check if medication is used in any prescription
            cursor.execute('SELECT COUNT(*) FROM prescription_config WHERE medication_id = %s', (medication_id,))
            count = cursor.fetchone()[0]
            if count > 0:
                return jsonify({"success": False, "message": f"Cannot delete: medication is used in {count} prescription(s)"}), 400

            cursor.execute('DELETE FROM medications WHERE medication_id = %s', (medication_id,))
            deleted_count = cursor.rowcount
            conn.commit()
            if deleted_count > 0:
                return jsonify({"success": True, "message": "Medication deleted"})
            else:
                return jsonify({"success": False, "message": "Medication not found"}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ==========================================
# 🛠️ DEVICE DETAILS & PATIENT LOOKUP
# ==========================================

@app.route('/device/<int:device_id>', methods=['GET'])
def get_device_by_id(device_id):
    """Return device details for a given device_id."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT device_id, device_serial, last_reported_battery AS battery_level,
                       last_battery_report AS last_active_timestamp, last_known_ip
                FROM iot_device
                WHERE device_id = %s
            ''', (device_id,))
            device = cursor.fetchone()
            cursor.close()
        if device:
            return jsonify({"success": True, "data": device})
        else:
            return jsonify({"success": False, "error": "Device not found"}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/device/<int:device_id>/patient', methods=['GET'])
def get_patient_by_device(device_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT p.patient_id, u.full_name
                FROM medications m
                JOIN prescription_config pc ON m.medication_id = pc.medication_id
                JOIN patient p ON pc.patient_id = p.patient_id
                JOIN users u ON p.patient_id = u.user_id
                WHERE m.device_id = %s
                ORDER BY pc.created_at DESC
                LIMIT 1
            ''', (device_id,))
            patient = cursor.fetchone()
            cursor.close()
        if patient:
            return jsonify({"success": True, "data": patient})
        else:
            return jsonify({"success": True, "data": None})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500



@app.route('/devices', methods=['GET'])
def get_all_devices():
    """Return all IoT devices (for dropdown)."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT device_id, device_serial, last_reported_battery AS battery_level,
                       last_battery_report AS last_active_timestamp, last_known_ip
                FROM iot_device
                ORDER BY device_id
            ''')
            devices = cursor.fetchall()
            cursor.close()
        return jsonify({"success": True, "data": devices})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500



@app.route('/device/<int:device_id>/prescriptions', methods=['GET'])
def get_device_prescriptions(device_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
        SELECT pc.prescription_id, pc.patient_id, med.medication_name,
            pc.dosage_tablet, pc.dispense_schedule,
            med.current_inventory, med.refill_threshold,
            pc.start_date, pc.end_date,
            pc.created_at, pc.updated_at,
            med.device_id, med.motor_slot
        FROM prescription_config pc
        JOIN medications med ON pc.medication_id = med.medication_id
        WHERE med.device_id = %s
        AND (pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE)
        ORDER BY med.motor_slot ASC
    ''', (device_id,))
            prescriptions = cursor.fetchall()
            cursor.close()
        return jsonify({"success": True, "data": prescriptions})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500



@app.route('/device/<device_serial>/pending_dose', methods=['GET'])
def get_pending_dose(device_serial):
    """ESP32 calls this when the touch button is pressed to see which motor to spin."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            # Find the oldest PENDING log for this specific physical box 
            # We allow dispensing if the scheduled time is within the next 60 minutes
            cursor.execute('''
                SELECT al.adlog_id, al.prescription_id, m.motor_slot, m.medication_name
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                JOIN medications m ON pc.medication_id = m.medication_id
                JOIN iot_device d ON m.device_id = d.device_id
                WHERE d.device_serial = %s 
                  AND al.status = 'PENDING' 
                  AND al.scheduled_time <= CURRENT_TIMESTAMP + INTERVAL 60 MINUTE
                ORDER BY al.scheduled_time ASC
                LIMIT 1
            ''', (device_serial,))
            dose = cursor.fetchone()
            cursor.close()
        
        if dose:
            return jsonify({"success": True, "has_pending": True, "data": dose})
        else:
            return jsonify({"success": True, "has_pending": False})
            
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/device/dispense_success', methods=['POST'])
def dispense_success():
    """ESP32 calls this AFTER the motor finishes rotating to update the DB."""
    try:
        data = request.get_json()
        adlog_id = data.get('adlog_id')
        prescription_id = data.get('prescription_id')
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # 1. Mark the adherence log as TAKEN and record the exact physical dispense time
            cursor.execute('''
                UPDATE adherence_logs 
                SET status = 'TAKEN', dispensed_time = CURRENT_TIMESTAMP 
                WHERE adlog_id = %s
            ''', (adlog_id,))
            
            # 2. Deduct the inventory based on the dosage required
            cursor.execute('''
                UPDATE medications m
                JOIN prescription_config pc ON m.medication_id = pc.medication_id
                SET m.current_inventory = m.current_inventory - pc.dosage_tablet, 
                    m.updated_at = CURRENT_TIMESTAMP
                WHERE pc.prescription_id = %s AND m.current_inventory > 0
            ''', (prescription_id,))
            
            conn.commit()
            cursor.close()
            
        return jsonify({"success": True, "message": "Dispense recorded successfully!"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500





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
 