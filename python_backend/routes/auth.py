# auth.py
from flask import Blueprint, request, jsonify
import mysql.connector
from models.user import get_user_by_credentials, create_new_user, get_user_id_by_email, update_user_password
from utils.sanitizers import clean_string

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        
        email = clean_string(data.get('email'))
        password = clean_string(data.get('password'))

        if not email or not password:
            return jsonify({"success": False, "message": "Email and password are required"}), 400

        user = get_user_by_credentials(email, password)

        if user:
            return jsonify({"success": True, "message": f"Welcome {user['name']}", "user": user})
        else:
            return jsonify({"success": False, "message": "Invalid email or password"}), 401

    except Exception as e:
        print(f"Login error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@auth_bp.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        role = data.get('role', 'patient').lower()
        email = data.get('email')
        password = data.get('password')
        name = data.get('fullname') or data.get('full_name')
        gender = data.get('gender', 'Other')
        phone = data.get('phone_no')
        dob = data.get('date_of_birth')
        address = data.get('address')

        if not email or not password or not name:
            return jsonify({"success": False, "message": "Email, password, and name are required"}), 400

        caregiver_id = data.get('caregiver_id', 1) if role != 'caregiver' else None
        medical_notes = data.get('medical_notes') if role != 'caregiver' else None

        create_new_user(email, password, role, name, phone, address, gender, dob, caregiver_id, medical_notes)

        return jsonify({"success": True, "message": f"Registration successful as {role.capitalize()}!"})

    except mysql.connector.errors.IntegrityError:
        return jsonify({"success": False, "error": "Email already exists"}), 409
    except Exception as e:
        print(f"Registration error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@auth_bp.route('/reset_password', methods=['POST'])
def reset_password():
    try:
        data = request.get_json()
        
        email = clean_string(data.get('email'))
        new_password = clean_string(data.get('new_password'))

        if not email or not new_password:
            return jsonify({"success": False, "message": "Email and new password are required"}), 400

        user = get_user_id_by_email(email)

        if not user:
            return jsonify({"success": False, "message": "Email not found"}), 404

        update_user_password(email, new_password)

        return jsonify({"success": True, "message": "Password reset successfully!"})
        
    except Exception as e:
        print(f"Reset password error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
