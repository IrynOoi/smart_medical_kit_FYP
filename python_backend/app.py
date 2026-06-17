# app.py
#backend codes- Complete Flask Backend for IoT-Based Smart Medical Kit
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask.json.provider import DefaultJSONProvider
import numpy as np
import tensorflow as tf
import psycopg2
from psycopg2.extras import RealDictCursor
import datetime
import os

class CustomJSONProvider(DefaultJSONProvider):
    def default(self, obj):
        if isinstance(obj, (datetime.datetime, datetime.date)):
            return obj.isoformat()
        return super().default(obj)

app = Flask(__name__)
app.json = CustomJSONProvider(app)
CORS(app)  # Enable CORS for all routes

# ==========================================
# 💾 1. Database Configuration (PostgreSQL)
# ==========================================
DB_CONFIG = {
    'host': 'localhost',
    'database': 'fyp_db',
    'user': 'postgres',
    'password': '123456',
    'port': 5433
}

def get_db_connection():
    """Create and return a database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        return None

def init_db():
    """Test database connection"""
    conn = get_db_connection()
    if conn:
        conn.close()
        print("PostgreSQL connected successfully!")
    else:
        print("Failed to connect to PostgreSQL")

# ==========================================
# 2. LSTM Model Setup
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

# Mapping categorical values to numeric
days_map = {
    'Monday': 0, 'Tuesday': 1, 'Wednesday': 2,
    'Thursday': 3, 'Friday': 4, 'Saturday': 5, 'Sunday': 6
}

times_map = {
    'Morning': 0, 'Afternoon': 1, 'Evening': 2
}

# ==========================================
# 📡 3. API Endpoints
# ==========================================

# ------------------------------------------------------------
# 🔐 AUTHENTICATION ENDPOINTS
# ------------------------------------------------------------

@app.route('/login', methods=['POST'])
def login():
    """Authenticate user (Patient or Caregiver)"""
    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')

        if not email or not password:
            return jsonify({
                "success": False,
                "message": "Email and password are required"
            }), 400

        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Check patient table (column: full_name)
        cursor.execute('''
            SELECT patient_id as id, email, full_name as name, 'patient' as role
            FROM patient 
            WHERE email = %s AND password = %s
        ''', (email, password))
        
        user = cursor.fetchone()

        # If not found in patient, check caregiver table (column: fullname)
        if not user:
            cursor.execute('''
                SELECT caregiver_id as id, email, fullname as name, 'caregiver' as role
                FROM caregiver 
                WHERE email = %s AND password = %s
            ''', (email, password))
            user = cursor.fetchone()

        cursor.close()
        conn.close()

        if user:
            return jsonify({
                "success": True,
                "message": f"Login successful! Welcome {user['name']}",
                "user": user
            })
        else:
            return jsonify({
                "success": False,
                "message": "Invalid email or password"
            }), 401

    except Exception as e:
        print(f"Login error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/register', methods=['POST'])
def register():
    """Register new user (Patient or Caregiver)"""
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
            return jsonify({
                "success": False,
                "message": "Email, password, and name are required"
            }), 400

        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
        cursor = conn.cursor()

        if role == 'caregiver':
            cursor.execute('''
                INSERT INTO caregiver (fullname, email, password, gender, phone_no, date_of_birth, address)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            ''', (name, email, password, gender, phone, dob, address))
        else:
            caregiver_id = data.get('caregiver_id', 1)
            cursor.execute('''
                INSERT INTO patient (full_name, caregiver_id, email, password, gender, phone_no, date_of_birth, address)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ''', (name, caregiver_id, email, password, gender, phone, dob, address))

        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({
            "success": True,
            "message": f"Registration successful as {role.capitalize()}!"
        })

    except psycopg2.IntegrityError as e:
        return jsonify({"success": False, "error": "Email already exists"}), 409
    except Exception as e:
        print(f"Registration error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------
# 👤 PATIENT ENDPOINTS
# ------------------------------------------------------------

@app.route('/patient/<int:patient_id>', methods=['GET'])
def get_patient(patient_id):
    """Get patient details by ID"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute('''
            SELECT patient_id, caregiver_id, full_name, date_of_birth, gender, address, 
                   medical_notes, email, phone_no, is_active, created_at, updated_at
            FROM patient 
            WHERE patient_id = %s
        ''', (patient_id,))
        
        patient = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if patient:
            return jsonify({
                "success": True,
                "data": patient
            })
        else:
            return jsonify({
                "success": False,
                "error": "Patient not found"
            }), 404
            
    except Exception as e:
        print(f"Get patient error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/prescriptions', methods=['GET'])
def get_patient_prescriptions(patient_id):
    """Get all prescriptions for a patient"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute('''
            SELECT prescription_id, patient_id, medication_name, dosage_tablet, 
                   current_inventory, refill_threshold, 
                   start_date, end_date, created_at, updated_at, device_id
            FROM prescription_config 
            WHERE patient_id = %s AND (end_date IS NULL OR end_date >= CURRENT_DATE)
            ORDER BY start_date ASC
        ''', (patient_id,))
        
        prescriptions = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return jsonify({
            "success": True,
            "data": prescriptions
        })
        
    except Exception as e:
        print(f"Get prescriptions error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/adherence_stats', methods=['GET'])
def get_adherence_stats(patient_id):
    """Get adherence statistics for a patient (last 7 days)"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
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
        conn.close()
        
        taken = stats['taken_count'] or 0
        missed = stats['missed_count'] or 0
        total = taken + missed
        score = int((taken / total) * 100) if total > 0 else 100
        
        return jsonify({
            "success": True,
            "data": {
                "taken_count": taken,
                "missed_count": missed,
                "upcoming_count": stats['upcoming_count'] or 0,
                "adherence_score": score
            }
        })
        
    except Exception as e:
        print(f"Get adherence stats error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/adherence_logs', methods=['GET'])
def get_adherence_logs(patient_id):
    """Get adherence logs for a patient"""
    try:
        limit = request.args.get('limit', default=20, type=int)
        
        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
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
        conn.close()
        
        return jsonify({
            "success": True,
            "data": logs
        })
        
    except Exception as e:
        print(f"Get adherence logs error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/notifications', methods=['GET'])
def get_notifications(patient_id):
    """Get notifications for a patient"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute('''
            SELECT notification_id, patient_id, title, message, is_read, created_at
            FROM notifications 
            WHERE patient_id = %s
            ORDER BY created_at DESC
            LIMIT 20
        ''', (patient_id,))
        
        notifications = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return jsonify({
            "success": True,
            "data": notifications
        })
        
    except Exception as e:
        print(f"Get notifications error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/patient/<int:patient_id>/ai_prediction', methods=['GET'])
def get_ai_prediction(patient_id):
    """Get AI prediction for a patient"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute('''
            SELECT ad_id, patient_id, prediction_score, risk_level, predicted_at, features_used
            FROM ai_adherence_prediction 
            WHERE patient_id = %s
            ORDER BY predicted_at DESC
            LIMIT 1
        ''', (patient_id,))
        
        prediction = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if prediction:
            return jsonify({
                "success": True,
                "data": prediction
            })
        else:
            return jsonify({
                "success": True,
                "data": {
                    "prediction_score": 85.5,
                    "risk_level": "LOW"
                }
            })
            
    except Exception as e:
        print(f"Get AI prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------
# 💊 MEDICATION ENDPOINTS
# ------------------------------------------------------------

@app.route('/record_medication', methods=['POST'])
def record_medication():
    """Record that a medication has been taken"""
    try:
        data = request.get_json()
        prescription_id = data.get('prescription_id')
        device_id = data.get('device_id')

        if not prescription_id or not device_id:
            return jsonify({
                "success": False,
                "message": "prescription_id and device_id are required"
            }), 400

        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
        cursor = conn.cursor()
        
        # Update the adherence log
        cursor.execute('''
            UPDATE adherence_logs 
            SET status = 'TAKEN', 
                dispensed_time = CURRENT_TIMESTAMP,
                recorded_at = CURRENT_TIMESTAMP
            WHERE prescription_id = %s 
            AND device_id = %s 
            AND status = 'PENDING'
            AND DATE(scheduled_time) = CURRENT_DATE
        ''', (prescription_id, device_id))
        
        # Update inventory
        cursor.execute('''
            UPDATE prescription_config 
            SET current_inventory = current_inventory - 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE prescription_id = %s AND current_inventory > 0
        ''', (prescription_id,))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            "success": True,
            "message": "Medication recorded successfully!"
        })
        
    except Exception as e:
        print(f"Record medication error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/predict', methods=['POST'])
def predict_forgetfulness():
    """AI prediction for medication forgetfulness"""
    try:
        data = request.get_json()
        
        age = data.get('age')
        day = days_map.get(data.get('day_of_week', 'Monday'), 0)
        time = times_map.get(data.get('time_of_day', 'Morning'), 0)
        history = data.get('history', [1, 1, 1])

        if model is None:
            # Mock prediction if model not available
            forget_prob = 0.35
        else:
            input_data = []
            for past_status in history[-3:]:  # Use last 3 history values
                feature_row = [
                    age / 100.0,
                    day / 6.0,
                    time / 2.0,
                    float(past_status)
                ]
                input_data.append(feature_row)
            
            # Pad if less than 3 entries
            while len(input_data) < 3:
                input_data.insert(0, [age / 100.0, day / 6.0, time / 2.0, 1.0])
            
            input_array = np.array([input_data])
            prediction = model.predict(input_array)
            forget_prob = float(prediction[0][0])

        warning_level = "HIGH" if forget_prob > 0.6 else "MEDIUM" if forget_prob > 0.3 else "LOW"
        message = "High chance of forgetting medication. Send reminder!" if forget_prob > 0.6 else \
                  "Moderate risk. Monitor patient carefully." if forget_prob > 0.3 else \
                  "Patient adherence is stable."

        return jsonify({
            "success": True,
            "forget_probability": round(forget_prob, 2),
            "warning_level": warning_level,
            "message": message
        })

    except Exception as e:
        print(f"Prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------
# 📝 ESP32 ENDPOINTS
# ------------------------------------------------------------

@app.route('/add_log', methods=['POST'])
def add_log():
    """Add medication log from ESP32 device"""
    try:
        data = request.get_json()
        
        required_fields = ['patient_id', 'age', 'day_of_week', 'time_of_day', 'status']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    "success": False,
                    "error": f"Missing required field: {field}"
                }), 400

        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
        cursor = conn.cursor()

        cursor.execute('''
            INSERT INTO medication_logs (patient_id, age, day_of_week, time_of_day, status)
            VALUES (%s, %s, %s, %s, %s)
        ''', (
            data['patient_id'],
            data['age'],
            data['day_of_week'],
            data['time_of_day'],
            data['status']
        ))

        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({
            "success": True,
            "message": "Log saved successfully!"
        })

    except Exception as e:
        print(f"Add log error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/get_logs', methods=['GET'])
def get_logs():
    """Get medication logs for display"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        cursor.execute('''
            SELECT * FROM medication_logs
            ORDER BY timestamp DESC
            LIMIT 20
        ''')

        logs = cursor.fetchall()
        cursor.close()
        conn.close()

        return jsonify({
            "success": True,
            "data": logs
        })

    except Exception as e:
        print(f"Get logs error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------
# 🔔 NOTIFICATION ENDPOINTS
# ------------------------------------------------------------

@app.route('/notification/<int:notification_id>/read', methods=['PUT'])
def mark_notification_read(notification_id):
    """Mark a notification as read"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({"success": False, "error": "Database connection failed"}), 500
            
        cursor = conn.cursor()
        
        cursor.execute('''
            UPDATE notifications 
            SET is_read = TRUE
            WHERE notification_id = %s
        ''', (notification_id,))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            "success": True,
            "message": "Notification marked as read"
        })
        
    except Exception as e:
        print(f"Mark notification read error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ------------------------------------------------------------
# 🏥 HEALTH CHECK ENDPOINT
# ------------------------------------------------------------

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "database": "connected" if get_db_connection() else "disconnected",
        "model": "loaded" if model else "not loaded"
    })


# ------------------------------------------------------------
# 🚀 Run the Flask App
# ------------------------------------------------------------
if __name__ == '__main__':
    init_db()
    print("\n" + "="*50)
    print("IoT-Based Smart Medical Kit API Server")
    print("="*50)
    print(f"Server running on: http://0.0.0.0:5000")
    print(f"Available endpoints:")
    print(f"   POST   /login")
    print(f"   POST   /register")
    print(f"   GET    /patient/<id>")
    print(f"   GET    /patient/<id>/prescriptions")
    print(f"   GET    /patient/<id>/adherence_stats")
    print(f"   GET    /patient/<id>/adherence_logs")
    print(f"   GET    /patient/<id>/notifications")
    print(f"   GET    /patient/<id>/ai_prediction")
    print(f"   POST   /record_medication")
    print(f"   POST   /predict")
    print(f"   POST   /add_log")
    print(f"   GET    /get_logs")
    print(f"   GET    /health")
    print("="*50 + "\n")
    
    app.run(host='0.0.0.0', port=5000, debug=True)