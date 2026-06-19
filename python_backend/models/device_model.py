# device_model.py - Database operations for IoT devices, including CRUD, heartbeat, and dispense logic

from db import get_db_connection
from datetime import datetime
from models.notification_model import sync_patient_caregiver_stock_notifications


# ---------------------- Get Device by ID ----------------------
def get_device_by_id(device_id):
    """
    Retrieve a single device record by its internal device_id.
    Returns a dict with device_id, serial, battery_level, last_active_timestamp, and last_known_ip.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT device_id, 
                   device_serial, 
                   last_reported_battery AS battery_level, 
                   last_battery_report AS last_active_timestamp, 
                   last_known_ip
            FROM iot_device 
            WHERE device_id = %s
        ''', (device_id,))
        device = cursor.fetchone()
        cursor.close()
    return device


# ---------------------- Get Device by Serial Number ----------------------
def get_device_by_serial(device_serial):
    """
    Retrieve a full device record by its unique serial number.
    Returns a dict with all columns from iot_device.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('SELECT * FROM iot_device WHERE device_serial = %s', (device_serial,))
        device = cursor.fetchone()
        cursor.close()
    return device


# ---------------------- Get All Devices ----------------------
def get_all_devices():
    """
    Fetch all devices from the iot_device table.
    Converts datetime fields to ISO format strings for JSON serialization.
    Returns a list of dicts.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT device_id, device_serial, last_reported_battery AS battery_level,
                   last_battery_report AS last_active_timestamp, last_known_ip
            FROM iot_device
            ORDER BY device_id
        ''')
        devices = cursor.fetchall()
        cursor.close()

    # Convert datetime objects to strings to avoid JSON serialization errors
    for device in devices:
        if isinstance(device.get('last_active_timestamp'), datetime):
            device['last_active_timestamp'] = device['last_active_timestamp'].isoformat()
    return devices


# ---------------------- Get Patient Associated with a Device ----------------------
def get_patient_by_device(device_id):
    """
    Find the patient currently assigned to this device (via an active prescription).
    Returns a dict with device_id, patient_id, and patient_name, or None if not found.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT m.device_id, pc.patient_id, u.full_name AS patient_name
            FROM medications m
            JOIN prescription_config pc ON m.medication_id = pc.medication_id
            JOIN patient p ON pc.patient_id = p.patient_id
            JOIN users u ON p.patient_id = u.user_id
            WHERE m.device_id = %s
            LIMIT 1
        ''', (device_id,))
        result = cursor.fetchone()
        cursor.close()
    return result


# ---------------------- Get Device ID by Serial ----------------------
def get_device_id_by_serial(device_serial):
    """
    Utility function: given a device serial, return its device_id.
    Returns None if not found.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT device_id FROM iot_device WHERE device_serial = %s', (device_serial,))
        row = cursor.fetchone()
        cursor.close()
    return row[0] if row else None


# ---------------------- Add a New Device ----------------------
def add_new_device(device_serial, battery_level, ip_address):
    """
    Register a new IoT device.
    - Checks for duplicate serial; fails if already exists.
    - Inserts with current timestamp for battery report and given IP.
    Returns (success, message, device_id).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Check for duplicate serial
        cursor.execute('SELECT device_id FROM iot_device WHERE device_serial = %s', (device_serial,))
        if cursor.fetchone():
            return False, "Device with this serial already exists", None

        # Insert new device
        cursor.execute('''
            INSERT INTO iot_device (device_serial, last_reported_battery, last_battery_report, last_known_ip)
            VALUES (%s, %s, %s, %s)
        ''', (device_serial, battery_level, datetime.now(), ip_address))
        device_id = cursor.lastrowid
        conn.commit()
        cursor.close()
    return True, "Success", device_id


# ---------------------- Update Device Serial Number ----------------------
def update_device_serial(device_id, new_serial):
    """
    Change the serial number of an existing device.
    - Checks that the new serial is not already used by another device.
    Returns (success, message).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Ensure the new serial is unique (excluding this device)
        cursor.execute('SELECT device_id FROM iot_device WHERE device_serial = %s AND device_id != %s', (new_serial, device_id))
        if cursor.fetchone():
            return False, "Serial number already used by another device"

        # Update the serial
        cursor.execute('''
            UPDATE iot_device 
            SET device_serial = %s
            WHERE device_id = %s
        ''', (new_serial, device_id))
        
        if cursor.rowcount > 0:
            conn.commit()
            return True, "Success"
        else:
            return False, "Device not found"


# ---------------------- Delete a Device ----------------------
def delete_device(device_id):
    """
    Delete a device from the system.
    First, clears device_id reference from any medications (set to NULL).
    Then deletes the device row.
    Returns (success, message).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Remove reference from medications
        cursor.execute('UPDATE medications SET device_id = NULL WHERE device_id = %s', (device_id,))
        # Delete the device itself
        cursor.execute('DELETE FROM iot_device WHERE device_id = %s', (device_id,))
        deleted_count = cursor.rowcount
        conn.commit()
        cursor.close()
        
    if deleted_count > 0:
        return True, "Device deleted successfully"
    else:
        return False, "Device not found"


# ---------------------- Record Device Heartbeat (Keep-Alive) ----------------------
def record_device_heartbeat(device_serial, battery_level, ip_address, wifi_rssi=None):
    """
    Update device status upon receiving a heartbeat from the ESP32.
    Updates battery level, timestamp, IP, and Wi‑Fi RSSI (if provided).
    Returns (success, message).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        # Verify the device exists
        cursor.execute('SELECT device_id FROM iot_device WHERE device_serial = %s', (device_serial,))
        device = cursor.fetchone()

        if device:
            # Update all relevant fields
            cursor.execute('''
                UPDATE iot_device 
                SET last_reported_battery = %s, 
                    last_battery_report = %s,
                    last_known_ip = %s,
                    wifi_rssi = %s
                WHERE device_serial = %s
            ''', (battery_level, datetime.now(), ip_address, wifi_rssi, device_serial))
            conn.commit()
            cursor.close()
            return True, "Heartbeat logged"
        else:
            cursor.close()
            return False, "Device not found"


# ---------------------- Get Pending Dose for Device (Polling) ----------------------
def get_pending_dose_for_device(device_serial):
    """
    Query for the next pending dose that should be dispensed by the device.
    - Finds a PENDING adherence log for any medication linked to this device.
    - The dose must be scheduled at or before the current time.
    - Returns the earliest such pending dose (LIMIT 1), including:
        adlog_id, scheduled_time, prescription_id, dosage_tablet, motor_slot,
        patient_id, medication_name, and current_inventory.
    - Returns None if no pending dose exists.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT al.adlog_id, al.scheduled_time, al.prescription_id,
                   pc.dosage_tablet, med.motor_slot, pc.patient_id,
                   m.medication_name,
                   m.current_inventory   -- include current stock for availability check
            FROM iot_device d
            JOIN medications med ON d.device_id = med.device_id
            JOIN prescription_config pc ON med.medication_id = pc.medication_id
            JOIN adherence_logs al ON pc.prescription_id = al.prescription_id
            JOIN medications m ON pc.medication_id = m.medication_id
            WHERE d.device_serial = %s
              AND al.status = 'PENDING'
              AND al.scheduled_time <= CURRENT_TIMESTAMP
            ORDER BY al.scheduled_time ASC
            LIMIT 1
        ''', (device_serial,))
        pending = cursor.fetchone()
        cursor.close()
    return pending


# ---------------------- Get Device IP for a Patient (for remote control) ----------------------
def get_device_ip_for_patient(patient_id):
    """
    Retrieve the last known IP address and device_id of the device assigned to a patient.
    Used for sending direct HTTP commands to the ESP32 (LED, buzzer, etc.).
    Returns a dict with last_known_ip and device_id, or None if not found.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT d.last_known_ip, d.device_id
            FROM iot_device d
            JOIN medications m ON d.device_id = m.device_id
            JOIN prescription_config pc ON m.medication_id = pc.medication_id
            WHERE pc.patient_id = %s
            LIMIT 1
        ''', (patient_id,))
        device = cursor.fetchone()
        cursor.close()
    return device


# ---------------------- Record a Successful Dispense from Device ----------------------
def record_dispense_from_device(adlog_id, prescription_id):
    """
    Called when the device reports that a dose has been successfully dispensed.
    - Updates the adherence log status from PENDING to TAKEN, sets dispensed_time.
    - Decrements the medication's inventory by the dosage_tablet (if inventory > 0).
    - (Optional) Marks reminders as read – currently commented out.
    - Triggers stock notification sync for the patient's caregivers.
    Returns (True, "Success").
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Get patient_id from the prescription (needed for notification sync)
        cursor.execute('SELECT patient_id FROM prescription_config WHERE prescription_id = %s', (prescription_id,))
        row = cursor.fetchone()
        patient_id = row[0] if row else None

        # 1. Update adherence log to TAKEN
        cursor.execute('''
            UPDATE adherence_logs 
            SET status = 'TAKEN', dispensed_time = CURRENT_TIMESTAMP 
            WHERE adlog_id = %s
        ''', (adlog_id,))

        # 2. Decrease inventory by the dosage amount
        cursor.execute('''
            UPDATE medications m
            JOIN prescription_config pc ON m.medication_id = pc.medication_id
            SET m.current_inventory = m.current_inventory - pc.dosage_tablet, 
                m.updated_at = CURRENT_TIMESTAMP
            WHERE pc.prescription_id = %s AND m.current_inventory > 0
        ''', (prescription_id,))
        
        # (Optional) Clear reminder notifications for this patient – currently commented out.
        # if patient_id:
        #     cursor.execute('''
        #         UPDATE notifications
        #         SET is_read = 1
        #         WHERE recipient_id = %s
        #           AND type = 'REMINDER'
        #           AND is_read = 0
        #     ''', (patient_id,))
        
        conn.commit()
        cursor.close()

    # Sync stock notifications so caregivers are alerted if inventory is low
    if patient_id:
        sync_patient_caregiver_stock_notifications(patient_id)
    return True, "Success"