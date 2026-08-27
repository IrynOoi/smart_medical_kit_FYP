# auth.py - Authentication Blueprint (login, registration, password reset)

from models.user_model import get_user_password_by_email
from flask import Blueprint, request, jsonify
import mysql.connector
import random
from services.email_service import send_reset_otp_email

from models.user_model import get_user_by_credentials, create_new_user, get_user_id_by_email, update_user_password, get_caregiver_patient_count
from utils.sanitizers import clean_string, normalize_phone_number  # Helper to strip dangerous characters and standardize phone numbers

# Create Blueprint for authentication routes
auth_bp = Blueprint('auth', __name__)


# ---------------------- User Login ----------------------
@auth_bp.route('/login', methods=['POST'])
def login():
    """
    Authenticate a user using email and password.
    Expects JSON: email, password.
    Returns user details (including role) on success.
    Uses clean_string to sanitize input before querying.
    """
    try:
        data = request.get_json()
        
        # Sanitize email and password to avoid injection attempts
        email = clean_string(data.get('email'))
        password = clean_string(data.get('password'))

        # Validate required fields
        if not email or not password:
            return jsonify({"success": False, "message": "Email and password are required"}), 400

        # Query user by credentials (handles hashed password comparison)
        user = get_user_by_credentials(email, password)

        if user:
            # Successful login; return user data (including user_id, role, name, etc.)
            return jsonify({"success": True, "message": f"Welcome {user['name']}", "user": user})
        else:
            # Invalid credentials
            return jsonify({"success": False, "message": "Invalid email or password"}), 401

    except Exception as e:
        print(f"Login error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- User Registration ----------------------
@auth_bp.route('/register', methods=['POST'])
def register():
    """
    Register a new user (patient or caregiver).
    Expects JSON: role (default 'patient'), email, password, fullname,
    gender (default 'Other'), phone_no, date_of_birth, address.
    Optional: caregiver_id, medical_notes (for patients only).
    Returns success message on creation.
    Handles duplicate email (IntegrityError) gracefully.
    """
    try:
        data = request.get_json()
        role = data.get('role', 'patient').lower()   # 'patient' or 'caregiver'
        email = data.get('email')
        password = data.get('password')
        name = data.get('fullname') or data.get('full_name')  # Accept either field name
        gender = data.get('gender', 'Other')
        phone = normalize_phone_number(data.get('phone_no') or data.get('phone'))
        dob = data.get('date_of_birth')
        address = data.get('address')

        # Required fields: email, password, name
        if not email or not password or not name:
            return jsonify({"success": False, "message": "Email, password, and name are required"}), 400

        # Role-specific fields:
        # - caregiver_id: only valid for patients (if they are assigned to a caregiver)
        # - medical_notes: only for patients
        caregiver_id = data.get('caregiver_id') if role != 'caregiver' else None
        medical_notes = data.get('medical_notes') if role != 'caregiver' else None

        # For caregiver registration, enforce 18+ years age restriction
        if role == 'caregiver':
            if not dob:
                return jsonify({"success": False, "message": "Date of birth is required for caregiver registration"}), 400
            try:
                from datetime import datetime, date
                dob_obj = datetime.strptime(str(dob)[:10], '%Y-%m-%d').date()
                today = date.today()
                age = today.year - dob_obj.year - ((today.month, today.day) < (dob_obj.month, dob_obj.day))
                if age < 18:
                    return jsonify({"success": False, "message": "Caregiver must be at least 18 years old"}), 400
            except ValueError:
                return jsonify({"success": False, "message": "Invalid date of birth format"}), 400

        # Check if caregiver patient limit is reached
        if caregiver_id:
            count = get_caregiver_patient_count(caregiver_id)
            if count >= 10:
                return jsonify({"success": False, "message": "Caregiver already has the maximum of 10 patients"}), 400

        # Call model to create the user; it will hash the password and insert into appropriate tables
        create_new_user(email, password, role, name, phone, address, gender, dob, caregiver_id, medical_notes)

        return jsonify({"success": True, "message": f"Registration successful as {role.capitalize()}!"})

    except mysql.connector.errors.IntegrityError:
        # Unique constraint violation (duplicate email)
        return jsonify({"success": False, "error": "Email already exists"}), 409
    except Exception as e:
        print(f"Registration error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Password Reset ----------------------
@auth_bp.route('/reset_password', methods=['POST'])
def reset_password():
    """
    Reset a user's password using their email.
    Expects JSON: email, new_password.
    Returns success if the email exists and the password is updated.
    (In production, this should involve a secure token-based flow, but here it's simplified.)
    """
    try:
        data = request.get_json()
        
        # Sanitize inputs
        email = clean_string(data.get('email'))
        new_password = clean_string(data.get('new_password'))

        # Validate required fields
        if not email or not new_password:
            return jsonify({"success": False, "message": "Email and new password are required"}), 400

        # Check if the email exists in the system
        user = get_user_id_by_email(email)   # Returns user_id if found, else None
        if not user:
            return jsonify({"success": False, "message": "Email not found"}), 404

        # =============================================
        # 🛡️ NEW: Prevent using the same password
        # =============================================
        current_password = get_user_password_by_email(email)
        if current_password is not None and current_password == new_password:
            return jsonify({
                "success": False,
                "message": "New password must be different from the current password."
            }), 400

        # Update the password (model handles hashing)
        update_user_password(email, new_password)

        return jsonify({"success": True, "message": "Password reset successfully!"})
        
    except Exception as e:
        print(f"Reset password error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500



# In-memory dictionary for storing OTP codes and verification status
otp_store = {} 

@auth_bp.route('/forgot_password', methods=['POST'])
def forgot_password():
    """Step 1: Check if email exists -> Generate OTP and send email via Mailtrap."""
    try:
        data = request.get_json()
        email = clean_string(data.get('email'))

        if not email:
            return jsonify({"success": False, "message": "Email is required"}), 400

        user = get_user_id_by_email(email)
        if not user:
            return jsonify({"success": False, "message": "Email address not found in system"}), 404

        # Generate 6-digit OTP
        otp_code = str(random.randint(100000, 999999))
        otp_store[email] = {
            "otp": otp_code,
            "verified": False
        }

        # Send email via Mailtrap
        sent = send_reset_otp_email(email, otp_code)
        if sent:
            return jsonify({"success": True, "message": "OTP code sent to your email!"})
        else:
            return jsonify({"success": False, "message": "Failed to send OTP email via Mailtrap"}), 500
    except Exception as e:
        print(f"Forgot password error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@auth_bp.route('/verify_otp', methods=['POST'])
def verify_otp():
    """Step 2: Validate entered OTP code."""
    try:
        data = request.get_json()
        email = clean_string(data.get('email'))
        user_otp = clean_string(data.get('otp'))

        if not email or not user_otp:
            return jsonify({"success": False, "message": "Email and OTP code are required"}), 400

        stored = otp_store.get(email)
        if not stored or stored.get('otp') != user_otp:
            return jsonify({"success": False, "message": "Invalid or expired OTP code"}), 400

        # Mark OTP as verified
        otp_store[email]['verified'] = True
        return jsonify({"success": True, "message": "OTP verified successfully!"})
    except Exception as e:
        print(f"Verify OTP error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@auth_bp.route('/verify_otp_and_reset', methods=['POST'])
def verify_otp_and_reset():
    """Step 3: Reset password after OTP verification."""
    try:
        data = request.get_json()
        email = clean_string(data.get('email'))
        user_otp = clean_string(data.get('otp'))
        new_password = clean_string(data.get('new_password'))

        if not email or not new_password:
            return jsonify({"success": False, "message": "Email and new password are required"}), 400

        # Check if OTP was verified or matches
        stored = otp_store.get(email)
        if not stored:
            return jsonify({"success": False, "message": "Session expired or invalid OTP"}), 400

        if not stored.get('verified') and stored.get('otp') != user_otp:
            return jsonify({"success": False, "message": "Invalid or unverified OTP"}), 400

        # Prevent using the same current password
        current_password = get_user_password_by_email(email)
        if current_password is not None and current_password == new_password:
            return jsonify({
                "success": False,
                "message": "New password must be different from current password."
            }), 400

        # Update Password in DB
        update_user_password(email, new_password)

        # Clear OTP from store
        if email in otp_store:
            del otp_store[email]

        return jsonify({"success": True, "message": "Password reset successfully!"})
    except Exception as e:
        print(f"Reset password error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

