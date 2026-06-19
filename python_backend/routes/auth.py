# auth.py - Authentication Blueprint (login, registration, password reset)

from flask import Blueprint, request, jsonify
import mysql.connector
from models.user import get_user_by_credentials, create_new_user, get_user_id_by_email, update_user_password
from utils.sanitizers import clean_string  # Helper to strip dangerous characters from inputs

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
        phone = data.get('phone_no')
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

        # Update the password (model handles hashing)
        update_user_password(email, new_password)

        return jsonify({"success": True, "message": "Password reset successfully!"})
        
    except Exception as e:
        print(f"Reset password error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500