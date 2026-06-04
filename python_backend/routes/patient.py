#patient.py
from models.user import hard_delete_patient, soft_delete_patient, reactivate_patient
import os
from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
from models.user import get_patient_profile, update_patient_profile, delete_patient_cascade
from models.medication_model import get_prescriptions_by_patient
from models.adherence_model import get_patient_adherence_stats, get_patient_adherence_logs
from models.notification_model import get_patient_notifications, mark_single_reminder_read, mark_all_reminders_read as mark_all_reminders_read_model, insert_notification, mark_notification_as_read
from models.analytics_model import get_latest_ai_prediction

patient_bp = Blueprint('patient', __name__)

@patient_bp.route('/patient/<int:patient_id>', methods=['GET'])
def get_patient(patient_id):
    try:
        row = get_patient_profile(patient_id)

        if row:
            patient_data = {
                "patient_id": row["patient_id"],
                "caregiver_id": row["cg_id"], # <-- CHANGED THIS LINE
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

@patient_bp.route('/patient/<int:patient_id>/reactivate', methods=['PUT'])
def api_reactivate_patient(patient_id):
    try:
        reactivate_patient(patient_id)   # import from user.py
        return jsonify({"success": True, "message": "Patient reactivated"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@patient_bp.route('/patient/<int:patient_id>/prescriptions', methods=['GET'])
def get_patient_prescriptions(patient_id):
    try:
        prescriptions = get_prescriptions_by_patient(patient_id)
        return jsonify({"success": True, "data": prescriptions})
    except Exception as e:
        print(f"Get prescriptions error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@patient_bp.route('/patient/<int:patient_id>/reminders/read_single', methods=['PUT'])
def api_mark_single_reminder_read(patient_id):
    try:
        data = request.get_json()
        medication_name = data.get('medication_name')
        
        if not medication_name:
            return jsonify({"success": False, "message": "medication_name required"}), 400

        mark_single_reminder_read(patient_id, medication_name)
            
        return jsonify({"success": True, "message": f"Reminders for {medication_name} marked as read"})
    except Exception as e:
        print(f"Error marking single reminder read: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@patient_bp.route('/patient/<int:patient_id>/adherence_stats', methods=['GET'])
def get_adherence_stats(patient_id):
    try:
        stats = get_patient_adherence_stats(patient_id)

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

@patient_bp.route('/patient/<int:patient_id>/adherence_logs', methods=['GET'])
def get_adherence_logs(patient_id):
    try:
        limit = request.args.get('limit', default=20, type=int)
        logs = get_patient_adherence_logs(patient_id, limit)
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        print(f"Get adherence logs error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@patient_bp.route('/patient/<int:patient_id>/notifications', methods=['GET'])
def get_notifications(patient_id):
    try:
        notifications = get_patient_notifications(patient_id)
        return jsonify({"success": True, "data": notifications})
    except Exception as e:
        print(f"Get notifications error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@patient_bp.route('/patient/<int:patient_id>/ai_prediction', methods=['GET'])
def get_ai_prediction(patient_id):
    try:
        prediction = get_latest_ai_prediction(patient_id)
            
        if prediction:
            return jsonify({
                "success": True,
                "data": prediction
            })
        else:
            return jsonify({
                "success": False, 
                "error": "No prediction found in database for this patient"
            })
            
    except Exception as e:
        print(f"Get AI prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@patient_bp.route('/update_patient/<int:patient_id>', methods=['PUT'])
def update_patient(patient_id):
    try:
        full_name = request.form.get('full_name')
        phone_no = request.form.get('phone_no')
        address = request.form.get('address')
        email = request.form.get('email')
        gender = request.form.get('gender')
        date_of_birth = request.form.get('date_of_birth')
        medical_notes = request.form.get('medical_notes')

        photo_url = None
        if 'profile_photo' in request.files:
            file = request.files['profile_photo']
            if file.filename != '':
                filename = secure_filename(f"patient_{patient_id}_{file.filename}")
                filepath = os.path.join('static', 'profiles')
                os.makedirs(filepath, exist_ok=True)
                file.save(os.path.join(filepath, filename))
                photo_url = f"/static/profiles/{filename}"

        update_patient_profile(patient_id, full_name, phone_no, address, email, gender, date_of_birth, medical_notes, photo_url)
            
        return jsonify({"success": True, "message": "Profile updated successfully", "photo_url": photo_url})
    except Exception as e:
        print(f"Update patient error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

# patient.py  (modify the DELETE route)
@patient_bp.route('/patient/<int:patient_id>', methods=['DELETE'])
def delete_patient(patient_id):
    try:
        hard = request.args.get('hard', 'false').lower() == 'true'
        if hard:
            hard_delete_patient(patient_id)
            return jsonify({"success": True, "message": "Patient permanently deleted"})
        else:
            soft_delete_patient(patient_id)
            return jsonify({"success": True, "message": "Patient deactivated successfully"})
    except Exception as e:
        print(f"Delete patient error: {e}")
        return jsonify({"success": False, "error": str(e)}), 5000

@patient_bp.route('/patient/<int:patient_id>/reminders/read', methods=['PUT'])
def api_mark_all_reminders_read(patient_id):
    try:
        mark_all_reminders_read_model(patient_id)
        return jsonify({"success": True, "message": "All reminders marked as read"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@patient_bp.route('/notifications', methods=['POST'])
def create_notification():
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        title = data.get('title')
        message = data.get('message')
        notif_type = data.get('type', 'REMINDER')

        if not all([patient_id, title, message]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        insert_notification(patient_id, title, message, notif_type)

        return jsonify({"success": True, "message": "In-app notification saved successfully!"})
    except Exception as e:
        print(f"Create notification error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@patient_bp.route('/notification/<int:notification_id>/read', methods=['PUT'])
def mark_notification_read(notification_id):
    try:
        mark_notification_as_read(notification_id)
        return jsonify({"success": True, "message": "Notification marked as read"})
    except Exception as e:
        print(f"Mark notification read error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
