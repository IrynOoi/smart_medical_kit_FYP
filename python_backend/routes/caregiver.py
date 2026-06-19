# caregiver.py - Blueprint for caregiver-related API endpoints

import os
from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename

# Import model functions for adherence, user profiles, and notifications
from models.adherence_model import (
    get_all_recent_logs,
    get_caregiver_overview_stats,
    get_caregiver_chart_data,
    get_caregiver_alerts,
    get_caregiver_analytics_overview
)
from models.user import (
    get_caregiver_profile,
    update_caregiver_profile,
    get_caregiver_patients_list
)
from models.notification_model import (
    get_caregiver_notifications as get_caregiver_notifications_model,
    get_caregiver_stock_alert_rows,
    get_caregiver_stock_notification_rows,
    mark_notification_as_read,
    sync_caregiver_stock_notifications,
)

# Create Blueprint for caregiver routes
caregiver_bp = Blueprint('caregiver', __name__)


# ---------------------- Get All Recent Adherence Logs for Caregiver's Patients ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/all_recent_logs', methods=['GET'])
def get_all_recent_logs_route(caregiver_id):
    """
    Retrieve the most recent adherence logs from all patients under this caregiver.
    Optional query param: limit (default 20).
    """
    try:
        limit = request.args.get('limit', default=20, type=int)
        logs = get_all_recent_logs(caregiver_id, limit)
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Overview Statistics for Caregiver Dashboard ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/overview_stats', methods=['GET'])
def get_caregiver_overview(caregiver_id):
    """
    Return summary statistics: taken/missed/pending doses, total patients,
    low stock count, total prescriptions, distinct medications, and adherence score.
    """
    try:
        # Fetch raw stats from model
        stats, total_patients, low_stock_count, total_rx, distinct_meds = get_caregiver_overview_stats(caregiver_id)

        # Compute adherence score (taken / (taken+missed))
        total_doses = (stats['taken_count'] or 0) + (stats['missed_count'] or 0)
        adherence_score = int((stats['taken_count'] or 0) / total_doses * 100) if total_doses > 0 else 100

        return jsonify({"success": True, "data": {
            "taken_count": stats['taken_count'] or 0,
            "missed_count": stats['missed_count'] or 0,
            "pending_count": stats['pending_count'] or 0,
            "total_patients": total_patients,
            "low_stock_count": low_stock_count,
            "total_doses": total_doses,
            "adherence_score": adherence_score,
            "total_prescriptions": total_rx,
            "distinct_medications": distinct_meds
        }})
    except Exception as e:
        print(f"Get caregiver overview error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get At-Risk Patients (AI-based) ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/at_risk_patients', methods=['GET'])
def get_at_risk_patients(caregiver_id):
    """
    Retrieve a list of patients flagged as 'at risk' based on AI predictions.
    """
    try:
        from models.analytics_model import get_caregiver_at_risk_patients
        patients = get_caregiver_at_risk_patients(caregiver_id)
        return jsonify({"success": True, "data": patients})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Chart Data (Adherence over Period) ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/chart_data', methods=['GET'])
def get_chart_data(caregiver_id):
    """
    Return adherence data (taken/missed counts) aggregated by period:
      - 'Day'  : 24 hours (0-23)
      - 'Week' : 7 days (1-7)
      - 'Month': 4 weeks (1-4)
    The model returns rows with taken/missed per unit; we reshape into arrays.
    """
    try:
        period = request.args.get('period', 'Week')  # Default to Week
        
        # Get raw data from model (period-specific query)
        rows = get_caregiver_chart_data(caregiver_id, period)

        # Initialize empty arrays for the chosen period
        if period == 'Week':
            taken = [0.0] * 7
            missed = [0.0] * 7
            for row in rows:
                idx = int(row['dow']) - 1   # dow is 1-7, convert to 0-6
                if 0 <= idx < 7:
                    taken[idx] = float(row['taken'])
                    missed[idx] = float(row['missed'])
        elif period == 'Month':
            taken = [0.0] * 4
            missed = [0.0] * 4
            for row in rows:
                w = int(row['week_ago'])   # week_ago is 1-4
                if 1 <= w <= 4:
                    taken[4-w] = float(row['taken'])   # reverse order (most recent first)
                    missed[4-w] = float(row['missed'])
        elif period == 'Day':
            taken = [0.0] * 24
            missed = [0.0] * 24
            for row in rows:
                hour = int(row['hour'])
                if 0 <= hour < 24:
                    taken[hour] = float(row['taken'])
                    missed[hour] = float(row['missed'])
        # (No else needed; if unknown period, we return empty arrays)

        return jsonify({"success": True, "data": {"taken": taken, "missed": missed}})
        
    except Exception as e:
        print(f"Chart Data Error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Recent Alerts (e.g., missed doses, low stock) ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/recent_alerts', methods=['GET'])
def get_recent_alerts(caregiver_id):
    """
    Fetch the most recent alerts for this caregiver.
    Optional limit query param (default 20).
    """
    try:
        limit = request.args.get('limit', default=20, type=int)
        alerts = get_caregiver_alerts(caregiver_id, limit)
        return jsonify({"success": True, "data": alerts})
    except Exception as e:
        print(f"Get caregiver alerts error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Low Stock Alerts (Notifications) ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/low_stock_alerts', methods=['GET'])
def get_low_stock_alerts(caregiver_id):
    """
    Return stock-related notifications for the caregiver.
    """
    try:
        from models.notification_model import get_caregiver_stock_notification_rows
        rows = get_caregiver_stock_notification_rows(caregiver_id)
        return jsonify({"success": True, "data": rows})
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Stock Notifications (Alternative route) ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/stock_notifications', methods=['GET'])
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


# ---------------------- Get List of Patients Assigned to Caregiver ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/patients', methods=['GET'])
def get_caregiver_patients(caregiver_id):
    """
    Return patients under this caregiver. Optional query param 'show':
      - 'active' (default) : only active patients
      - 'all'             : all patients (including inactive)
    """
    try:
        status = request.args.get('show', 'active')
        patients = get_caregiver_patients_list(caregiver_id, status)
        return jsonify({"success": True, "data": patients})
    except Exception as e:
        print(f"Error in get_caregiver_patients: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Caregiver Profile ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>', methods=['GET'])
def get_caregiver_profile_route(caregiver_id):
    """
    Retrieve full caregiver profile (user details).
    """
    try:
        caregiver = get_caregiver_profile(caregiver_id)
        if caregiver:
            return jsonify({"success": True, "data": caregiver})
        else:
            return jsonify({"success": False, "error": "Caregiver not found"}), 404
    except Exception as e:
        print(f"Get caregiver profile error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Update Caregiver Profile (with Photo Upload) ----------------------
@caregiver_bp.route('/update_caregiver/<int:caregiver_id>', methods=['PUT'])
def update_caregiver(caregiver_id):
    """
    Update caregiver profile fields. Supports multipart/form-data with optional profile_photo file.
    Fields: full_name, phone_no, address, email, gender, date_of_birth.
    """
    try:
        # Extract form fields
        full_name = request.form.get('full_name')
        phone_no = request.form.get('phone_no')
        address = request.form.get('address')
        email = request.form.get('email')
        gender = request.form.get('gender')
        date_of_birth = request.form.get('date_of_birth')

        photo_url = None
        # Handle file upload if present
        if 'profile_photo' in request.files:
            file = request.files['profile_photo']
            if file.filename != '':
                # Secure filename and prepend caregiver_id
                filename = secure_filename(f"caregiver_{caregiver_id}_{file.filename}")
                filepath = os.path.join('static', 'profiles')
                os.makedirs(filepath, exist_ok=True)
                file.save(os.path.join(filepath, filename))
                # Build absolute URL for the photo
                photo_url = f"{request.host_url}static/profiles/{filename}"

        # Update profile via model
        update_caregiver_profile(caregiver_id, full_name, phone_no, address, email, gender, date_of_birth, photo_url)
            
        return jsonify({"success": True, "message": "Profile updated successfully", "photo_url": photo_url})
    except Exception as e:
        print(f"Update caregiver error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get In-App Notifications for Caregiver ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/notifications', methods=['GET'])
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
@caregiver_bp.route('/caregiver/notification/<int:notif_id>/read', methods=['PUT'])
def mark_caregiver_notification_read(notif_id):
    """
    Mark a specific notification as read by its ID.
    """
    try:
        mark_notification_as_read(notif_id)
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Analytics Overview (AI Predictions Summary) ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/analytics_overview', methods=['GET'])
def get_analytics_overview(caregiver_id):
    """
    Return summary analytics for the caregiver:
      - overall_adherence_prediction (average AI score across patients, rounded to 2 decimals)
      - high_risk_patients count
      - medium_risk_patients count
      - total_analyzed patients
    This endpoint also prints debugging info to the console.
    """
    try:
        total, stats = get_caregiver_analytics_overview(caregiver_id)

        analysed_count = stats.get('analysed_patients', 0)
        total_score = float(stats.get('total_score') or 0.0)

        # Compute average score; if no patients, default to 0
        if total == 0:
            avg_score = 0.00
        else:
            avg_score = stats['avg_prediction_score']
            if avg_score is None:
                avg_score = 85.00   # fallback default
            else:
                avg_score = float(avg_score)
        
        # Round to 2 decimal places for cleaner display
        final_forecast = round(avg_score, 2)
        
        # Print debugging information to the console
        print("\n" + "="*40)
        print(f"📊 SYSTEM FORECAST CALCULATION (Caregiver {caregiver_id})")
        print(f"   Total Score: {total_score}")
        print(f"   Analysed Patient: {analysed_count}")
        print(f"   Final Rounded Score:   {final_forecast:.2f}%")
        print("="*40 + "\n")

        return jsonify({
            "success": True,
            "data": {
                "overall_adherence_prediction": final_forecast,
                "high_risk_patients": stats['high_risk_patients'] or 0,
                "medium_risk_patients": stats['medium_risk_patients'] or 0,
                "total_analyzed": analysed_count,
            }
        })
    except Exception as e:
        print(f"Analytics overview error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Available Patients (Not Yet Linked to This Caregiver) ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/available_patients', methods=['GET'])
def get_available_patients_route(caregiver_id):
    """
    Return patients who are not assigned to this caregiver (or to any caregiver).
    Optional query param 'status' can filter patients by active/inactive/all (default 'all').
    Used for linking new patients.
    """
    try:
        status = request.args.get('status', 'all')
        from models.user import get_available_patients
        patients = get_available_patients(caregiver_id, status_filter=status)
        return jsonify({"success": True, "data": patients})
    except Exception as e:
        print(f"Error getting available patients: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Link a Patient to This Caregiver ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/link_patient', methods=['POST'])
def link_patient_route(caregiver_id):
    """
    Assign a patient to this caregiver.
    Expects JSON with 'patient_id'.
    """
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        if not patient_id:
            return jsonify({"success": False, "message": "patient_id required"}), 400
            
        from models.user import link_patient_to_caregiver
        link_patient_to_caregiver(caregiver_id, patient_id)
        return jsonify({"success": True, "message": "Patient linked successfully"})
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Deactivate Caregiver Account (Soft Delete) ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/deactivate', methods=['PUT'])
def deactivate_caregiver(caregiver_id):
    """
    Soft‑delete a caregiver account (set is_active = False).
    """
    try:
        from models.user import soft_delete_caregiver
        soft_delete_caregiver(caregiver_id)
        return jsonify({"success": True, "message": "Caregiver account deactivated"})
    except Exception as e:
        print(f"Deactivate caregiver error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Unlink a Patient from This Caregiver ----------------------
@caregiver_bp.route('/caregiver/<int:caregiver_id>/unlink_patient/<int:patient_id>', methods=['DELETE'])
def unlink_patient_route(caregiver_id, patient_id):
    """
    Remove the association between a patient and this caregiver (set patient.cg_id = NULL).
    """
    try:
        from models.user import unlink_patient_from_caregiver
        unlink_patient_from_caregiver(caregiver_id, patient_id)
        return jsonify({"success": True, "message": "Patient unlinked successfully"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500