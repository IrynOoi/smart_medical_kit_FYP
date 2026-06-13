#medication_model.py
import datetime
from db import get_db_connection
from models.notification_model import (
    sync_medication_stock_notifications,
    sync_patient_caregiver_stock_notifications,
    sync_prescription_stock_notifications,
)

def record_dispense_inventory(prescription_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT medication_id, patient_id FROM prescription_config WHERE prescription_id = %s', (prescription_id,))
        row = cursor.fetchone()
        if not row:
            return False, "Prescription not found", None
        med_id = row[0]
        patient_id = row[1]

        cursor.execute('''
            UPDATE medications
            SET current_inventory = current_inventory - 1, updated_at = CURRENT_TIMESTAMP
            WHERE medication_id = %s AND current_inventory > 0
        ''', (med_id,))
        
        # cursor.execute('''
        #     UPDATE notifications
        #     SET is_read = 1
        #     WHERE recipient_id = %s
        #       AND type = 'REMINDER'
        #       AND is_read = 0
        # ''', (patient_id,))
        
        conn.commit()
        cursor.close()
    sync_patient_caregiver_stock_notifications(patient_id)
    return True, "Success", patient_id

def create_prescription_config(patient_id, medication_name, dosage_tablet, dispense_schedule, start_date, end_date, current_inventory, refill_threshold, device_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute('SELECT medication_id FROM medications WHERE medication_name = %s', (medication_name,))
        med_row = cursor.fetchone()
        if not med_row:
            return False, f"Medication '{medication_name}' not found", None
        medication_id = med_row['medication_id']

        cursor.execute('''
            INSERT INTO prescription_config 
            (patient_id, medication_id, dosage_tablet, dispense_schedule, start_date, end_date)
            VALUES (%s, %s, %s, %s, %s, %s)
        ''', (patient_id, medication_id, dosage_tablet, dispense_schedule, start_date, end_date))
        new_prescription_id = cursor.lastrowid

        if current_inventory is not None:
            cursor.execute('UPDATE medications SET current_inventory = %s WHERE medication_id = %s',
                        (current_inventory, medication_id))
        if device_id is not None:
            cursor.execute('UPDATE medications SET device_id = %s WHERE medication_id = %s',
                        (device_id, medication_id))
        if refill_threshold is not None:
            cursor.execute('UPDATE medications SET refill_threshold = %s WHERE medication_id = %s',
                        (refill_threshold, medication_id))
        
        new_prescription = {
            "prescription_id": new_prescription_id,
            "patient_id": patient_id,
            "medication_id": medication_id,
            "medication_name": medication_name,
            "dosage_tablet": dosage_tablet,
            "dispense_schedule": dispense_schedule,
            "start_date": start_date,
            "end_date": end_date,
            "created_at": datetime.datetime.now(),
            "updated_at": datetime.datetime.now()
        }
        conn.commit()
        cursor.close()
    sync_patient_caregiver_stock_notifications(patient_id)
    return True, "Success", new_prescription

def get_prescription_details(prescription_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT pc.prescription_id, pc.patient_id, m.medication_name,
                   pc.dosage_tablet, pc.dispense_schedule,
                   m.current_inventory, m.refill_threshold,
                   pc.start_date, pc.end_date,
                   pc.created_at, pc.updated_at,
                   m.device_id, m.motor_slot
            FROM prescription_config pc
            JOIN medications m ON pc.medication_id = m.medication_id
            WHERE pc.prescription_id = %s
        ''', (prescription_id,))
        prescription = cursor.fetchone()
        cursor.close()
    return prescription

def get_prescriptions_by_patient(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT pc.prescription_id, pc.patient_id, m.medication_name,
                   pc.dosage_tablet, pc.dispense_schedule,
                   m.current_inventory, m.refill_threshold,
                   pc.start_date, pc.end_date,
                   pc.created_at, pc.updated_at,
                   m.device_id, m.motor_slot
            FROM prescription_config pc
            JOIN medications m ON pc.medication_id = m.medication_id
            WHERE pc.patient_id = %s 
              AND (pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE)
            ORDER BY pc.start_date ASC
        ''', (patient_id,))
        prescriptions = cursor.fetchall()
        cursor.close()
    return prescriptions

def get_prescriptions_by_device(device_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT 
                pc.prescription_id,
                pc.patient_id,
                med.medication_name,
                pc.dosage_tablet,
                pc.dispense_schedule,
                med.current_inventory,
                med.refill_threshold,
                pc.start_date,
                pc.end_date,
                pc.created_at,
                pc.updated_at,
                med.device_id,
                med.motor_slot,
                u.full_name AS patient_name
            FROM prescription_config pc
            JOIN medications med ON pc.medication_id = med.medication_id
            JOIN patient p ON pc.patient_id = p.patient_id
            JOIN users u ON p.patient_id = u.user_id
            WHERE med.device_id = %s
              AND (pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE)
            ORDER BY med.motor_slot ASC
        ''', (device_id,))
        prescriptions = cursor.fetchall()
        cursor.close()
    return prescriptions

def get_prescription_for_device_patient(device_id, patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT pc.prescription_id, m.motor_slot, m.medication_id,
                   m.current_inventory, m.refill_threshold
            FROM prescription_config pc
            JOIN medications m ON pc.medication_id = m.medication_id
            WHERE pc.patient_id = %s AND m.device_id = %s
            LIMIT 1
        ''', (patient_id, device_id))
        result = cursor.fetchone()
        cursor.close()
    return result

def restock_medication_inventory(prescription_id, quantity):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE medications m
            JOIN prescription_config pc ON m.medication_id = pc.medication_id
            SET m.current_inventory = m.current_inventory + %s,
                m.updated_at = CURRENT_TIMESTAMP
            WHERE pc.prescription_id = %s
        ''', (quantity, prescription_id))
        conn.commit()
        cursor.close()
    sync_prescription_stock_notifications(prescription_id)

def update_prescription_config(prescription_id, medication_name, dosage_tablet, dispense_schedule, start_date, end_date, current_inventory, refill_threshold, device_id, check_device_id_none=False):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        cursor.execute('SELECT medication_id FROM medications WHERE medication_name = %s', (medication_name,))
        med_row = cursor.fetchone()
        if not med_row:
            return False, f"Medication '{medication_name}' not found"
        medication_id = med_row[0]
        
        cursor.execute('''
            UPDATE prescription_config 
            SET medication_id = %s, dosage_tablet = %s, dispense_schedule = %s, 
                start_date = %s, end_date = %s, updated_at = CURRENT_TIMESTAMP
            WHERE prescription_id = %s
        ''', (medication_id, dosage_tablet, dispense_schedule, start_date, end_date, prescription_id))
        
        updates = []
        params = []
        if current_inventory is not None:
            updates.append('current_inventory = %s')
            params.append(current_inventory)
        if refill_threshold is not None:
            updates.append('refill_threshold = %s')
            params.append(refill_threshold)
        if device_id is not None:
            updates.append('device_id = %s')
            params.append(device_id)
        else:
            if check_device_id_none:
                updates.append('device_id = NULL')
        
        if updates:
            query = f"UPDATE medications SET {', '.join(updates)} WHERE medication_id = %s"
            params.append(medication_id)
            cursor.execute(query, tuple(params))
        
        conn.commit()
        cursor.close()
    sync_prescription_stock_notifications(prescription_id)
    return True, "Success"

def delete_prescription_config(prescription_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute('''
            SELECT pc.patient_id, m.medication_name 
            FROM prescription_config pc
            JOIN medications m ON pc.medication_id = m.medication_id
            WHERE pc.prescription_id = %s
        ''', (prescription_id,))
        rx_data = cursor.fetchone()
        
        cursor.execute('DELETE FROM adherence_logs WHERE prescription_id = %s', (prescription_id,))
        cursor.execute('DELETE FROM prescription_config WHERE prescription_id = %s', (prescription_id,))
        conn.commit()
        cursor.close()
    return rx_data

def get_all_medications():
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT m.medication_id, m.medication_name, m.current_inventory,
                   m.refill_threshold, m.device_id, m.motor_slot,
                   m.created_at, m.updated_at,
                   d.device_serial
            FROM medications m
            LEFT JOIN iot_device d ON m.device_id = d.device_id
            ORDER BY m.medication_name
        ''')
        meds = cursor.fetchall()
        cursor.close()
    return meds

def add_new_medication(medication_name, current_inventory, refill_threshold, device_id, motor_slot):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Validate device_id is provided
        if not device_id:
            return False, "Device is required", None
        
        # Check if medication name already exists
        cursor.execute('SELECT medication_id FROM medications WHERE medication_name = %s', (medication_name,))
        if cursor.fetchone():
            return False, "Medication name already exists", None

        # Check if motor slot is already in use for this device
        cursor.execute('SELECT medication_id FROM medications WHERE device_id = %s AND motor_slot = %s', (device_id, motor_slot))
        if cursor.fetchone():
            return False, f"Motor slot {motor_slot} is already in use on this device", None

        # Insert new medication
        cursor.execute('''
            INSERT INTO medications (medication_name, current_inventory, refill_threshold, device_id, motor_slot)
            VALUES (%s, %s, %s, %s, %s)
        ''', (medication_name, current_inventory, refill_threshold, device_id, motor_slot))
        
        medication_id = cursor.lastrowid
        conn.commit()
        cursor.close()
    return True, "Success", medication_id

def update_medication_info(medication_id, new_name, current_inventory, refill_threshold, device_id, motor_slot):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        updates = []
        params = []
        if new_name:
            updates.append("medication_name = %s")
            params.append(new_name)
        if current_inventory is not None:
            updates.append("current_inventory = %s")
            params.append(current_inventory)
        if refill_threshold is not None:
            updates.append("refill_threshold = %s")
            params.append(refill_threshold)
        if device_id is not None:
            updates.append("device_id = %s")
            params.append(device_id)
        if motor_slot is not None:
            updates.append("motor_slot = %s")
            params.append(motor_slot)

        if not updates:
            return False, "No fields to update", None

        params.append(medication_id)
        query = f"UPDATE medications SET {', '.join(updates)}, updated_at = CURRENT_TIMESTAMP WHERE medication_id = %s"
        cursor.execute(query, tuple(params))
        
        if cursor.rowcount > 0:
            cursor.execute('SELECT medication_id, medication_name, current_inventory, refill_threshold, device_id, motor_slot FROM medications WHERE medication_id = %s', (medication_id,))
            updated = cursor.fetchone()
            conn.commit()
            cursor.close()
            sync_medication_stock_notifications(medication_id)
            return True, "Success", updated
        else:
            conn.commit()
            cursor.close()
            return False, "Medication not found", None

def delete_medication_if_unused(medication_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM prescription_config WHERE medication_id = %s', (medication_id,))
        count = cursor.fetchone()[0]
        if count > 0:
            return False, f"Cannot delete: medication is used in {count} prescription(s)"

        cursor.execute('DELETE FROM medications WHERE medication_id = %s', (medication_id,))
        deleted_count = cursor.rowcount
        conn.commit()
        cursor.close()
        
    if deleted_count > 0:
        return True, "Medication deleted"
    else:
        return False, "Medication not found"
