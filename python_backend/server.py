# server.py - Entry point for the IoT Smart Medical Kit Backend
from flask import Flask, jsonify
from flask_cors import CORS
from flask.json.provider import DefaultJSONProvider
import datetime
from scheduler_service import start_scheduler  # Background task scheduler for reminders

import decimal  # Required for handling high-precision database numeric types

# Database and AI imports
from db import init_db, get_db_connection
from services.ai_predictor import get_models

# Import modular route blueprints (organized by domain)
from routes.auth import auth_bp
from routes.patient import patient_bp
from routes.caregiver import caregiver_bp
from routes.medication import medication_bp
from routes.device import device_bp
from routes.analytics import analytics_bp
from routes.notification import notification_bp

import os
import sys

# ==========================================
# 🌐 1. Timezone Configuration
# ==========================================
# Force the server to use Malaysia Time (UTC+8) for all date/time operations.
# This is critical for medication schedules (e.g., "Take at 10:00 AM MYT").

# Only call tzset on Unix systems (Linux/macOS)
if sys.platform != 'win32':
    import time
    os.environ['TZ'] = 'Asia/Kuala_Lumpur'  # Set environment variable
    time.tzset()  # Apply the new timezone to Python's runtime
else:
    # On Windows, tzset() is not available. We just print a warning.
    print("Running on Windows: Please ensure your system time zone is set to 'Singapore/Malaysia Time (GMT+8)'")

# ==========================================
# 📦 2. Custom JSON Serializer
# ==========================================
class CustomJSONProvider(DefaultJSONProvider):
    """
    Overrides Flask's default JSON encoding to support custom Python types.
    This prevents errors like "datetime is not JSON serializable".
    """
    def default(self, obj):
        # Convert datetime objects to ISO-8601 strings (e.g., "2026-06-17T14:30:00")
        if isinstance(obj, (datetime.datetime, datetime.date)):
            return obj.isoformat()
        # Convert high-precision decimals (from MySQL/PostgreSQL) to floats for JSON
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        # For any other unknown types, fall back to the parent class implementation
        return super().default(obj)

# ==========================================
# 🚀 3. Flask App Initialization
# ==========================================
app = Flask(__name__)
app.json = CustomJSONProvider(app)  # Attach our custom JSON provider
CORS(app)  # Enable Cross-Origin Resource Sharing (allows mobile/web apps from different ports to call this API)

# ==========================================
# 🗺️ 4. Register Blueprints (Modular Routes)
# ==========================================
# These group all endpoints by feature.
# For example, all `/auth/*` endpoints are defined in `routes/auth.py`.
app.register_blueprint(auth_bp)
app.register_blueprint(patient_bp)
app.register_blueprint(caregiver_bp)
app.register_blueprint(medication_bp)
app.register_blueprint(device_bp)
app.register_blueprint(analytics_bp)
app.register_blueprint(notification_bp)

# ==========================================
# 🧹 5. Logging Configuration
# ==========================================
import logging

# Silence the default verbose Werkzeug (Flask's dev server) access logs.
# We only want to see our own custom formatted logs below.
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

from flask import request

# ==========================================
# 🖨️ 6. Custom Request Logging Middleware
# ==========================================
_http_header_printed = False  # Flag to print the header only once

@app.after_request
def log_request(response):
    """
    Runs automatically after every HTTP request.
    Prints a clean, formatted log line with timestamp, method, path, and status.
    """
    global _http_header_printed
    # Print the table header only on the very first request
    if not _http_header_printed:
        print("\nHTTP Requests")
        print("-------------")
        print()
        _http_header_printed = True
        
    # Format current time to HH:MM:SS.mmm (Malaysia time)
    now = datetime.datetime.now().strftime('%H:%M:%S.%f')[:-3]
    method = request.method.ljust(4)          # e.g., "GET " or "POST"
    path = request.path.ljust(30)             # e.g., "/health"
    status_code = response.status_code        # e.g., 200, 404, 500
    # Extract the human-readable status text (e.g., "OK", "Not Found")
    status_text = response.status.split(' ', 1)[1] if ' ' in response.status else ''
    
    # Print to console with +08 timezone indicator
    print(f"{now} +08 {method} {path} {status_code} {status_text}", flush=True)
    return response  # Must return the response for Flask to send it to the client

# ==========================================
# ❤️ 7. Health Check Endpoint
# ==========================================
@app.route('/health', methods=['GET'])
def health_check():
    """
    Simple liveness/readiness probe for monitoring systems (Docker/Kubernetes).
    Checks database connectivity and AI model loading status.
    """
    # Check if the LSTM/RF models are loaded
    lstm_model, _ = get_models()
    
    # Try to get a database connection to verify DB is responsive
    try:
        with get_db_connection() as conn:
            pass  # Just testing if we can acquire a connection
        db_status = "connected"
    except:
        db_status = "disconnected"
        
    return jsonify({
        "status": "healthy", 
        "database": db_status, 
        "model": "loaded" if lstm_model else "not loaded"
    })

# ==========================================
# 🏁 8. Main Entry Point (Run the Server)
# ==========================================
if __name__ == '__main__':
    # Step 1: Initialize the database (create tables if they don't exist)
    init_db()
    
    # Step 2: Start the background scheduler.
    # This runs every minute to check for upcoming medications and generate
    # app reminders / hardware triggers (defined in scheduler_service.py).
    start_scheduler()
    
    # Step 3: Print a beautiful startup banner
    print("\n" + "="*50)
    print("IoT-Based Smart Medical Kit API Server")
    print("="*50)
    print(f"Server running on: http://0.0.0.0:5000")
    print("="*50 + "\n")
    
    # Step 4: Launch the Flask development server.
    # host='0.0.0.0' makes it accessible from any device on the network.
    # debug=True enables auto-reload and detailed error pages (remove in production!).
    # use_reloader=False is critical because the scheduler runs in the main thread;
    # enabling the reloader would duplicate the scheduler process.
    app.run(host='0.0.0.0', port=5000, debug=True, use_reloader=False)
