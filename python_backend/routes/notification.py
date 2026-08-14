# notification.py - Blueprint for notification-related API endpoints

from flask import Blueprint, request, jsonify

from models.notification_model import (
    get_patient_notifications,
    mark_single_reminder_read,
    mark_all_reminders_read as mark_all_reminders_read_model,
    insert_notification,
    mark_notification_as_read,
    get_caregiver_notifications as get_caregiver_notifications_model,
    get_caregiver_stock_notification_rows
)

# Create a Flask Blueprint for notification routes
notification_bp = Blueprint('notification', __name__)

# ==============================================================================
# 🧑‍⚕️ PATIENT NOTIFICATION ENDPOINTS
# ==============================================================================

# ---------------------- Mark Single Medication Reminders as Read ----------------------
@notification_bp.route('/patient/<int:patient_id>/reminders/read_single', methods=['PUT'])
def api_mark_single_reminder_read(patient_id):
    """
    Mark all reminders for a specific medication as read.
    Expects JSON body with 'medication_name'.
    """
    try:
        data = request.get_json()
        medication_name = data.get('medication_name')
        
        # Validate required field
        if not medication_name:
            return jsonify({"success": False, "message": "medication_name required"}), 400

        # Call model to mark reminders for this medication as read
        mark_single_reminder_read(patient_id, medication_name)
            
        return jsonify({"success": True, "message": f"Reminders for {medication_name} marked as read"})
    except Exception as e:
        print(f"Error marking single reminder read: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Notifications ----------------------
@notification_bp.route('/patient/<int:patient_id>/notifications', methods=['GET'])
def get_notifications(patient_id):
    """
    Fetch all in-app notifications for the patient.
    """
    try:
        notifications = get_patient_notifications(patient_id)
        return jsonify({"success": True, "data": notifications})
    except Exception as e:
        print(f"Get notifications error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Mark All Reminders as Read ----------------------
@notification_bp.route('/patient/<int:patient_id>/reminders/read', methods=['PUT'])
def api_mark_all_reminders_read(patient_id):
    """
    Mark all reminders for the patient as read (across all medications).
    """
    try:
        mark_all_reminders_read_model(patient_id)
        return jsonify({"success": True, "message": "All reminders marked as read"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Create In-App Notification ----------------------
@notification_bp.route('/notifications', methods=['POST'])
def create_notification():
    """
    Create a new in-app notification for a patient.
    Expects JSON body: patient_id, title, message, and optional type (default 'REMINDER').
    """
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        title = data.get('title')
        message = data.get('message')
        notif_type = data.get('type', 'REMINDER')

        # Validate required fields
        if not all([patient_id, title, message]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        insert_notification(patient_id, title, message, notif_type)

        return jsonify({"success": True, "message": "In-app notification saved successfully!"})
    except Exception as e:
        print(f"Create notification error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Mark Single Notification as Read ----------------------
@notification_bp.route('/notification/<int:notification_id>/read', methods=['PUT'])
def mark_notification_read(notification_id):
    """
    Mark a specific notification as read by its ID.
    """
    try:
        mark_notification_as_read(notification_id)
        return jsonify({"success": True, "message": "Notification marked as read"})
    except Exception as e:
        print(f"Mark notification read error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ==============================================================================
# 👨‍⚕️ CAREGIVER NOTIFICATION ENDPOINTS
# ==============================================================================

# ---------------------- Get Low Stock Alerts (Notifications) ----------------------
@notification_bp.route('/caregiver/<int:caregiver_id>/low_stock_alerts', methods=['GET'])
def get_low_stock_alerts(caregiver_id):
    """
    Return stock-related notifications for the caregiver.
    """
    try:
        rows = get_caregiver_stock_notification_rows(caregiver_id)
        return jsonify({"success": True, "data": rows})
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Stock Notifications (Alternative route) ----------------------
@notification_bp.route('/caregiver/<int:caregiver_id>/stock_notifications', methods=['GET'])
def get_stock_notifications(caregiver_id):
    """
    Similar to /low_stock_alerts; returns stock notifications.
    (Duplicate functionality, kept for compatibility.)
    """
    try:
        alerts = get_caregiver_stock_notification_rows(caregiver_id)
        return jsonify({"success": True, "data": alerts})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get In-App Notifications for Caregiver ----------------------
@notification_bp.route('/caregiver/<int:caregiver_id>/notifications', methods=['GET'])
def get_caregiver_notifications(caregiver_id):
    """
    Fetch all in-app notifications for the caregiver.
    """
    try:
        notifs = get_caregiver_notifications_model(caregiver_id)
        return jsonify({"success": True, "data": notifs})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Mark a Caregiver Notification as Read ----------------------
@notification_bp.route('/caregiver/notification/<int:notif_id>/read', methods=['PUT'])
def mark_caregiver_notification_read(notif_id):
    """
    Mark a specific notification as read by its ID.
    """
    try:
        mark_notification_as_read(notif_id)
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
