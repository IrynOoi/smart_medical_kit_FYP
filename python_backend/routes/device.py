# device.py
from flask import Blueprint, request, jsonify
from models.device_model import (
    get_device_by_serial, 
    get_all_devices as get_all_devices_model, # <-- Just the alias
    get_device_by_id as get_device_by_id_model,
    get_patient_by_device, add_new_device, update_device_serial as update_device_serial_model,
    delete_device as delete_device_model, record_device_heartbeat,
    get_pending_dose_for_device, get_device_ip_for_patient, record_dispense_from_device
)
from models.medication_model import get_prescriptions_by_device, get_prescription_for_device_patient as get_prescription_for_device_patient_model
from models.notification_model import sync_patient_caregiver_stock_notifications
from services.esp_forwarder import _forward_to_esp
from db import get_db_connection

device_bp = Blueprint('device', __name__)

@device_bp.route('/device/control/led', methods=['POST'])
def control_led():
    data = request.get_json()
    patient_id = data.get('patient_id')
    action = data.get('action')
    if not patient_id or action not in ('on', 'off'):
        return jsonify({"success": False, "message": "patient_id and action (on/off) required"}), 400

    device = get_device_ip_for_patient(patient_id)

    if not device or not device['last_known_ip']:
        return jsonify({"success": False, "message": "Device IP not known"}), 404

    status_code, response = _forward_to_esp(device['last_known_ip'], f"/led/{action}")
    if status_code == 200:
        return jsonify({"success": True, "message": f"LED turned {action}"})
    else:
        return jsonify({"success": False, "message": f"ESP32 error: {response}"}), 500

@device_bp.route('/device/control/buzzer', methods=['POST'])
def control_buzzer():
    data = request.get_json()
    patient_id = data.get('patient_id')
    action = data.get('action')
    if not patient_id or action not in ('on', 'off'):
        return jsonify({"success": False, "message": "patient_id and action (on/off) required"}), 400

    device = get_device_ip_for_patient(patient_id)

    if not device or not device['last_known_ip']:
        return jsonify({"success": False, "message": "Device IP not known"}), 404

    status_code, response = _forward_to_esp(device['last_known_ip'], f"/buzzer/{action}")
    if status_code == 200:
        return jsonify({"success": True, "message": f"Buzzer turned {action}"})
    else:
        return jsonify({"success": False, "message": f"ESP32 error: {response}"}), 500

@device_bp.route('/device/control/display', methods=['POST'])
def control_display():
    data = request.get_json()
    patient_id = data.get('patient_id')
    command = data.get('command')
    if not patient_id or command not in ('hello', 'clear', 'sv'):
        return jsonify({"success": False, "message": "patient_id and command (hello/clear/sv) required"}), 400

    device = get_device_ip_for_patient(patient_id)

    if not device or not device['last_known_ip']:
        return jsonify({"success": False, "message": "Device IP not known"}), 404

    status_code, response = _forward_to_esp(device['last_known_ip'], f"/display/{command}")
    if status_code == 200:
        return jsonify({"success": True, "message": f"Display command '{command}' sent"})
    else:
        return jsonify({"success": False, "message": f"ESP32 error: {response}"}), 500

@device_bp.route('/device/control/stepper', methods=['POST'])
def control_stepper():
    data = request.get_json()
    patient_id = data.get('patient_id')
    motor = data.get('motor')
    action = data.get('action')
    if not patient_id or motor not in (1,2,3) or action not in ('forward','backward','90','180'):
        return jsonify({"success": False, "message": "patient_id, motor(1-3), action(forward/backward/90/180) required"}), 400

    device = get_device_ip_for_patient(patient_id)

    if not device or not device['last_known_ip']:
        return jsonify({"success": False, "message": "Device IP not known"}), 404

    motor_prefix = "" if motor == 1 else str(motor)
    endpoint = f"/stepper{motor_prefix}/{action}"
    status_code, response = _forward_to_esp(device['last_known_ip'], endpoint)
    if status_code == 200:
        return jsonify({"success": True, "message": f"Motor {motor} {action} command sent"})
    else:
        return jsonify({"success": False, "message": f"ESP32 error: {response}"}), 500

@device_bp.route('/iot_device/<int:device_id>', methods=['PUT'])
def update_device(device_id):
    data = request.get_json()
    new_serial = data.get('device_serial')
    if not new_serial:
        return jsonify({"success": False, "message": "device_serial required"}), 400
    updated = update_device_serial_model(device_id, new_serial)
    if updated:
        return jsonify({"success": True, "message": "Device updated"})
    else:
        return jsonify({"success": False, "message": "Device not found"}), 404
@device_bp.route('/iot_device/<int:device_id>', methods=['DELETE'])
def delete_device_route(device_id):
    success, msg = delete_device_model(device_id)
    if success:
        return jsonify({"success": True, "message": msg})
    else:
        return jsonify({"success": False, "message": msg}), 404

@device_bp.route('/iot_device', methods=['POST'])
def add_device():
    data = request.get_json()
    device_serial = data.get('device_serial')
    ip_address = data.get('last_known_ip') or request.remote_addr
    battery_level = data.get('battery', 100)

    if not device_serial:
        return jsonify({"success": False, "message": "device_serial required"}), 400

    # Model returns (success, message, device_id)
    success, msg, device_id = add_new_device(device_serial, battery_level, ip_address)
    if not success:
        return jsonify({"success": False, "message": msg}), 400

    return jsonify({"success": True, "message": "Device added", "device_id": device_id})

@device_bp.route('/device/<int:device_id>', methods=['GET'])
def get_device_by_id_route(device_id):
    try:
        device = get_device_by_id_model(device_id)
        if device:
            return jsonify({"success": True, "data": device})
        else:
            return jsonify({"success": False, "error": "Device not found"}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@device_bp.route('/device/<int:device_id>/patient', methods=['GET'])
def get_patient_by_device_route(device_id):
    try:
        patient = get_patient_by_device(device_id)
        if patient:
            return jsonify({"success": True, "data": patient})
        else:
            return jsonify({"success": True, "data": None})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@device_bp.route('/devices', methods=['GET'])
def get_all_devices():
    try:
        # Call the aliased model function instead of the route itself
        devices = get_all_devices_model() 
        return jsonify({"success": True, "data": devices})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@device_bp.route('/device/<int:device_id>/prescriptions', methods=['GET'])
def get_device_prescriptions(device_id):
    try:
        prescriptions = get_prescriptions_by_device(device_id)
        return jsonify({"success": True, "data": prescriptions})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@device_bp.route('/device/<device_serial>/pending_dose', methods=['GET'])
def get_pending_dose(device_serial):
    try:
        dose = get_pending_dose_for_device(device_serial)
        
        if dose:
            # 💡 新增逻辑：检查库存是否为 0
            is_empty = False
            if dose.get('current_inventory', 0) <= 0:
                is_empty = True
                
            # (可选) 从发给 ESP32 的 data 里删掉库存字段，保持数据精简
            if 'current_inventory' in dose:
                del dose['current_inventory']

            # 把 is_empty 塞进 JSON 发出去！
            return jsonify({
                "success": True, 
                "has_pending": True, 
                "is_empty": is_empty,  # 👈 ESP32 就靠这行代码救命了！
                "data": dose
            })
        else:
            return jsonify({"success": True, "has_pending": False})
            
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@device_bp.route('/device/dispense_success', methods=['POST'])
def dispense_success():
    try:
        data = request.get_json()
        adlog_id = data.get('adlog_id')
        prescription_id = data.get('prescription_id')
        
        record_dispense_from_device(adlog_id, prescription_id)
        return jsonify({"success": True, "message": "Dispense recorded and reminders cleared!"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@device_bp.route('/device/heartbeat', methods=['POST'])
def device_heartbeat():
    try:
        data = request.get_json(silent=True) or {}
        device_serial = data.get('device_serial')
        battery = data.get('battery', 100)
        wifi_rssi = data.get('rssi')
        
        # Prefer the ESP32's local IP from JSON. request.remote_addr can be the
        # tunnel/proxy IP instead of the actual device IP.
        device_ip = (
            data.get('ip')
            or data.get('device_ip')
            or data.get('last_known_ip')
            or request.remote_addr
        )

        if not device_serial:
            return jsonify({"success": False, "message": "device_serial required"}), 400

        success, message = record_device_heartbeat(device_serial, battery, device_ip, wifi_rssi)
        if not success:
            return jsonify({"success": False, "message": message}), 404

        return jsonify({"success": True, "message": "Heartbeat received", "device_ip": device_ip})
    except Exception as e:
        print(f"Heartbeat error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@device_bp.route('/test_device/<int:user_id>', methods=['POST'])
def test_device(user_id):
    return jsonify({"success": True, "message": "Buzzer Signal Sent to Kit! 🔊"})

@device_bp.route('/iot_device/patient/<int:patient_id>', methods=['GET'])
def get_patient_device(patient_id):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('''
                SELECT d.device_id, d.device_serial, 
                    d.last_reported_battery AS battery_level, 
                    d.last_battery_report AS last_active_timestamp,
                    d.last_known_ip AS last_known_ip
                FROM prescription_config pc
                JOIN medications m ON pc.medication_id = m.medication_id
                JOIN iot_device d ON m.device_id = d.device_id
                WHERE pc.patient_id = %s AND m.device_id IS NOT NULL
                AND (pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE)
                LIMIT 1
            ''', (patient_id,))
            device = cursor.fetchone()
            cursor.close()
        
        if device:
            return jsonify({"success": True, "data": device})
        else:
            return jsonify({"success": True, "data": {}})
    except Exception as e:
        print(f"Get device error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@device_bp.route('/device/create_with_prescription', methods=['POST'])
def create_device_with_prescription():
    data = request.get_json()
    device_serial = data.get('device_serial')
    patient_id = data.get('patient_id')
    motor_slot = data.get('motor_slot')
    medication_id = data.get('medication_id')
    inventory = data.get('current_inventory', 30)
    threshold = data.get('refill_threshold', 10)

    if not all([device_serial, patient_id, motor_slot, medication_id]):
        return jsonify({"success": False, "message": "Missing required fields"}), 400

    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO iot_device (device_serial, last_reported_battery, last_battery_report)
            VALUES (%s, 100, CURRENT_TIMESTAMP)
        ''', (device_serial,))
        device_id = cursor.lastrowid

        cursor.execute('''
            INSERT INTO prescription_config
            (patient_id, medication_id, dosage_tablet, dispense_schedule, start_date)
            VALUES (%s, %s, 1.0, '0 8 * * *', CURRENT_DATE)
        ''', (patient_id, medication_id))

        cursor.execute('''
            UPDATE medications
            SET device_id = %s, motor_slot = %s,
                current_inventory = %s, refill_threshold = %s
            WHERE medication_id = %s
        ''', (device_id, motor_slot, inventory, threshold, medication_id))

        conn.commit()
    sync_patient_caregiver_stock_notifications(patient_id)
    return jsonify({"success": True, "message": "Device and prescription created"})

@device_bp.route('/device/<int:device_id>/prescription', methods=['PUT'])
def update_device_prescription(device_id):
    data = request.get_json()
    patient_id = data.get('patient_id')
    motor_slot = data.get('motor_slot')
    medication_id = data.get('medication_id')
    inventory = data.get('current_inventory')
    threshold = data.get('refill_threshold')

    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT IGNORE INTO prescription_config (patient_id, medication_id, dosage_tablet, dispense_schedule, start_date)
            VALUES (%s, %s, 1.0, '0 8 * * *', CURRENT_DATE)
        ''', (patient_id, medication_id))

        cursor.execute('''
            UPDATE medications
            SET device_id = %s, motor_slot = %s,
                current_inventory = %s, refill_threshold = %s
            WHERE medication_id = %s
        ''', (device_id, motor_slot, inventory, threshold, medication_id))

        conn.commit()
    sync_patient_caregiver_stock_notifications(patient_id)
    return jsonify({"success": True, "message": "Prescription updated"})

@device_bp.route('/device/<int:device_id>/patient/<int:patient_id>/prescription', methods=['GET'])
def get_prescription_for_device_patient_route(device_id, patient_id):
    try:
        result = get_prescription_for_device_patient_model(device_id, patient_id)
        return jsonify({"success": True, "data": result})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@device_bp.route('/device/dispense_missed', methods=['POST'])
def dispense_missed():
    try:
        data = request.get_json()
        adlog_id = data.get('adlog_id')
        if not adlog_id:
            return jsonify({"success": False, "message": "adlog_id required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE adherence_logs
                SET status = 'MISSED', dispensed_time = NULL
                WHERE adlog_id = %s AND status = 'PENDING'
            ''', (adlog_id,))
            conn.commit()
            affected = cursor.rowcount
            cursor.close()

        if affected:
            return jsonify({"success": True, "message": "Marked as MISSED"})
        else:
            return jsonify({"success": False, "message": "No pending log found"}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
