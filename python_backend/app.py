# app.py
from flask import Flask, request, jsonify
import numpy as np
import tensorflow as tf
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime

app = Flask(__name__)

# ==========================================
# 💾 1. Database Configuration (PostgreSQL)
# ==========================================
DB_CONFIG = {
    'host': 'localhost',
    'database': 'fyp_db',  # Database name created in pgAdmin
    'user': 'postgres',               # Default PostgreSQL admin user
    'password': '123456',      # ⚠️ Replace with your PostgreSQL password
    'port': 5433
}

def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)

def init_db():
    conn = get_db_connection()
    # If we can successfully get `conn`, it means the username/password are correct and PostgreSQL is running!
    conn.close() 
    print("🐘 PostgreSQL connected successfully! (Tables already exist)")
# ==========================================
# 🧠 2. LSTM Model Setup
# ==========================================
print("🧠 Loading LSTM model...")
# Note: In production, ensure 'smart_pill_lstm_model.h5' is present.
try:
    model = tf.keras.models.load_model('smart_pill_lstm_model.h5')
except:
    print("⚠️ Model file not found. Prediction API will use mock logic.")
    model = None

# Mapping categorical values to numeric
days_map = {
    'Monday': 0, 'Tuesday': 1, 'Wednesday': 2,
    'Thursday': 3, 'Friday': 4, 'Saturday': 5, 'Sunday': 6
}

times_map = {
    'Afternoon': 0, 'Evening': 1, 'Morning': 2
}

# ==========================================
# 📡 3. API Endpoints
# ==========================================

# 👑 API 1: Used by Flutter App → Predict forgetfulness probability
@app.route('/predict', methods=['POST'])
def predict_forgetfulness():
    try:
        data = request.get_json()

        age = data['age']
        day = days_map.get(data['day_of_week'], 0)
        time = times_map.get(data['time_of_day'], 0)
        history = data['history']

        input_data = []
        for past_status in history:
            feature_row = [
                age / 100.0,
                day / 6.0,
                time / 2.0,
                past_status
            ]
            input_data.append(feature_row)

        input_array = np.array([input_data])
        prediction = model.predict(input_array)
        forget_prob = float(prediction[0][0])

        return jsonify({
            "success": True,
            "forget_probability": round(forget_prob, 2),
            "warning_level": "High" if forget_prob > 0.6 else "Low",
            "message": "High chance of forgetting medication. Please send a reminder!"
                      if forget_prob > 0.6 else "Patient condition is stable."
        })

    except Exception as e:
        return jsonify({"success": False, "error": str(e)})

# 📝 API 2: Used by ESP32 → Save medication log into database
@app.route('/add_log', methods=['POST'])
def add_log():
    try:
        data = request.get_json()

        conn = get_db_connection()
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
            "message": "Log successfully saved to PostgreSQL!"
        })

    except Exception as e:
        return jsonify({"success": False, "error": str(e)})

# 📱 API 3: Used by Flutter App → Retrieve medication history
@app.route('/get_logs', methods=['GET'])
def get_logs():
    try:
        conn = get_db_connection()

        # Use RealDictCursor to return results as JSON-like objects
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Get latest 20 records
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
        return jsonify({"success": False, "error": str(e)})



        # 🔐 API 4: Login Authentication
# 🔐 API 4: Login Authentication (Supports both Patient and Caregiver tables)
@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')

        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        # Step 1: Try to find the user in the patient table
        # Note: The patient table has a column called full_name
        cursor.execute('''
            SELECT patient_id as id, email, full_name as name 
            FROM patient 
            WHERE email = %s AND password = %s
        ''', (email, password))
        
        user = cursor.fetchone()

        if user:
            # If found in patient table, mark role as 'patient'
            user['role'] = 'patient'
        else:
            # Step 2: If not found in patient table, try the caregiver table
            # Note: The caregiver table has a column called fullname (no underscore)
            cursor.execute('''
                SELECT caregiver_id as id, email, fullname as name 
                FROM caregiver 
                WHERE email = %s AND password = %s
            ''', (email, password))
            
            user = cursor.fetchone()
            if user:
                # If found in caregiver table, mark role as 'caregiver'
                user['role'] = 'caregiver'

        cursor.close()
        conn.close()

        # Step 3: Return the result to Flutter
        if user:
            return jsonify({
                "success": True,
                "message": f"Login successful! Welcome {user['name']}",
                "user": user 
            })
        else:
            return jsonify({
                "success": False,
                "message": "Login failed: Incorrect email or password!"
            })

    except Exception as e:
        return jsonify({"success": False, "error": str(e)})

# 📝 API 5: User Registration (Supports both Patient and Caregiver)
@app.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        role = data.get('role', 'Patient').lower() # 'patient' or 'caregiver'
        email = data.get('email')
        password = data.get('password')
        name = data.get('fullname') or data.get('full_name')
        gender = data.get('gender', 'Other')
        phone = data.get('phone_no')
        dob = data.get('date_of_birth')
        address = data.get('address')

        conn = get_db_connection()
        cursor = conn.cursor()

        if role == 'caregiver':
            # Insert into caregiver table
            cursor.execute('''
                INSERT INTO caregiver (fullname, email, password, gender, phone_no, date_of_birth, address)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            ''', (name, email, password, gender, phone, dob, address))
        else:
            # Insert into patient table
            # Note: caregiver_id is NOT NULL in your schema. 
            # We'll use caregiver_id 1 as a default for now if not provided.
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

    except Exception as e:
        return jsonify({"success": False, "error": str(e)})
# ==========================================
# 🚀 Run the Flask App
# ==========================================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)