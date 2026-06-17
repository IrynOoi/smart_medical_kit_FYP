#medication.py
from models.notification_model import sync_medication_stock_notifications
from db import get_db_connection
import datetime
from flask import Blueprint, request, jsonify
from models.medication_model import (
    record_dispense_inventory, create_prescription_config, get_prescription_details,
    restock_medication_inventory, update_prescription_config, delete_prescription_config,
    get_all_medications, add_new_medication, update_medication_info, delete_medication_if_unused
)
from models.adherence_model import retake_missed_dose as model_retake_missed_dose
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
        dispense_times = data.get('dispense_times')
        current_inventory = data.get('current_inventory', 0)
        refill_threshold = data.get('refill_threshold', 5)
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        device_id = data.get('device_id')

        if not all([patient_id, medication_name, dosage_tablet, dispense_times, start_date]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        success, msg, new_prescription = create_prescription_config(
            patient_id, medication_name, dosage_tablet, dispense_times, 
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
        medication_id = data.get('medication_id')
        quantity = data.get('quantity', 30)
        set_inventory = data.get('set_inventory', False)   # 新增

        if not prescription_id and not medication_id:
            return jsonify({"success": False, "message": "prescription_id or medication_id required"}), 400
        if quantity < 0:
            return jsonify({"success": False, "message": "Quantity must be positive"}), 400

        # 如果传了 medication_id，直接使用
        if medication_id:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                if set_inventory:
                    cursor.execute('UPDATE medications SET current_inventory = %s, updated_at = CURRENT_TIMESTAMP WHERE medication_id = %s',
                                   (quantity, medication_id))
                else:
                    cursor.execute('UPDATE medications SET current_inventory = current_inventory + %s, updated_at = CURRENT_TIMESTAMP WHERE medication_id = %s',
                                   (quantity, medication_id))
                conn.commit()
                cursor.close()
            sync_medication_stock_notifications(medication_id)  # 需要导入
            return jsonify({"success": True, "message": f"Inventory set to {quantity} for medication {medication_id}"})
        else:
            # 原有逻辑（基于 prescription_id）
            restock_medication_inventory(prescription_id, quantity, set_inventory)
            return jsonify({"success": True, "message": f"Updated inventory for prescription {prescription_id}"})
    except Exception as e:
        print(f"Restock error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/prescription/<int:prescription_id>', methods=['PUT'])
def update_prescription(prescription_id):
    try:
        data = request.get_json()
        medication_name = data.get('medication_name')
        dosage_tablet = data.get('dosage_tablet')
        dispense_times = data.get('dispense_times')
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        current_inventory = data.get('current_inventory')
        refill_threshold = data.get('refill_threshold')
        device_id = data.get('device_id')
        
        if not all([medication_name, dosage_tablet, dispense_times]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        check_none = 'device_id' in data
        success, msg = update_prescription_config(
            prescription_id, medication_name, dosage_tablet, dispense_times, 
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
        device_serial = data.get('device_serial')  # 👈 accept serial instead of id
        motor_slot = data.get('motor_slot')

        if not medication_name:
            return jsonify({"success": False, "message": "Medication name is required"}), 400

        # Resolve device_serial to device_id
        device_id = None
        if device_serial:
            from models.device_model import get_device_id_by_serial
            device_id = get_device_id_by_serial(device_serial)
            if not device_id:
                return jsonify({"success": False, "message": f"Device '{device_serial}' not found. Please register the device first."}), 400

        success, msg, medication_id = add_new_medication(
            medication_name, current_inventory, refill_threshold, device_id, motor_slot
        )
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
                "device_serial": device_serial,
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
        device_serial = data.get('device_serial')
        motor_slot = data.get('motor_slot')
        
        device_id = None
        if device_serial:
            from models.device_model import get_device_id_by_serial
            device_id = get_device_id_by_serial(device_serial)
            if not device_id:
                return jsonify({"success": False, "message": f"Device '{device_serial}' not found. Please register the device first."}), 400

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

@medication_bp.route('/adherence_log/<int:adlog_id>/retake', methods=['PUT'])
def retake_missed_dose(adlog_id):
    try:
        success, msg = model_retake_missed_dose(adlog_id)   # ✅ now calls the correct function
        if success:
            return jsonify({"success": True, "message": msg})
        else:
            return jsonify({"success": False, "message": msg}), 400
    except Exception as e:
        print(f"Retake error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@medication_bp.route('/get_logs', methods=['GET'])
def get_logs():
    try:
        logs = get_all_medication_logs()
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        print(f"Get logs error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@medication_bp.route('/retake_trigger/<int:adlog_id>', methods=['GET'])
def trigger_retake(adlog_id):
    try:
        # 1. Get the missed dose details
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT al.prescription_id, al.scheduled_time, al.status,
                       pc.dosage_tablet, med.motor_slot, med.device_id,
                       m.medication_name, med.current_inventory
                FROM adherence_logs al
                JOIN prescription_config pc ON al.prescription_id = pc.prescription_id
                JOIN medications med ON pc.medication_id = med.medication_id
                JOIN medications m ON pc.medication_id = m.medication_id
                WHERE al.adlog_id = %s
            ''', (adlog_id,))
            dose = cursor.fetchone()
            cursor.close()

        if not dose:
            return jsonify({"success": False, "message": "Dose not found"}), 404
        if dose['status'] != 'MISSED':
            return jsonify({"success": False, "message": "Dose is not missed"}), 400

        # 2. Check 30‑minute window using a separate connection/cursor
        with get_db_connection() as conn2:
            cursor2 = conn2.cursor(dictionary=True)
            cursor2.execute('''
                SELECT CASE 
                    WHEN NOW() <= DATE_ADD(%s, INTERVAL 30 MINUTE) THEN 1 
                    ELSE 0 
                END AS within_window
            ''', (dose['scheduled_time'],))
            within = cursor2.fetchone()['within_window']
            cursor2.close()

        if not within:
            return jsonify({"success": False, "message": "Retake window expired (30 minutes)"}), 400

        # 3. Return the dispense information (status unchanged)
        return jsonify({
            "success": True,
            "data": {
                "adlog_id": adlog_id,
                "prescription_id": dose['prescription_id'],
                "motor_slot": dose['motor_slot'],
                "device_id": dose['device_id'],
                "medication_name": dose['medication_name'],
                "dosage_tablet": dose['dosage_tablet'],
                "current_inventory": dose['current_inventory'],
            }
        })
    except Exception as e:
        print(f"Trigger retake error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500