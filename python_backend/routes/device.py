# device.py - Blueprint for IoT device management, control, and communication

from flask import Blueprint, request, jsonify

# Device model functions for CRUD and operations
from models.device_model import (
    get_device_by_serial,
    get_all_devices as get_all_devices_model,   # Alias to avoid conflict with route name
    get_device_by_id as get_device_by_id_model,
    get_patient_by_device,
    add_new_device,
    update_device_serial as update_device_serial_model,
    delete_device as delete_device_model,
    record_device_heartbeat,
    get_pending_dose_for_device,
    get_device_ip_for_patient,
    record_dispense_from_device
)

# Medication model functions for device‑prescription linkage
from models.medication_model import (
    get_prescriptions_by_device,
    get_prescription_for_device_patient as get_prescription_for_device_patient_model
)

# Notification sync for stock alerts
from models.notification_model import sync_patient_caregiver_stock_notifications

# Utility to forward HTTP commands to the ESP32 device
from services.esp_forwarder import _forward_to_esp

# Database connection for raw queries when needed
from db import get_db_connection

# Create Blueprint for device routes
device_bp = Blueprint('device', __name__)


# ---------------------- Control LED on Device ----------------------
@device_bp.route('/device/control/led', methods=['POST'])
def control_led():
    """
    Turn the LED on or off on the patient's associated ESP32 device.
    Expects JSON: patient_id and action ('on'/'off').
    Uses the device's last known IP to send the command via HTTP.
    """
    data = request.get_json()
    patient_id = data.get('patient_id')
    action = data.get('action')

    # Validate input
    if not patient_id or action not in ('on', 'off'):
        return jsonify({"success": False, "message": "patient_id and action (on/off) required"}), 400

    # Get the device IP for this patient (from their assigned device)
    device = get_device_ip_for_patient(patient_id)

    if not device or not device['last_known_ip']:
        return jsonify({"success": False, "message": "Device IP not known"}), 404

    # Forward the command to the ESP32
    status_code, response = _forward_to_esp(device['last_known_ip'], f"/led/{action}")
    if status_code == 200:
        return jsonify({"success": True, "message": f"LED turned {action}"})
    else:
        return jsonify({"success": False, "message": f"ESP32 error: {response}"}), 500


# ---------------------- Get Device IP by Device ID ----------------------
@device_bp.route('/device/<int:device_id>/ip', methods=['GET'])
def get_device_ip(device_id):
    """
    Retrieve the last known IP address of a device by its ID.
    Used mainly for diagnostics.
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute('SELECT last_known_ip FROM iot_device WHERE device_id = %s', (device_id,))
            row = cursor.fetchone()
            cursor.close()
        if row and row['last_known_ip']:
            return jsonify({"success": True, "ip": row['last_known_ip']})
        else:
            return jsonify({"success": False, "error": "IP not found"}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Control Buzzer on Device ----------------------
@device_bp.route('/device/control/buzzer', methods=['POST'])
def control_buzzer():
    """
    Turn the buzzer on or off on the patient's ESP32.
    Expects JSON: patient_id and action ('on'/'off').
    """
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


# ---------------------- Control Display on Device ----------------------
@device_bp.route('/device/control/display', methods=['POST'])
def control_display():
    """
    Send a display command to the ESP32 (e.g., show 'hello', clear screen, or 'sv' for status).
    Expects JSON: patient_id and command ('hello', 'clear', or 'sv').
    """
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


# ---------------------- Control Stepper Motor on Device ----------------------
@device_bp.route('/device/control/stepper', methods=['POST'])
def control_stepper():
    """
    Control a stepper motor on the ESP32 (for pill dispensing).
    Expects JSON: patient_id, motor (1-3), action (forward/backward/90/180).
    The motor number determines which motor slot to control.
    """
    data = request.get_json()
    patient_id = data.get('patient_id')
    motor = data.get('motor')
    action = data.get('action')

    # Validate inputs
    if not patient_id or motor not in (1, 2, 3) or action not in ('forward', 'backward', '90', '180'):
        return jsonify({"success": False, "message": "patient_id, motor(1-3), action(forward/backward/90/180) required"}), 400

    device = get_device_ip_for_patient(patient_id)

    if not device or not device['last_known_ip']:
        return jsonify({"success": False, "message": "Device IP not known"}), 404

    # Build endpoint: if motor=1, use /stepper/forward; else /stepper2/forward etc.
    motor_prefix = "" if motor == 1 else str(motor)
    endpoint = f"/stepper{motor_prefix}/{action}"
    status_code, response = _forward_to_esp(device['last_known_ip'], endpoint)
    if status_code == 200:
        return jsonify({"success": True, "message": f"Motor {motor} {action} command sent"})
    else:
        return jsonify({"success": False, "message": f"ESP32 error: {response}"}), 500


# ---------------------- Update Device Serial Number ----------------------
@device_bp.route('/iot_device/<int:device_id>', methods=['PUT'])
def update_device(device_id):
    """
    Update the serial number of an existing device.
    Expects JSON: device_serial (new serial).
    """
    data = request.get_json()
    new_serial = data.get('device_serial')
    if not new_serial:
        return jsonify({"success": False, "message": "device_serial required"}), 400

    updated = update_device_serial_model(device_id, new_serial)
    if updated:
        return jsonify({"success": True, "message": "Device updated"})
    else:
        return jsonify({"success": False, "message": "Device not found"}), 404


# ---------------------- Delete a Device ----------------------
@device_bp.route('/iot_device/<int:device_id>', methods=['DELETE'])
def delete_device_route(device_id):
    """
    Delete a device from the system (if not referenced by any medication/prescription).
    """
    success, msg = delete_device_model(device_id)
    if success:
        return jsonify({"success": True, "message": msg})
    else:
        return jsonify({"success": False, "message": msg}), 404


# ---------------------- Add a New Device ----------------------
@device_bp.route('/iot_device', methods=['POST'])
def add_device():
    """
    Register a new IoT device in the system.
    Expects JSON: device_serial (required), last_known_ip (optional, falls back to request IP),
    battery (optional, default 100).
    Returns the new device_id.
    """
    data = request.get_json()
    device_serial = data.get('device_serial')
    # If IP not provided, use the request's remote address (but may be a proxy IP)
    ip_address = data.get('last_known_ip') or request.remote_addr
    battery_level = data.get('battery', 100)

    if not device_serial:
        return jsonify({"success": False, "message": "device_serial required"}), 400

    # Model returns (success, message, device_id)
    success, msg, device_id = add_new_device(device_serial, battery_level, ip_address)
    if not success:
        return jsonify({"success": False, "message": msg}), 400

    return jsonify({"success": True, "message": "Device added", "device_id": device_id})


# ---------------------- Get Device by ID ----------------------
@device_bp.route('/device/<int:device_id>', methods=['GET'])
def get_device_by_id_route(device_id):
    """
    Retrieve full device details by its ID.
    """
    try:
        device = get_device_by_id_model(device_id)
        if device:
            return jsonify({"success": True, "data": device})
        else:
            return jsonify({"success": False, "error": "Device not found"}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Patient Linked to Device ----------------------
@device_bp.route('/device/<int:device_id>/patient', methods=['GET'])
def get_patient_by_device_route(device_id):
    """
    Find the patient currently assigned to this device (via active prescription).
    Returns patient data or None if not assigned.
    """
    try:
        patient = get_patient_by_device(device_id)
        if patient:
            return jsonify({"success": True, "data": patient})
        else:
            return jsonify({"success": True, "data": None})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- List All Devices ----------------------
@device_bp.route('/devices', methods=['GET'])
def get_all_devices():
    """
    Retrieve a list of all registered devices.
    """
    try:
        devices = get_all_devices_model()   # Using the aliased model function
        return jsonify({"success": True, "data": devices})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Prescriptions for a Device ----------------------
@device_bp.route('/device/<int:device_id>/prescriptions', methods=['GET'])
def get_device_prescriptions(device_id):
    """
    Get all prescriptions associated with a given device (via linked medications).
    """
    try:
        prescriptions = get_prescriptions_by_device(device_id)
        return jsonify({"success": True, "data": prescriptions})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Pending Dose for ESP32 (Polling) ----------------------
@device_bp.route('/device/<device_serial>/pending_dose', methods=['GET'])
def get_pending_dose(device_serial):
    """
    Endpoint used by the ESP32 device to poll for due doses to dispense.
    Returns:
      - has_pending: True/False
      - doses: list of due dose objects (each with is_empty + dispense metadata)
      - data: first due dose object (compatibility for older clients)
    This is a critical route for the device's operation.
    """
    try:
        doses = get_pending_dose_for_device(device_serial)

        if doses:
            enriched_doses = []
            for dose in doses:
                item = dict(dose)
                item['is_empty'] = item.get('current_inventory', 0) <= 0

                # Remove inventory field from payload to keep responses lightweight
                if 'current_inventory' in item:
                    del item['current_inventory']

                enriched_doses.append(item)

            # Compatibility fields for older firmware that expects a single `data` item.
            first_dose = enriched_doses[0]
            return jsonify({
                "success": True,
                "has_pending": True,
                "is_empty": first_dose['is_empty'],
                "doses": enriched_doses,
                "data": first_dose
            })
        else:
            return jsonify({"success": True, "has_pending": False})

    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Device Reports Successful Dispense ----------------------
@device_bp.route('/device/dispense_success', methods=['POST'])
def dispense_success():
    """
    Called by the device (or the system) after a dose has been successfully dispensed.
    Expects JSON: adlog_id and prescription_id.
    Updates the adherence log to 'TAKEN' and clears reminders.
    """
    try:
        data = request.get_json()
        adlog_id = data.get('adlog_id')
        prescription_id = data.get('prescription_id')

        record_dispense_from_device(adlog_id, prescription_id)
        return jsonify({"success": True, "message": "Dispense recorded and reminders cleared!"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Device Heartbeat (Keep-Alive) ----------------------
@device_bp.route('/device/heartbeat', methods=['POST'])
def device_heartbeat():
    """
    Endpoint for the ESP32 to report its status periodically.
    Expects JSON: device_serial (required), battery (optional), rssi (optional),
    and IP address (optional; fallback to request.remote_addr).
    Updates the device's last heartbeat timestamp, battery level, and IP.
    """
    try:
        data = request.get_json(silent=True) or {}
        device_serial = data.get('device_serial')
        battery = data.get('battery', 100)
        wifi_rssi = data.get('rssi')

        # Prefer the ESP32's reported IP (since request.remote_addr might be a proxy IP).
        # The ESP32 can send its own IP in the payload.
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


# ---------------------- Test Endpoint for Device (Buzzer) ----------------------
@device_bp.route('/test_device/<int:user_id>', methods=['POST'])
def test_device(user_id):
    """
    Simple test endpoint to simulate sending a buzzer signal to the kit.
    (Probably a placeholder or for testing purposes.)
    """
    return jsonify({"success": True, "message": "Buzzer Signal Sent to Kit! 🔊"})


# ---------------------- Get Device Linked to a Patient (Active Prescription) ----------------------
@device_bp.route('/iot_device/patient/<int:patient_id>', methods=['GET'])
def get_patient_device(patient_id):
    """
    Retrieve the device currently assigned to a patient via an active prescription.
    Returns device details (ID, serial, battery, IP, etc.).
    Only returns the first matching device if multiple exist.
    """
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


# ---------------------- Create Device and Prescription Together ----------------------
@device_bp.route('/device/create_with_prescription', methods=['POST'])
def create_device_with_prescription():
    """
    Convenience endpoint to simultaneously create a device, link it to a medication,
    and create a basic prescription for a patient.
    Expects JSON: device_serial, patient_id, motor_slot, medication_id,
    current_inventory (default 30), refill_threshold (default 10).
    Also syncs stock notifications for patient/caregiver.
    """
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
        # Insert new device
        cursor.execute('''
            INSERT INTO iot_device (device_serial, last_reported_battery, last_battery_report)
            VALUES (%s, 100, CURRENT_TIMESTAMP)
        ''', (device_serial,))
        device_id = cursor.lastrowid

        # Create a default prescription (one tablet, starts today)
        cursor.execute('''
            INSERT INTO prescription_config
            (patient_id, medication_id, dosage_tablet, start_date)
            VALUES (%s, %s, 1.0, CURRENT_DATE)
        ''', (patient_id, medication_id))
        prescription_id = cursor.lastrowid

        # Add a default schedule (once daily at 08:00)
        cursor.execute('''
            INSERT INTO prescription_schedules (prescription_id, dispense_time, day_of_week)
            VALUES (%s, '08:00:00', NULL)
        ''', (prescription_id,))

        # Update the medication with device and slot, and set inventory/threshold
        cursor.execute('''
            UPDATE medications
            SET device_id = %s, motor_slot = %s,
                current_inventory = %s, refill_threshold = %s
            WHERE medication_id = %s
        ''', (device_id, motor_slot, inventory, threshold, medication_id))

        conn.commit()

    # Sync stock notifications for the patient (and caregiver)
    sync_patient_caregiver_stock_notifications(patient_id)
    return jsonify({"success": True, "message": "Device and prescription created"})


# ---------------------- Update Device Prescription (Link) ----------------------
@device_bp.route('/device/<int:device_id>/prescription', methods=['PUT'])
def update_device_prescription(device_id):
    """
    Update or create a prescription linking a device to a patient and medication.
    Expects JSON: patient_id, motor_slot, medication_id, current_inventory, refill_threshold.
    If a prescription doesn't exist, it creates one with default values.
    Also syncs stock notifications.
    """
    data = request.get_json()
    patient_id = data.get('patient_id')
    motor_slot = data.get('motor_slot')
    medication_id = data.get('medication_id')
    inventory = data.get('current_inventory')
    threshold = data.get('refill_threshold')

    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Try to insert a prescription; if already exists, ignore
        cursor.execute('''
            INSERT IGNORE INTO prescription_config (patient_id, medication_id, dosage_tablet, start_date)
            VALUES (%s, %s, 1.0, CURRENT_DATE)
        ''', (patient_id, medication_id))
        prescription_id = cursor.lastrowid  # returns 0 if no insert (if existed)

        # If a new prescription was created, add a default schedule
        if prescription_id:
            cursor.execute('''
                INSERT INTO prescription_schedules (prescription_id, dispense_time, day_of_week)
                VALUES (%s, '08:00:00', NULL)
            ''', (prescription_id,))

        # Update the medication with the new device/slot and inventory
        cursor.execute('''
            UPDATE medications
            SET device_id = %s, motor_slot = %s,
                current_inventory = %s, refill_threshold = %s
            WHERE medication_id = %s
        ''', (device_id, motor_slot, inventory, threshold, medication_id))

        conn.commit()

    # Sync notifications
    sync_patient_caregiver_stock_notifications(patient_id)
    return jsonify({"success": True, "message": "Prescription updated"})


# ---------------------- Get Prescription for Device-Patient Pair ----------------------
@device_bp.route('/device/<int:device_id>/patient/<int:patient_id>/prescription', methods=['GET'])
def get_prescription_for_device_patient_route(device_id, patient_id):
    """
    Retrieve the prescription that links a specific device and patient.
    Used to verify or fetch details for a given pairing.
    """
    try:
        result = get_prescription_for_device_patient_model(device_id, patient_id)
        return jsonify({"success": True, "data": result})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Mark Pending Dose as Missed (Device Timeout) ----------------------
@device_bp.route('/device/dispense_missed', methods=['POST'])
def dispense_missed():
    """
    Called when a pending dose was not dispensed within the allowed window.
    Updates the adherence log status from 'PENDING' to 'MISSED'.
    Expects JSON: adlog_id.
    """
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