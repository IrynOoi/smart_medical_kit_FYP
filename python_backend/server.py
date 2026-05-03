# server.py
#backend codes
import json 
import joblib # <--- Add this impor
from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
from flask_cors import CORS
from flask.json.provider import DefaultJSONProvider
import numpy as np
import tensorflow as tf
import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2 import pool
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
from psycopg2.pool import ThreadedConnectionPool # 改用线程安全的连接池

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

# 使用 ThreadedConnectionPool，最大连接数稍微调大一点以防高并发
db_pool = ThreadedConnectionPool(1, 20, **DB_CONFIG)

@contextmanager
def get_db_connection():
    conn = None
    try:
        conn = db_pool.getconn()
        yield conn
    except Exception as e:
        if conn:
            conn.rollback() # 【关键修复】如果发生错误，必须回滚清洗这个连接，防止“毒化”！
        raise e
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
            cursor = conn.cursor(cursor_factory=RealDictCursor)
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
    """
    Fetch the LATEST existing prediction from PostgreSQL without recalculating.
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
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
                       pc.medication_name, al.scheduled_time, al.status,
                       pc.dosage_tablet, pc.dispense_schedule, pc.current_inventory
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



def compute_prediction_for_patient(patient_id):
    """
    Compute HYBRID prediction using LSTM and Random Forest, store in DB.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # 1. Get patient age
        cursor.execute('''
            SELECT EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth)) AS age
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
        if forget_prob > 0.6:
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
            VALUES (%s, %s, %s, CURRENT_TIMESTAMP, %s::jsonb)
            ON CONFLICT (patient_id) DO UPDATE SET
                prediction_score = EXCLUDED.prediction_score,
                risk_level = EXCLUDED.risk_level,
                predicted_at = EXCLUDED.predicted_at,
                features_used = EXCLUDED.features_used
            RETURNING ad_id, patient_id, prediction_score, risk_level, predicted_at, features_used
        ''', (patient_id, adherence_score, risk_level, json.dumps(features_used)))
        
        new_pred = cursor.fetchone()
        conn.commit()
        return new_pred

        
@app.route('/caregiver/<int:caregiver_id>/patients', methods=['GET'])
def get_caregiver_patients(caregiver_id):
    """Get all patients under this caregiver"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT u.user_id as patient_id, u.full_name, u.date_of_birth, u.gender,
                       u.phone_no, u.address, p.medical_notes, u.profile_photo,   -- added profile_photo
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
# Ensure this is imported at the top of server.py

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
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            
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
                
                prediction_score_val = forget_prob * 100.0
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
                    VALUES (%s, %s, %s, CURRENT_TIMESTAMP, %s::jsonb)
                    ON CONFLICT (patient_id) DO UPDATE SET
                        prediction_score = EXCLUDED.prediction_score,
                        risk_level = EXCLUDED.risk_level,
                        predicted_at = EXCLUDED.predicted_at,
                        features_used = EXCLUDED.features_used
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
    return jsonify({"status": "healthy", "database": db_status, "model": "loaded" if lstm_model else "not loaded"})

@app.route('/caregiver/<int:caregiver_id>/analytics_overview', methods=['GET'])
def get_analytics_overview(caregiver_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            
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
                    SELECT DISTINCT ON (patient_id) patient_id, risk_level, prediction_score
                    FROM ai_adherence_prediction
                    ORDER BY patient_id, predicted_at DESC
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

@app.route('/caregiver/<int:caregiver_id>/at_risk_patients', methods=['GET'])
def get_at_risk_patients(caregiver_id):
    """Return list of patients with their latest AI prediction (high/medium risk only)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT 
                    u.full_name AS name,
                    pc.medication_name AS medication,
                    a.risk_level,
                    a.prediction_score AS forget_probability,
                    COALESCE(a.features_used->>'temporal_pattern', 'Irregular pattern detected') AS temporal_pattern
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                JOIN prescription_config pc ON pc.patient_id = p.patient_id
                LEFT JOIN (
                    SELECT DISTINCT ON (patient_id) patient_id, risk_level, prediction_score, features_used
                    FROM ai_adherence_prediction
                    ORDER BY patient_id, predicted_at DESC
                ) a ON p.patient_id = a.patient_id
                WHERE p.caregiver_id = %s 
                  AND u.is_active = true
                  AND a.risk_level IN ('HIGH', 'MEDIUM')
                ORDER BY a.prediction_score DESC
                LIMIT 20
            ''', (caregiver_id,))
            patients = cursor.fetchall()
            cursor.close()
        return jsonify({"success": True, "data": patients})
    except Exception as e:
        print(f"At-risk patients error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# Add to server.py

@app.route('/iot_device/patient/<int:patient_id>', methods=['GET'])
def get_patient_device(patient_id):
    """Get IoT device info for a patient"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute('''
                SELECT device_id, device_serial, battery_level, last_active_timestamp
                FROM iot_device
                WHERE patient_id = %s
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
 