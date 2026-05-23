#medication.py
import datetime
from flask import Blueprint, request, jsonify
from models.medication_model import (
    record_dispense_inventory, create_prescription_config, get_prescription_details,
    restock_medication_inventory, update_prescription_config, delete_prescription_config,
    get_all_medications, add_new_medication, update_medication_info, delete_medication_if_unused
)
from models.adherence_model import save_medication_log, get_all_medication_logs
from services.notification_service import send_new_prescription_notification, send_removed_prescription_notification

medication_bp = Blueprint('medication', __name__)

@medication_bp.route('/record_medication', methods=['POST'])
def record_medication():
    try:
        data = request.get_json()
        prescription_id = data.get('prescription_id')
        device_id = data.get('device_id')

        if not prescription_id or not device_id:
            return jsonify({"success": False, "message": "prescription_id and device_id are required"}), 400

        success, msg, patient_id = record_dispense_inventory(prescription_id)
        if not success:
            return jsonify({"success": False, "message": msg}), 404

        return jsonify({"success": True, "message": "Medication recorded and reminders cleared!"})
    except Exception as e:
        print(f"Record medication error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/add_prescription', methods=['POST'])
def add_prescription():
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        medication_name = data.get('medication_name')
        dosage_tablet = data.get('dosage_tablet')
        dispense_schedule = data.get('dispense_schedule')
        current_inventory = data.get('current_inventory', 0)
        refill_threshold = data.get('refill_threshold', 5)
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        device_id = data.get('device_id')

        if not all([patient_id, medication_name, dosage_tablet, dispense_schedule, start_date]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        success, msg, new_prescription = create_prescription_config(
            patient_id, medication_name, dosage_tablet, dispense_schedule, 
            start_date, end_date, current_inventory, refill_threshold, device_id
        )

        if not success:
            return jsonify({"success": False, "message": msg}), 400

        send_new_prescription_notification(patient_id, medication_name)

        return jsonify({"success": True, "message": "Prescription created successfully!", "data": new_prescription})
    except Exception as e:
        print(f"Add prescription error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/prescription/<int:prescription_id>', methods=['GET'])
def get_prescription_details(prescription_id):
    try:
        prescription = get_prescription_details(prescription_id)

        if prescription:
            return jsonify({"success": True, "data": prescription})
        else:
            return jsonify({"success": False, "error": "Prescription not found"}), 404
    except Exception as e:
        print(f"Get prescription details error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/restock_medication', methods=['POST'])
def restock_medication():
    try:
        data = request.get_json()
        prescription_id = data.get('prescription_id')
        quantity = data.get('quantity', 30)
        
        if not prescription_id:
            return jsonify({"success": False, "message": "prescription_id required"}), 400
        
        restock_medication_inventory(prescription_id, quantity)
        
        return jsonify({"success": True, "message": f"Added {quantity} pills to inventory"})
    except Exception as e:
        print(f"Restock error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/prescription/<int:prescription_id>', methods=['PUT'])
def update_prescription(prescription_id):
    try:
        data = request.get_json()
        medication_name = data.get('medication_name')
        dosage_tablet = data.get('dosage_tablet')
        dispense_schedule = data.get('dispense_schedule')
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        current_inventory = data.get('current_inventory')
        refill_threshold = data.get('refill_threshold')
        device_id = data.get('device_id')
        
        if not all([medication_name, dosage_tablet, dispense_schedule]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        check_none = 'device_id' in data
        success, msg = update_prescription_config(
            prescription_id, medication_name, dosage_tablet, dispense_schedule, 
            start_date, end_date, current_inventory, refill_threshold, device_id, check_none
        )
        if not success:
            return jsonify({"success": False, "message": msg}), 400

        return jsonify({"success": True, "message": "Prescription updated successfully!"})
    except Exception as e:
        print(f"Update prescription error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/prescription/<int:prescription_id>', methods=['DELETE'])
def delete_prescription(prescription_id):
    try:
        rx_data = delete_prescription_config(prescription_id)
        if rx_data:
            send_removed_prescription_notification(rx_data['patient_id'], rx_data['medication_name'])

        return jsonify({"success": True, "message": "Prescription deleted and patient notified!"})
    except Exception as e:
        print(f"Delete prescription error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/medications', methods=['GET'])
def get_medications():
    try:
        meds = get_all_medications()
        return jsonify({"success": True, "data": meds})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/medications', methods=['POST'])
def add_medication():
    try:
        data = request.get_json()
        medication_name = data.get('medication_name')
        current_inventory = data.get('current_inventory', 0)
        refill_threshold = data.get('refill_threshold', 5)
        device_id = data.get('device_id')
        motor_slot = data.get('motor_slot')

        if not medication_name:
            return jsonify({"success": False, "message": "Medication name is required"}), 400

        success, msg, medication_id = add_new_medication(medication_name, current_inventory, refill_threshold, device_id, motor_slot)
        if not success:
            return jsonify({"success": False, "message": msg}), 400

        return jsonify({
            "success": True,
            "data": {
                "medication_id": medication_id,
                "medication_name": medication_name,
                "current_inventory": current_inventory,
                "refill_threshold": refill_threshold,
                "device_id": device_id,
                "motor_slot": motor_slot
            }
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/medications/<int:medication_id>', methods=['PUT'])
def update_medication(medication_id):
    try:
        data = request.get_json()
        new_name = data.get('medication_name')
        current_inventory = data.get('current_inventory')
        refill_threshold = data.get('refill_threshold')
        device_id = data.get('device_id')
        motor_slot = data.get('motor_slot')

        if not new_name and current_inventory is None and refill_threshold is None and device_id is None and motor_slot is None:
            return jsonify({"success": False, "message": "No fields to update"}), 400

        success, msg, updated = update_medication_info(medication_id, new_name, current_inventory, refill_threshold, device_id, motor_slot)
        
        if success:
            return jsonify({
                "success": True,
                "data": {
                    "medication_id": updated[0],
                    "medication_name": updated[1],
                    "current_inventory": updated[2],
                    "refill_threshold": updated[3],
                    "device_id": updated[4],
                    "motor_slot": updated[5]
                }
            })
        else:
            return jsonify({"success": False, "message": msg}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/medications/<int:medication_id>', methods=['DELETE'])
def delete_medication(medication_id):
    try:
        success, msg = delete_medication_if_unused(medication_id)
        if success:
            return jsonify({"success": True, "message": msg})
        else:
            return jsonify({"success": False, "message": msg}), 400 if "used" in msg else 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/add_log', methods=['POST'])
def add_log():
    try:
        data = request.get_json()
        save_medication_log(data['patient_id'], data['age'], data['day_of_week'], data['time_of_day'], data['status'])
        return jsonify({"success": True, "message": "Log saved successfully!"})
    except Exception as e:
        print(f"Add log error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/get_logs', methods=['GET'])
def get_logs():
    try:
        logs = get_all_medication_logs()
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        print(f"Get logs error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
