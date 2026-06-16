# server.py
from flask import Flask, jsonify
from flask_cors import CORS
from flask.json.provider import DefaultJSONProvider
import datetime
from scheduler_service import start_scheduler

import decimal

from db import init_db, get_db_connection
from services.ai_predictor import get_models

from routes.auth import auth_bp
from routes.patient import patient_bp
from routes.caregiver import caregiver_bp
from routes.medication import medication_bp
from routes.device import device_bp
from routes.analytics import analytics_bp

import os
import sys

# Only call tzset on Unix (Linux/macOS)
if sys.platform != 'win32':
    import time
    os.environ['TZ'] = 'Asia/Kuala_Lumpur'
    time.tzset()
else:
    # On Windows, system time must already be Malaysia time.
    print("Running on Windows: Please ensure your system time zone is set to 'Singapore/Malaysia Time (GMT+8)'")
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

# Register Blueprints
app.register_blueprint(auth_bp)
app.register_blueprint(patient_bp)
app.register_blueprint(caregiver_bp)
app.register_blueprint(medication_bp)
app.register_blueprint(device_bp)
app.register_blueprint(analytics_bp)

import logging

# Silence the default Werkzeug logger
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

from flask import request

_http_header_printed = False

@app.after_request
def log_request(response):
    global _http_header_printed
    if not _http_header_printed:
        print("\nHTTP Requests")
        print("-------------")
        print()
        _http_header_printed = True
        
    now = datetime.datetime.now().strftime('%H:%M:%S.%f')[:-3]
    method = request.method.ljust(4)
    path = request.path.ljust(30)
    status_code = response.status_code
    status_text = response.status.split(' ', 1)[1] if ' ' in response.status else ''
    
    print(f"{now} +08 {method} {path} {status_code} {status_text}", flush=True)
    return response

@app.route('/health', methods=['GET'])
def health_check():
    lstm_model, _ = get_models()
    try:
        with get_db_connection() as conn:
            pass # Just test connection retrieval
        db_status = "connected"
    except:
        db_status = "disconnected"
    return jsonify({"status": "healthy", "database": db_status, "model": "loaded" if lstm_model else "not loaded"})

# ==========================================
# 🚀 Run the Flask App
# ==========================================
if __name__ == '__main__':
    init_db()
    start_scheduler()
    
    print("\n" + "="*50)
    print("IoT-Based Smart Medical Kit API Server")
    print("="*50)
    print(f"Server running on: http://0.0.0.0:5000")
    print("="*50 + "\n")
    app.run(host='0.0.0.0', port=5000, debug=True, use_reloader=False)
