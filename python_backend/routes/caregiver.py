#caregiver.py
import os
from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
from models.adherence_model import get_all_recent_logs, get_caregiver_overview_stats, get_caregiver_chart_data, get_caregiver_alerts, get_caregiver_analytics_overview
from models.user import get_caregiver_profile, update_caregiver_profile, get_caregiver_patients_list
from models.notification_model import (
    get_caregiver_notifications as get_caregiver_notifications_model,
    get_caregiver_stock_alert_rows,
    get_caregiver_stock_notification_rows,
    mark_notification_as_read,
    sync_caregiver_stock_notifications,
)

caregiver_bp = Blueprint('caregiver', __name__)

@caregiver_bp.route('/caregiver/<int:caregiver_id>/all_recent_logs', methods=['GET'])
def get_all_recent_logs_route(caregiver_id):
    try:
        limit = request.args.get('limit', default=20, type=int)
        logs = get_all_recent_logs(caregiver_id, limit)
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@caregiver_bp.route('/caregiver/<int:caregiver_id>/overview_stats', methods=['GET'])
def get_caregiver_overview(caregiver_id):
    try:
        stats, total_patients, low_stock_count, total_rx, distinct_meds = get_caregiver_overview_stats(caregiver_id)

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

@caregiver_bp.route('/caregiver/<int:caregiver_id>/chart_data', methods=['GET'])
def get_chart_data(caregiver_id):
    try:
        period = request.args.get('period', 'Week')
        
        rows = get_caregiver_chart_data(caregiver_id, period)

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
        else:
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

@caregiver_bp.route('/caregiver/<int:caregiver_id>/recent_alerts', methods=['GET'])
def get_recent_alerts(caregiver_id):  
    # Renamed the function to avoid name conflict
    try:
        # Get 'limit' from query parameters, default is 20
        limit = request.args.get('limit', default=20, type=int)
        
        # Call the model function to fetch alerts for the caregiver
        alerts = get_caregiver_alerts(caregiver_id, limit)
        
        # Return successful response with data
        return jsonify({"success": True, "data": alerts})
    
    except Exception as e:
        # Print error message in server logs
        print(f"Get caregiver alerts error: {e}")
        
        # Return error response with status code 500
        return jsonify({"success": False, "error": str(e)}), 500

@caregiver_bp.route('/caregiver/<int:caregiver_id>/low_stock_alerts', methods=['GET'])
def get_low_stock_alerts(caregiver_id):
    try:
        from models.notification_model import get_caregiver_stock_notification_rows
        rows = get_caregiver_stock_notification_rows(caregiver_id)
        return jsonify({"success": True, "data": rows})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@caregiver_bp.route('/caregiver/<int:caregiver_id>/stock_notifications', methods=['GET'])
def get_caregiver_stock_notifications(caregiver_id):
    try:
        from models.notification_model import get_caregiver_stock_notification_rows
        rows = get_caregiver_stock_notification_rows(caregiver_id)
        return jsonify({"success": True, "data": rows})
    except Exception as e:
        print(f"Error in stock_notifications: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@caregiver_bp.route('/caregiver/<int:caregiver_id>/stock_notifications', methods=['GET'])
def get_stock_notifications(caregiver_id):
    try:
        alerts = get_caregiver_stock_notification_rows(caregiver_id)
        return jsonify({"success": True, "data": alerts})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@caregiver_bp.route('/caregiver/<int:caregiver_id>/patients', methods=['GET'])
def get_caregiver_patients(caregiver_id):
    try:
        patients = get_caregiver_patients_list(caregiver_id)
        return jsonify({"success": True, "data": patients})
    except Exception as e:
        print(f"Error in get_caregiver_patients: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@caregiver_bp.route('/caregiver/<int:caregiver_id>', methods=['GET'])
def get_caregiver_profile_route(caregiver_id):
    try:
        caregiver = get_caregiver_profile(caregiver_id)

        if caregiver:
            return jsonify({"success": True, "data": caregiver})
        else:
            return jsonify({"success": False, "error": "Caregiver not found"}), 404
    except Exception as e:
        print(f"Get caregiver profile error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@caregiver_bp.route('/update_caregiver/<int:caregiver_id>', methods=['PUT'])
def update_caregiver(caregiver_id):
    try:
        full_name = request.form.get('full_name')
        phone_no = request.form.get('phone_no')
        address = request.form.get('address')
        email = request.form.get('email')
        gender = request.form.get('gender')
        date_of_birth = request.form.get('date_of_birth')

        photo_url = None
        if 'profile_photo' in request.files:
            file = request.files['profile_photo']
            if file.filename != '':
                filename = secure_filename(f"caregiver_{caregiver_id}_{file.filename}")
                filepath = os.path.join('static', 'profiles')
                os.makedirs(filepath, exist_ok=True)
                file.save(os.path.join(filepath, filename))
                
                photo_url = f"{request.host_url}static/profiles/{filename}"

        update_caregiver_profile(caregiver_id, full_name, phone_no, address, email, gender, date_of_birth, photo_url)
            
        return jsonify({"success": True, "message": "Profile updated successfully", "photo_url": photo_url})
    except Exception as e:
        print(f"Update caregiver error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@caregiver_bp.route('/caregiver/<int:caregiver_id>/notifications', methods=['GET'])
def get_caregiver_notifications(caregiver_id):
    try:
        notifs = get_caregiver_notifications_model(caregiver_id)
        return jsonify({"success": True, "data": notifs})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@caregiver_bp.route('/caregiver/notification/<int:notif_id>/read', methods=['PUT'])
def mark_caregiver_notification_read(notif_id):
    try:
        mark_notification_as_read(notif_id)
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@caregiver_bp.route('/caregiver/<int:caregiver_id>/analytics_overview', methods=['GET'])
def get_analytics_overview(caregiver_id):
    try:
        total, stats = get_caregiver_analytics_overview(caregiver_id)

        avg_score = stats['avg_prediction_score']
        if avg_score is None:
            avg_score = 85.0
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
