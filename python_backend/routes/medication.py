# medication.py - Blueprint for medication, prescription, and adherence log management

# Import notification function to sync stock alerts (used when inventory changes)
from models.notification_model import sync_medication_stock_notifications
from db import get_db_connection  # For raw database queries when needed
import datetime  # (unused here but may be for future use)
from flask import Blueprint, request, jsonify

# Import medication model functions for database operations
from models.medication_model import (
    record_dispense_inventory,      # Logs a dispense event and updates inventory
    create_prescription_config,     # Creates a new prescription (links patient/medication)
    get_prescription_details,       # Retrieves prescription details by ID
    restock_medication_inventory,   # Adds inventory to a prescription's medication
    update_prescription_config,     # Updates prescription fields
    delete_prescription_config,     # Soft‑deletes a prescription config
    get_all_medications,            # List all medications in the system
    add_new_medication,             # Adds a new medication (without prescription)
    update_medication_info,         # Updates a medication's attributes
    delete_medication_if_unused     # Deletes a medication if not referenced by any prescription
)

# Adherence model functions for logging and retaking missed doses
from models.adherence_model import retake_missed_dose as model_retake_missed_dose
from models.adherence_model import save_medication_log, get_all_medication_logs

# Notification service functions (send push/in‑app notifications)
from services.notification_service import send_new_prescription_notification, send_removed_prescription_notification

# Create Blueprint for medication routes
medication_bp = Blueprint('medication', __name__)


# ---------------------- Record Medication Dispense ----------------------
@medication_bp.route('/record_medication', methods=['POST'])
def record_medication():
    """
    Record a dispense event from a device (e.g., pill dispenser).
    Expects JSON: prescription_id and device_id.
    After successful recording, reminders are cleared for that medication.
    """
    try:
        data = request.get_json()
        prescription_id = data.get('prescription_id')
        device_id = data.get('device_id')

        # Validate required fields
        if not prescription_id or not device_id:
            return jsonify({"success": False, "message": "prescription_id and device_id are required"}), 400

        # Call model to record dispense; returns success flag, message, and patient_id (unused)
        success, msg, patient_id = record_dispense_inventory(prescription_id)
        if not success:
            return jsonify({"success": False, "message": msg}), 404

        return jsonify({"success": True, "message": "Medication recorded and reminders cleared!"})
    except Exception as e:
        print(f"Record medication error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Add a New Prescription ----------------------
@medication_bp.route('/add_prescription', methods=['POST'])
def add_prescription():
    """
    Create a new prescription configuration for a patient.
    Expects JSON: patient_id, medication_name, dosage_tablet, dispense_times,
                  current_inventory, refill_threshold, start_date, end_date, device_id.
    Sends a notification to the patient about the new prescription.
    """
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        medication_name = data.get('medication_name')
        dosage_tablet = data.get('dosage_tablet')
        dispense_times = data.get('dispense_times')   # List of times (e.g., ["08:00", "20:00"])
        dispense_days = data.get('dispense_days')
        current_inventory = data.get('current_inventory')
        refill_threshold = data.get('refill_threshold')
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        device_id = data.get('device_id')

        # Required fields: patient, medication, dosage, times, and start date
        if not all([patient_id, medication_name, dosage_tablet, dispense_times, start_date]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        # Call model to create prescription; returns success, message, and new prescription data
        success, msg, new_prescription = create_prescription_config(
            patient_id, medication_name, dosage_tablet, dispense_times,
            start_date, end_date, current_inventory, refill_threshold, device_id, dispense_days
        )

        if not success:
            return jsonify({"success": False, "message": msg}), 400

        # Notify patient about the new prescription
        send_new_prescription_notification(patient_id, medication_name)

        return jsonify({"success": True, "message": "Prescription created successfully!", "data": new_prescription})
    except Exception as e:
        print(f"Add prescription error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get Prescription Details ----------------------
@medication_bp.route('/prescription/<int:prescription_id>', methods=['GET'])
def get_prescription_details(prescription_id):
    """
    Retrieve all details for a single prescription by its ID.
    Returns 404 if not found.
    """
    try:
        prescription = get_prescription_details(prescription_id)

        if prescription:
            return jsonify({"success": True, "data": prescription})
        else:
            return jsonify({"success": False, "error": "Prescription not found"}), 404
    except Exception as e:
        print(f"Get prescription details error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Restock / Set Medication Inventory ----------------------
@medication_bp.route('/restock_medication', methods=['POST'])
def restock_medication():
    """
    Add to or set the inventory of a medication.
    Can be called with either prescription_id or medication_id.
    Body: prescription_id OR medication_id, quantity (default 30), set_inventory (bool, default False).
    If set_inventory is True, the quantity is set exactly; otherwise it is added.
    Also syncs stock notification alerts.
    """
    try:
        data = request.get_json()
        prescription_id = data.get('prescription_id')
        medication_id = data.get('medication_id')
        quantity = data.get('quantity', 30)
        set_inventory = data.get('set_inventory', False)   # True = set absolute, False = add

        # Need at least one identifier
        if not prescription_id and not medication_id:
            return jsonify({"success": False, "message": "prescription_id or medication_id required"}), 400
        if quantity < 0:
            return jsonify({"success": False, "message": "Quantity must be positive"}), 400

        # If medication_id is given, update directly in medications table
        if medication_id:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                if set_inventory:
                    # Set exact inventory
                    cursor.execute('UPDATE medications SET current_inventory = %s, updated_at = CURRENT_TIMESTAMP WHERE medication_id = %s',
                                   (quantity, medication_id))
                else:
                    # Add to existing inventory
                    cursor.execute('UPDATE medications SET current_inventory = current_inventory + %s, updated_at = CURRENT_TIMESTAMP WHERE medication_id = %s',
                                   (quantity, medication_id))
                conn.commit()
                cursor.close()
            # Sync stock notifications (e.g., check if below threshold)
            sync_medication_stock_notifications(medication_id)
            return jsonify({"success": True, "message": f"Inventory set to {quantity} for medication {medication_id}"})
        else:
            # Fallback: use prescription_id to find the linked medication and update it
            restock_medication_inventory(prescription_id, quantity, set_inventory)
            return jsonify({"success": True, "message": f"Updated inventory for prescription {prescription_id}"})
    except Exception as e:
        print(f"Restock error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Update Prescription Config ----------------------
@medication_bp.route('/prescription/<int:prescription_id>', methods=['PUT'])
def update_prescription(prescription_id):
    """
    Update an existing prescription.
    Expects JSON with fields to update: medication_name, dosage_tablet, dispense_times,
    start_date, end_date, current_inventory, refill_threshold, device_id.
    At least medication_name, dosage_tablet, and dispense_times are required.
    """
    try:
        data = request.get_json()
        medication_name = data.get('medication_name')
        dosage_tablet = data.get('dosage_tablet')
        dispense_times = data.get('dispense_times')
        dispense_days = data.get('dispense_days')
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        current_inventory = data.get('current_inventory')
        refill_threshold = data.get('refill_threshold')
        device_id = data.get('device_id')

        # Mandatory fields (can't be null for a valid prescription)
        if not all([medication_name, dosage_tablet, dispense_times]):
            return jsonify({"success": False, "message": "Missing required fields"}), 400

        # Check if device_id was explicitly provided (to distinguish from None)
        check_none = 'device_id' in data
        success, msg = update_prescription_config(
            prescription_id, medication_name, dosage_tablet, dispense_times,
            start_date, end_date, current_inventory, refill_threshold, device_id, check_none, dispense_days
        )
        if not success:
            return jsonify({"success": False, "message": msg}), 400

        return jsonify({"success": True, "message": "Prescription updated successfully!"})
    except Exception as e:
        print(f"Update prescription error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Delete Prescription ----------------------
@medication_bp.route('/prescription/<int:prescription_id>', methods=['DELETE'])
def delete_prescription(prescription_id):
    """
    Delete (soft‑delete) a prescription config.
    Sends a notification to the patient that the prescription has been removed.
    """
    try:
        # delete_prescription_config returns the patient_id and medication_name for notification
        rx_data = delete_prescription_config(prescription_id)
        if rx_data:
            send_removed_prescription_notification(rx_data['patient_id'], rx_data['medication_name'])

        return jsonify({"success": True, "message": "Prescription deleted and patient notified!"})
    except Exception as e:
        print(f"Delete prescription error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get All Medications (Master List) ----------------------
@medication_bp.route('/medications', methods=['GET'])
def get_medications():
    """
    Return the list of all medications available in the system (master medication catalog).
    """
    try:
        meds = get_all_medications()
        return jsonify({"success": True, "data": meds})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Add a New Medication (Catalog Entry) ----------------------
@medication_bp.route('/medications', methods=['POST'])
def add_medication():
    """
    Add a new medication to the master catalog (not linked to a patient yet).
    Expects JSON: medication_name, current_inventory (default 0), refill_threshold (default 5),
    device_serial (optional), motor_slot (optional).
    Resolves device_serial to a device_id if provided.
    """
    try:
        data = request.get_json()
        medication_name = data.get('medication_name')
        current_inventory = data.get('current_inventory', 0)
        refill_threshold = data.get('refill_threshold', 5)
        device_serial = data.get('device_serial')   # Accept serial instead of device ID for easier client use
        motor_slot = data.get('motor_slot')

        if not medication_name:
            return jsonify({"success": False, "message": "Medication name is required"}), 400

        # Resolve device_serial to device_id if given
        device_id = None
        if device_serial:
            from models.device_model import get_device_id_by_serial
            device_id = get_device_id_by_serial(device_serial)
            if not device_id:
                return jsonify({"success": False, "message": f"Device '{device_serial}' not found. Please register the device first."}), 400

        # Call model to add new medication; returns success, message, and new medication_id
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


# ---------------------- Update a Medication (Catalog Entry) ----------------------
@medication_bp.route('/medications/<int:medication_id>', methods=['PUT'])
def update_medication(medication_id):
    """
    Update an existing medication in the master catalog.
    Expects JSON with any fields to update: medication_name, current_inventory,
    refill_threshold, device_serial, motor_slot.
    Resolves device_serial if provided.
    """
    try:
        data = request.get_json()
        new_name = data.get('medication_name')
        current_inventory = data.get('current_inventory')
        refill_threshold = data.get('refill_threshold')
        device_serial = data.get('device_serial')
        motor_slot = data.get('motor_slot')

        # Resolve serial to device_id if given
        device_id = None
        if device_serial:
            from models.device_model import get_device_id_by_serial
            device_id = get_device_id_by_serial(device_serial)
            if not device_id:
                return jsonify({"success": False, "message": f"Device '{device_serial}' not found. Please register the device first."}), 400

        # Ensure at least one field is provided
        if not new_name and current_inventory is None and refill_threshold is None and device_id is None and motor_slot is None:
            return jsonify({"success": False, "message": "No fields to update"}), 400

        # Call model to update; returns success, message, and updated tuple
        success, msg, updated = update_medication_info(medication_id, new_name, current_inventory,
                                                       refill_threshold, device_id, motor_slot)

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


# ---------------------- Delete a Medication (Catalog Entry) ----------------------
@medication_bp.route('/medications/<int:medication_id>', methods=['DELETE'])
def delete_medication(medication_id):
    """
    Delete a medication from the master catalog.
    Only allowed if the medication is not referenced by any prescription.
    """
    try:
        success, msg = delete_medication_if_unused(medication_id)
        if success:
            return jsonify({"success": True, "message": msg})
        else:
            # If the message contains "used", return 400; otherwise 404
            return jsonify({"success": False, "message": msg}), 400 if "used" in msg else 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Add a Medication Adherence Log ----------------------
@medication_bp.route('/add_log', methods=['POST'])
def add_log():
    """
    Add a manual adherence log entry (e.g., from a patient's report).
    Expects JSON: patient_id, age, day_of_week, time_of_day, status.
    """
    try:
        data = request.get_json()
        save_medication_log(
            data['patient_id'],
            data['age'],
            data['day_of_week'],
            data['time_of_day'],
            data['status']
        )
        return jsonify({"success": True, "message": "Log saved successfully!"})
    except Exception as e:
        print(f"Add log error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Retake a Missed Dose ----------------------
@medication_bp.route('/adherence_log/<int:adlog_id>/retake', methods=['PUT'])
def retake_missed_dose(adlog_id):
    """
    Mark a missed dose as taken (retake).
    Calls the model function to update the status from 'MISSED' to 'TAKEN'.
    """
    try:
        success, msg = model_retake_missed_dose(adlog_id)   # Calls the function imported with alias
        if success:
            return jsonify({"success": True, "message": msg})
        else:
            return jsonify({"success": False, "message": msg}), 400
    except Exception as e:
        print(f"Retake error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Get All Adherence Logs ----------------------
@medication_bp.route('/get_logs', methods=['GET'])
def get_logs():
    """
    Retrieve all medication adherence logs (for admin/reporting).
    """
    try:
        logs = get_all_medication_logs()
        return jsonify({"success": True, "data": logs})
    except Exception as e:
        print(f"Get logs error: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------- Trigger Retake (Dispense Info) ----------------------
@medication_bp.route('/retake_trigger/<int:adlog_id>', methods=['GET'])
def trigger_retake(adlog_id):
    """
    Check if a missed dose can be retaken (within 30‑minute window) and return
    the information needed to dispense it (motor_slot, device_id, etc.).
    This is used by the device interface to know what to dispense.
    """
    try:
        # 1. Fetch the missed dose details from adherence_logs, joining with prescriptions and medications
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

        # Validate the dose exists and is still in MISSED status
        if not dose:
            return jsonify({"success": False, "message": "Dose not found"}), 404
        if dose['status'] != 'MISSED':
            return jsonify({"success": False, "message": "Dose is not missed"}), 400

        # 2. Check if the current time is within 30 minutes of the scheduled time
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

        # 3. Return the dispense information so the device can perform the retake
        #    (the actual status update will happen when the device calls /record_medication)
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