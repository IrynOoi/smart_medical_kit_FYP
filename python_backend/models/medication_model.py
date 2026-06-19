# medication_model.py - Database operations for medications, prescriptions, and adherence logs

import datetime
from db import get_db_connection
from models.notification_model import (
    sync_medication_stock_notifications,
    sync_patient_caregiver_stock_notifications,
    sync_prescription_stock_notifications,
)


# ---------------------- Record a Dispense Event (from device or manual) ----------------------
def record_dispense_inventory(prescription_id):
    """
    Record that a dose has been dispensed for a specific prescription.
    - Decrements the medication's current_inventory by 1 (if inventory > 0).
    - Does NOT clear reminders here (commented out; reminders are cleared elsewhere).
    - Triggers stock notifications sync for the patient's caregivers.
    Returns (success, message, patient_id).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Get medication_id and patient_id for this prescription
        cursor.execute('SELECT medication_id, patient_id FROM prescription_config WHERE prescription_id = %s', (prescription_id,))
        row = cursor.fetchone()
        if not row:
            return False, "Prescription not found", None
        med_id = row[0]
        patient_id = row[1]

        # Decrease inventory by 1, but only if current_inventory > 0 (safety check)
        cursor.execute('''
            UPDATE medications
            SET current_inventory = current_inventory - 1, updated_at = CURRENT_TIMESTAMP
            WHERE medication_id = %s AND current_inventory > 0
        ''', (med_id,))
        
        # (Optional) Clear reminders for this patient – currently commented out.
        # cursor.execute('''
        #     UPDATE notifications
        #     SET is_read = 1
        #     WHERE recipient_id = %s
        #       AND type = 'REMINDER'
        #       AND is_read = 0
        # ''', (patient_id,))
        
        conn.commit()
        cursor.close()

    # Sync stock notifications for all caregivers of this patient
    sync_patient_caregiver_stock_notifications(patient_id)
    return True, "Success", patient_id


# ---------------------- Create a New Prescription Configuration ----------------------
def create_prescription_config(patient_id, medication_name, dosage_tablet, dispense_times, 
                               start_date, end_date, current_inventory, refill_threshold, 
                               device_id, dispense_days=None):
    """
    Create a new prescription for a patient.
    - Looks up the medication by name; fails if not found.
    - Inserts into prescription_config, then adds schedules (one per dispense_time, optionally per day_of_week).
    - Updates the medication's inventory, device_id, and refill_threshold if provided.
    - Syncs stock notifications for the patient's caregivers.
    Returns (success, message, new_prescription_dict).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        # Find the medication ID by name
        cursor.execute('SELECT medication_id FROM medications WHERE medication_name = %s', (medication_name,))
        med_row = cursor.fetchone()
        if not med_row:
            return False, f"Medication '{medication_name}' not found", None
        medication_id = med_row['medication_id']

        # Insert the prescription config
        cursor.execute('''
            INSERT INTO prescription_config 
            (patient_id, medication_id, dosage_tablet, start_date, end_date)
            VALUES (%s, %s, %s, %s, %s)
        ''', (patient_id, medication_id, dosage_tablet, start_date, end_date))
        new_prescription_id = cursor.lastrowid

        # Insert schedules: if dispense_days provided, create entries for each day and time combination
        for dt in dispense_times:
            if dispense_days and len(dispense_days) > 0:
                for day in dispense_days:
                    cursor.execute('''
                        INSERT INTO prescription_schedules (prescription_id, dispense_time, day_of_week)
                        VALUES (%s, %s, %s)
                    ''', (new_prescription_id, dt, day))
            else:
                # No specific days → daily (day_of_week = NULL)
                cursor.execute('''
                    INSERT INTO prescription_schedules (prescription_id, dispense_time, day_of_week)
                    VALUES (%s, %s, NULL)
                ''', (new_prescription_id, dt))

        # Update medication fields if provided
        if current_inventory is not None:
            cursor.execute('UPDATE medications SET current_inventory = %s WHERE medication_id = %s',
                           (current_inventory, medication_id))
        if device_id is not None:
            cursor.execute('UPDATE medications SET device_id = %s WHERE medication_id = %s',
                           (device_id, medication_id))
        if refill_threshold is not None:
            cursor.execute('UPDATE medications SET refill_threshold = %s WHERE medication_id = %s',
                           (refill_threshold, medication_id))
        
        # Build a response dict with the new prescription details
        new_prescription = {
            "prescription_id": new_prescription_id,
            "patient_id": patient_id,
            "medication_id": medication_id,
            "medication_name": medication_name,
            "dosage_tablet": dosage_tablet,
            "dispense_times": dispense_times,
            "dispense_days": dispense_days,
            "start_date": start_date,
            "end_date": end_date,
            "created_at": datetime.datetime.now(),
            "updated_at": datetime.datetime.now()
        }
        conn.commit()
        cursor.close()

    # Sync stock notifications after creation
    sync_patient_caregiver_stock_notifications(patient_id)
    return True, "Success", new_prescription


# ---------------------- Get Prescription Details (including schedules) ----------------------
def get_prescription_details(prescription_id):
    """
    Fetch full details for a single prescription, including:
      - medication name, dosage, inventory, threshold
      - device ID and motor slot
      - dispense_times (list of times)
      - dispense_days (list of day-of-week numbers, if any)
    Returns a dict or None if not found.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT pc.prescription_id, pc.patient_id, m.medication_name,
                   pc.dosage_tablet,
                   m.current_inventory, m.refill_threshold,
                   pc.start_date, pc.end_date,
                   pc.created_at, pc.updated_at,
                   m.device_id, m.motor_slot
            FROM prescription_config pc
            JOIN medications m ON pc.medication_id = m.medication_id
            WHERE pc.prescription_id = %s
        ''', (prescription_id,))
        prescription = cursor.fetchone()
        if prescription:
            # Fetch distinct dispense times (sorted)
            cursor.execute('SELECT DISTINCT dispense_time FROM prescription_schedules WHERE prescription_id = %s ORDER BY dispense_time ASC', (prescription_id,))
            times = cursor.fetchall()
            prescription['dispense_times'] = [str(t['dispense_time']) for t in times]
            
            # Fetch distinct day_of_week (non-null)
            cursor.execute('SELECT DISTINCT day_of_week FROM prescription_schedules WHERE prescription_id = %s AND day_of_week IS NOT NULL ORDER BY day_of_week ASC', (prescription_id,))
            days = cursor.fetchall()
            prescription['dispense_days'] = [int(d['day_of_week']) for d in days]
        cursor.close()
    return prescription


# ---------------------- Get Active Prescriptions for a Patient ----------------------
def get_prescriptions_by_patient(patient_id):
    """
    Fetch all active prescriptions for a given patient (end_date >= today or NULL).
    Includes medication details and schedules (times, days).
    Returns a list of dicts.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT pc.prescription_id, pc.patient_id, m.medication_name,
                   pc.dosage_tablet,
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
        for p in prescriptions:
            # Add schedules
            cursor.execute('SELECT DISTINCT dispense_time FROM prescription_schedules WHERE prescription_id = %s ORDER BY dispense_time ASC', (p['prescription_id'],))
            times = cursor.fetchall()
            p['dispense_times'] = [str(t['dispense_time']) for t in times]
            
            cursor.execute('SELECT DISTINCT day_of_week FROM prescription_schedules WHERE prescription_id = %s AND day_of_week IS NOT NULL ORDER BY day_of_week ASC', (p['prescription_id'],))
            days = cursor.fetchall()
            p['dispense_days'] = [int(d['day_of_week']) for d in days]
        cursor.close()
    return prescriptions


# ---------------------- Get Prescriptions by Device (for IoT device management) ----------------------
def get_prescriptions_by_device(device_id):
    """
    Fetch all active prescriptions linked to a given device (via medications.device_id).
    Includes patient name, medication details, and schedules.
    Used by the device to know which medications it should dispense.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT 
                pc.prescription_id,
                pc.patient_id,
                med.medication_id,           -- explicit medication_id
                med.medication_name,
                pc.dosage_tablet,
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
        for p in prescriptions:
            cursor.execute('SELECT DISTINCT dispense_time FROM prescription_schedules WHERE prescription_id = %s ORDER BY dispense_time ASC', (p['prescription_id'],))
            times = cursor.fetchall()
            p['dispense_times'] = [str(t['dispense_time']) for t in times]
            
            cursor.execute('SELECT DISTINCT day_of_week FROM prescription_schedules WHERE prescription_id = %s AND day_of_week IS NOT NULL ORDER BY day_of_week ASC', (p['prescription_id'],))
            days = cursor.fetchall()
            p['dispense_days'] = [int(d['day_of_week']) for d in days]
        cursor.close()
    return prescriptions


# ---------------------- Get Prescription for a Device-Patient Pair (single) ----------------------
def get_prescription_for_device_patient(device_id, patient_id):
    """
    Find the (first) active prescription linking a specific device and patient.
    Used to verify a device-patient association and get motor slot/inventory info.
    Returns a dict with prescription_id, motor_slot, medication_id, current_inventory, refill_threshold,
    or None if not found.
    """
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


# ---------------------- Restock Medication Inventory ----------------------
def restock_medication_inventory(prescription_id, quantity, set_inventory=False):
    """
    Add to (or set) the inventory for the medication linked to a prescription.
    - If set_inventory=True, sets the inventory exactly to quantity.
    - Otherwise, adds quantity to current inventory.
    Triggers stock notification sync for that prescription.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Get the medication_id for this prescription
        cursor.execute('SELECT medication_id FROM prescription_config WHERE prescription_id = %s', (prescription_id,))
        row = cursor.fetchone()
        if not row:
            return
        medication_id = row[0]
        # Perform update
        if set_inventory:
            cursor.execute('UPDATE medications SET current_inventory = %s, updated_at = CURRENT_TIMESTAMP WHERE medication_id = %s',
                           (quantity, medication_id))
        else:
            cursor.execute('UPDATE medications SET current_inventory = current_inventory + %s, updated_at = CURRENT_TIMESTAMP WHERE medication_id = %s',
                           (quantity, medication_id))
        conn.commit()
        cursor.close()
    # Sync notifications for the prescription (affects caregiver)
    sync_prescription_stock_notifications(prescription_id)


# ---------------------- Update an Existing Prescription Configuration ----------------------
def update_prescription_config(prescription_id, medication_name, dosage_tablet, dispense_times,
                               start_date, end_date, current_inventory, refill_threshold,
                               device_id, check_device_id_none=False, dispense_days=None):
    """
    Update a prescription's details and schedules.
    - Looks up medication by name (must exist).
    - Updates prescription_config fields.
    - Replaces all schedules with new ones (delete old, insert new).
    - Updates medication fields (inventory, threshold, device) only if provided.
    - If check_device_id_none is True, explicitly sets device_id to NULL.
    Triggers stock notification sync for the prescription.
    Returns (success, message).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Get the medication ID by name
        cursor.execute('SELECT medication_id FROM medications WHERE medication_name = %s', (medication_name,))
        med_row = cursor.fetchone()
        if not med_row:
            return False, f"Medication '{medication_name}' not found"
        medication_id = med_row[0]
        
        # Update the prescription config
        cursor.execute('''
            UPDATE prescription_config 
            SET medication_id = %s, dosage_tablet = %s, 
                start_date = %s, end_date = %s, updated_at = CURRENT_TIMESTAMP
            WHERE prescription_id = %s
        ''', (medication_id, dosage_tablet, start_date, end_date, prescription_id))
        
        # Delete old schedules and insert new ones
        cursor.execute('DELETE FROM prescription_schedules WHERE prescription_id = %s', (prescription_id,))
        for dt in dispense_times:
            if dispense_days and len(dispense_days) > 0:
                for day in dispense_days:
                    cursor.execute('''
                        INSERT INTO prescription_schedules (prescription_id, dispense_time, day_of_week)
                        VALUES (%s, %s, %s)
                    ''', (prescription_id, dt, day))
            else:
                cursor.execute('''
                    INSERT INTO prescription_schedules (prescription_id, dispense_time, day_of_week)
                    VALUES (%s, %s, NULL)
                ''', (prescription_id, dt))

        # Update medication fields if provided
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
            # If device_id is explicitly None and check_device_id_none is True, set to NULL
            if check_device_id_none:
                updates.append('device_id = NULL')
        
        if updates:
            query = f"UPDATE medications SET {', '.join(updates)} WHERE medication_id = %s"
            params.append(medication_id)
            cursor.execute(query, tuple(params))
        
        conn.commit()
        cursor.close()

    # Sync stock notifications for this prescription
    sync_prescription_stock_notifications(prescription_id)
    return True, "Success"


# ---------------------- Delete (Soft) Prescription Configuration ----------------------
def delete_prescription_config(prescription_id):
    """
    Soft‑delete a prescription by removing all related records:
      - adherence_logs for this prescription
      - prescription_schedules
      - prescription_config (the main record)
    Returns a dict with patient_id and medication_name for notification purposes,
    or None if the prescription didn't exist.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        # Fetch patient_id and medication_name before deletion (for notification)
        cursor.execute('''
            SELECT pc.patient_id, m.medication_name 
            FROM prescription_config pc
            JOIN medications m ON pc.medication_id = m.medication_id
            WHERE pc.prescription_id = %s
        ''', (prescription_id,))
        rx_data = cursor.fetchone()
        
        # Delete dependent records
        cursor.execute('DELETE FROM adherence_logs WHERE prescription_id = %s', (prescription_id,))
        cursor.execute('DELETE FROM prescription_schedules WHERE prescription_id = %s', (prescription_id,))
        cursor.execute('DELETE FROM prescription_config WHERE prescription_id = %s', (prescription_id,))
        conn.commit()
        cursor.close()
    return rx_data   # may be None if not found


# ---------------------- Get All Medications (Master Catalog) ----------------------
def get_all_medications():
    """
    Retrieve the full list of medications from the master catalog,
    including device serial (if assigned). Ordered by name.
    Returns a list of dicts.
    """
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


# ---------------------- Add a New Medication to the Master Catalog ----------------------
def add_new_medication(medication_name, current_inventory, refill_threshold, device_id, motor_slot):
    """
    Add a new medication entry.
    - Requires device_id (must be provided).
    - Checks for duplicate name and that the motor slot is not already taken on the device.
    Returns (success, message, medication_id).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Device must be provided
        if not device_id:
            return False, "Device is required", None
        
        # Check for duplicate name
        cursor.execute('SELECT medication_id FROM medications WHERE medication_name = %s', (medication_name,))
        if cursor.fetchone():
            return False, "Medication name already exists", None

        # Check if motor slot is already in use on this device
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


# ---------------------- Update an Existing Medication (Master Catalog) ----------------------
def update_medication_info(medication_id, new_name, current_inventory, refill_threshold, device_id, motor_slot):
    """
    Update a medication's attributes.
    Only fields that are not None will be updated.
    Returns (success, message, updated_tuple) if successful.
    Triggers stock notification sync for the medication.
    """
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
            # Fetch the updated record
            cursor.execute('SELECT medication_id, medication_name, current_inventory, refill_threshold, device_id, motor_slot FROM medications WHERE medication_id = %s', (medication_id,))
            updated = cursor.fetchone()
            conn.commit()
            cursor.close()
            # Sync stock notifications for this medication
            sync_medication_stock_notifications(medication_id)
            return True, "Success", updated
        else:
            conn.commit()
            cursor.close()
            return False, "Medication not found", None


# ---------------------- Delete a Medication (Only If Not Used in Prescriptions) ----------------------
def delete_medication_if_unused(medication_id):
    """
    Delete a medication from the master catalog only if it is not referenced
    in any prescription_config (active or inactive).
    Returns (success, message).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Check usage count
        cursor.execute('SELECT COUNT(*) FROM prescription_config WHERE medication_id = %s', (medication_id,))
        count = cursor.fetchone()[0]
        if count > 0:
            return False, f"Cannot delete: medication is used in {count} prescription(s)"

        # Delete the medication
        cursor.execute('DELETE FROM medications WHERE medication_id = %s', (medication_id,))
        deleted_count = cursor.rowcount
        conn.commit()
        cursor.close()
        
    if deleted_count > 0:
        return True, "Medication deleted"
    else:
        return False, "Medication not found"