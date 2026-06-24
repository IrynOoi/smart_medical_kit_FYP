# patient.py - Blueprint for patient-related API endpoints

# Import required model functions for user operations (soft/hard delete, reactivation)
from models.user_model import hard_delete_patient, soft_delete_patient, reactivate_patient
import os  # For file path operations
from flask import Blueprint, request, jsonify  # Flask components for routing and request handling
from werkzeug.utils import secure_filename  # Sanitize uploaded filenames

# Additional user model functions: profile retrieval, update, cascade delete (unused)
from models.user_model import get_patient_profile, update_patient_profile, delete_patient_cascade
from models.medication_model import get_prescriptions_by_patient  # Fetch prescriptions
from models.adherence_model import get_patient_adherence_stats, get_patient_adherence_logs  # Adherence data

from models.analytics_model import get_latest_ai_prediction  # AI prediction

# Create a Flask Blueprint for patient routes; will be registered with a URL prefix in the main app
patient_bp = Blueprint('patient', __name__)


# ---------------------- GET Patient Profile ----------------------
@patient_bp.route('/patient/<int:patient_id>', methods=['GET'])
def get_patient(patient_id):
    """
    Retrieve full patient profile including user details and associated caregiver info.
    Returns 404 if patient not found.
    """
    try:
        # Fetch the patient row (joined with user and caregiver tables)
        row = get_patient_profile(patient_id)

        if row:
            # Build the base patient data object
            patient_data = {
                "patient_id": row["patient_id"],
                "caregiver_id": row["cg_id"],  # Direct caregiver ID (from join)
                "medical_notes": row["medical_notes"],
                "user": {  # Nested user object
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
            # If caregiver exists (cg_id not null), add a caregiver object with user details
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
                patient_data["caregiver"] = None  # Explicitly set to null

            return jsonify({"success": True, "data": patient_data})
        else:
            return jsonify({"success": False, "error": "Patient not found"}), 404
    except Exception as e:
        print(f"Get patient error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Reactivate Patient ----------------------
@patient_bp.route('/patient/<int:patient_id>/reactivate', methods=['PUT'])
def api_reactivate_patient(patient_id):
    """
    Reactivate a soft-deleted patient (set is_active = True).
    """
    try:
        reactivate_patient(patient_id)   # Call model function
        return jsonify({"success": True, "message": "Patient reactivated"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Prescriptions ----------------------
@patient_bp.route('/patient/<int:patient_id>/prescriptions', methods=['GET'])
def get_patient_prescriptions(patient_id):
    """
    Retrieve all prescriptions for a given patient.
    """
    try:
        prescriptions = get_prescriptions_by_patient(patient_id)
        return jsonify({"success": True, "data": prescriptions})
    except Exception as e:
        print(f"Get prescriptions error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500



# ---------------------- Get Adherence Statistics ----------------------
@patient_bp.route('/patient/<int:patient_id>/adherence_stats', methods=['GET'])
def get_adherence_stats(patient_id):
    """
    Return summary adherence counts (taken, missed, upcoming) and a computed adherence score.
    """
    try:
        # Get raw stats from model
        stats = get_patient_adherence_stats(patient_id)

        taken = stats['taken_count'] or 0
        missed = stats['missed_count'] or 0
        total = taken + missed
        # Score = (taken / total) * 100; if no records, assume perfect adherence (100)
        score = int((taken / total) * 100) if total > 0 else 100

        return jsonify({"success": True, "data": {
            "taken_count": taken,
            "missed_count": missed,
            "upcoming_count": stats['upcoming_count'] or 0,
            "adherence_score": score
        }})
    except Exception as e:
        print(f"Get adherence stats error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Adherence Logs ----------------------
@patient_bp.route('/patient/<int:patient_id>/adherence_logs', methods=['GET'])
def get_adherence_logs(patient_id):
    """
    Retrieve recent adherence logs (dose events) with an optional limit query parameter.
    """
    try:
        # Default limit = 20 if not provided
        limit = request.args.get('limit', default=20, type=int)
        logs = get_patient_adherence_logs(patient_id, limit)
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        print(f"Get adherence logs error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500



# ---------------------- Get AI Prediction ----------------------
@patient_bp.route('/patient/<int:patient_id>/ai_prediction', methods=['GET'])
def get_ai_prediction(patient_id):
    """
    Retrieve the latest AI-generated prediction (e.g., adherence risk) for the patient.
    Returns 404-like error if no prediction exists.
    """
    try:
        prediction = get_latest_ai_prediction(patient_id)
            
        if prediction:
            return jsonify({
                "success": True,
                "data": prediction
            })
        else:
            # No prediction found
            return jsonify({
                "success": False, 
                "error": "No prediction found in database for this patient"
            })
            
    except Exception as e:
        print(f"Get AI prediction error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Update Patient Profile ----------------------
@patient_bp.route('/update_patient/<int:patient_id>', methods=['PUT'])
def update_patient(patient_id):
    """
    Update patient profile fields and optionally upload a new profile photo.
    Expects multipart/form-data with fields: full_name, phone_no, address, email,
    gender, date_of_birth, medical_notes, and optionally profile_photo file.
    """
    try:
        # Extract form fields
        full_name = request.form.get('full_name')
        phone_no = request.form.get('phone_no')
        address = request.form.get('address')
        email = request.form.get('email')
        gender = request.form.get('gender')
        date_of_birth = request.form.get('date_of_birth')
        medical_notes = request.form.get('medical_notes')

        photo_url = None
        # Handle file upload if present
        if 'profile_photo' in request.files:
            file = request.files['profile_photo']
            if file.filename != '':
                # Secure the filename and prepend patient_id to avoid collisions
                filename = secure_filename(f"patient_{patient_id}_{file.filename}")
                filepath = os.path.join('static', 'profiles')
                os.makedirs(filepath, exist_ok=True)  # Create directory if it doesn't exist
                file.save(os.path.join(filepath, filename))
                photo_url = f"/static/profiles/{filename}"  # URL to access the photo

        # Call model to update patient profile (all fields are passed, including photo_url)
        update_patient_profile(patient_id, full_name, phone_no, address, email,
                               gender, date_of_birth, medical_notes, photo_url)
            
        return jsonify({"success": True, "message": "Profile updated successfully", "photo_url": photo_url})
    except Exception as e:
        print(f"Update patient error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Delete Patient (Soft or Hard) ----------------------
@patient_bp.route('/patient/<int:patient_id>', methods=['DELETE'])
def delete_patient(patient_id):
    """
    Delete a patient. By default performs a soft delete (sets is_active = False).
    If query parameter ?hard=true is provided, performs a permanent hard delete.
    NOTE: There is a typo in the error status code (5000 instead of 500).
    """
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
        # TYPO: status code should be 500, not 5000
        return jsonify({"success": False, "error": str(e)}), 5000

