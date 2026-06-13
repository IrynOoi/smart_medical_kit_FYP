#device_model.py
from db import get_db_connection
from datetime import datetime
from models.notification_model import sync_patient_caregiver_stock_notifications

def get_device_by_id(device_id):
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

def get_device_by_serial(device_serial):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('SELECT * FROM iot_device WHERE device_serial = %s', (device_serial,))
        device = cursor.fetchone()
        cursor.close()
    return device


def get_all_devices():
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

    # Convert datetime fields to strings to avoid JSON serialization errors
    for device in devices:
        if isinstance(device.get('last_active_timestamp'), datetime):
            device['last_active_timestamp'] = device['last_active_timestamp'].isoformat()
    return devices

def get_patient_by_device(device_id):
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
def get_device_id_by_serial(device_serial):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT device_id FROM iot_device WHERE device_serial = %s', (device_serial,))
        row = cursor.fetchone()
        cursor.close()
    return row[0] if row else None

def add_new_device(device_serial, battery_level, ip_address):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT device_id FROM iot_device WHERE device_serial = %s', (device_serial,))
        if cursor.fetchone():
            return False, "Device with this serial already exists", None

        cursor.execute('''
            INSERT INTO iot_device (device_serial, last_reported_battery, last_battery_report, last_known_ip)
            VALUES (%s, %s, %s, %s)
        ''', (device_serial, battery_level, datetime.now(), ip_address))
        device_id = cursor.lastrowid
        conn.commit()
        cursor.close()
    return True, "Success", device_id

def update_device_serial(device_id, new_serial):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT device_id FROM iot_device WHERE device_serial = %s AND device_id != %s', (new_serial, device_id))
        if cursor.fetchone():
            return False, "Serial number already used by another device"

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

def delete_device(device_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('UPDATE medications SET device_id = NULL WHERE device_id = %s', (device_id,))
        cursor.execute('DELETE FROM iot_device WHERE device_id = %s', (device_id,))
        deleted_count = cursor.rowcount
        conn.commit()
        cursor.close()
        
    if deleted_count > 0:
        return True, "Device deleted successfully"
    else:
        return False, "Device not found"

def record_device_heartbeat(device_serial, battery_level, ip_address, wifi_rssi=None):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('SELECT device_id FROM iot_device WHERE device_serial = %s', (device_serial,))
        device = cursor.fetchone()

        if device:
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

def get_pending_dose_for_device(device_serial):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT al.adlog_id, al.scheduled_time, al.prescription_id,
                   pc.dosage_tablet, med.motor_slot, pc.patient_id,
                   m.medication_name,
                   m.current_inventory  -- 💡 新增：查出当前库存！
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

def get_device_ip_for_patient(patient_id):
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

def record_dispense_from_device(adlog_id, prescription_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        cursor.execute('SELECT patient_id FROM prescription_config WHERE prescription_id = %s', (prescription_id,))
        row = cursor.fetchone()
        patient_id = row[0] if row else None

   # 1. 更新 adherence_logs
        cursor.execute('''
            UPDATE adherence_logs 
            SET status = 'TAKEN', dispensed_time = CURRENT_TIMESTAMP 
            WHERE adlog_id = %s
        ''', (adlog_id,))

        # 2. 扣减库存
        cursor.execute('''
            UPDATE medications m
            JOIN prescription_config pc ON m.medication_id = pc.medication_id
            SET m.current_inventory = m.current_inventory - pc.dosage_tablet, 
                m.updated_at = CURRENT_TIMESTAMP
            WHERE pc.prescription_id = %s AND m.current_inventory > 0
        ''', (prescription_id,))
        
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
    if patient_id:
        sync_patient_caregiver_stock_notifications(patient_id)
    return True, "Success"
