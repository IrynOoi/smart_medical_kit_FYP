# user.py
# user.py - Model functions for user management (patients, caregivers, authentication)

# (Note: 'cleanup_connections' import is unused; likely legacy)
from cleanup_connections import conn
import mysql.connector
from db import get_db_connection  # Custom connection helper using context manager


# ---------------------- Authentication / Login ----------------------
def get_user_by_credentials(email, password):
    """
    Retrieve a user by email and plain-text password.
    (In production, passwords should be hashed; this is a simplified example.)
    Returns a dictionary with id, email, name, role if found and is_active=True.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True) 
        cursor.execute('''
            SELECT user_id as id, email, full_name as name, role
            FROM users 
            WHERE email = %s AND password = %s AND is_active = true
        ''', (email, password))
        user = cursor.fetchone()
        cursor.close()
    return user


# ---------------------- Patient Reactivation ----------------------
def reactivate_patient(patient_id):
    """
    Reactivate a soft-deleted patient (set is_active = 1).
    Only affects users with role = 'patient'.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            'UPDATE users SET is_active = 1, updated_at = CURRENT_TIMESTAMP WHERE user_id = %s AND role = %s',
            (patient_id, 'patient')
        )
        conn.commit()
        cursor.close()


# ---------------------- Get Available Patients for a Caregiver ----------------------
def get_available_patients(caregiver_id, status_filter='all'):
    """
    Return patients that can be assigned to a caregiver.
    :param caregiver_id: the caregiver's user ID
    :param status_filter: 'active' (only active patients not linked), 
                          'inactive' (all inactive patients, regardless of link),
                          'all' (all patients not linked, both active/inactive)
    Returns a list of patient dicts with basic info.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        if status_filter == 'inactive':
            # For inactive, return ALL inactive patients (so they can be managed)
            query = '''
                SELECT u.user_id as patient_id, u.full_name, u.email, p.medical_notes, u.is_active
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                WHERE u.is_active = 0
            '''
            params = []
        else:
            # For active/all, exclude patients already linked to this caregiver
            query = '''
                SELECT u.user_id as patient_id, u.full_name, u.email, p.medical_notes, u.is_active
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                WHERE NOT EXISTS (
                    SELECT 1 FROM patient_caregiver_mapping pcm 
                    WHERE pcm.patient_id = p.patient_id AND pcm.caregiver_id = %s
                )
            '''
            params = [caregiver_id]
            if status_filter == 'active':
                query += ' AND u.is_active = 1'
            # 'all' has no extra filter
        
        cursor.execute(query, params)
        patients = cursor.fetchall()
        cursor.close()
    return patients


# ---------------------- User Registration ----------------------
def create_new_user(email, password, role, name, phone, address, gender, dob, caregiver_id=None, medical_notes=None):
    """
    Insert a new user into the system.
    :param role: 'patient' or 'caregiver'
    :param caregiver_id: optional, for patients only (assigns to a caregiver)
    :param medical_notes: optional, for patients only
    Returns the new user_id.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Insert into the main users table
        cursor.execute('''
            INSERT INTO users (email, password, role, full_name, phone_no, address, gender, date_of_birth)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ''', (email, password, role, name, phone, address, gender, dob))
        
        user_id = cursor.lastrowid
        
        # Insert role-specific record
        if role == 'caregiver':
            cursor.execute('INSERT INTO caregiver (caregiver_id) VALUES (%s)', (user_id,))
        else:  # patient
            cursor.execute('''
                INSERT INTO patient (patient_id, medical_notes)
                VALUES (%s, %s)
            ''', (user_id, medical_notes))
            
        # If patient and caregiver_id is provided, create the mapping
        if caregiver_id:  
            cursor.execute('''
                INSERT INTO patient_caregiver_mapping (patient_id, caregiver_id)
                VALUES (%s, %s)
            ''', (user_id, caregiver_id))
        
        conn.commit()
        cursor.close()
    return user_id


# ---------------------- Get User ID by Email ----------------------
def get_user_id_by_email(email):
    """
    Fetch a user's ID by email. Returns a tuple (user_id,) or None.
    Used for password reset verification.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT user_id FROM users WHERE email = %s', (email,))
        user = cursor.fetchone()
        cursor.close()
    return user


# ---------------------- Update Password ----------------------
def update_user_password(email, new_password):
    """
    Update a user's password (stored as plain text in this example).
    In production, hash the password before storing.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE users 
            SET password = %s, updated_at = CURRENT_TIMESTAMP 
            WHERE email = %s
        ''', (new_password, email))
        conn.commit()
        cursor.close()


# ---------------------- Patient Profile Retrieval (with Caregiver Info) ----------------------
def get_patient_profile(patient_id):
    """
    Fetch a patient's full profile, including their user details and 
    the primary caregiver (the first one from the mapping table).
    Returns a row with all fields, or None.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT 
                p.patient_id, p.medical_notes,
                u.user_id, u.email, u.full_name, u.phone_no, u.address,
                u.gender, u.date_of_birth, u.is_active, u.created_at, u.updated_at, u.profile_photo,
                -- Get the first caregiver (by mapping_id) as the primary one
                (SELECT pcam.caregiver_id 
                 FROM patient_caregiver_mapping pcam 
                 WHERE pcam.patient_id = p.patient_id 
                 ORDER BY pcam.mapping_id 
                 LIMIT 1) AS caregiver_id,
                c.caregiver_id AS cg_id, 
                cu.full_name AS cg_full_name, cu.email AS cg_email,
                cu.phone_no AS cg_phone_no, cu.address AS cg_address, cu.gender AS cg_gender,
                cu.date_of_birth AS cg_date_of_birth, cu.is_active AS cg_is_active,
                cu.created_at AS cg_created_at, cu.updated_at AS cg_updated_at, cu.profile_photo AS cg_profile_photo
            FROM patient p
            JOIN users u ON p.patient_id = u.user_id
            LEFT JOIN caregiver c ON c.caregiver_id = (
                SELECT pcam.caregiver_id 
                FROM patient_caregiver_mapping pcam 
                WHERE pcam.patient_id = p.patient_id 
                ORDER BY pcam.mapping_id 
                LIMIT 1
            )
            LEFT JOIN users cu ON c.caregiver_id = cu.user_id
            WHERE p.patient_id = %s AND u.role = 'patient'
        ''', (patient_id,))
        row = cursor.fetchone()
        cursor.close()
    return row


# ---------------------- Update Patient Profile ----------------------
def update_patient_profile(patient_id, full_name, phone_no, address, email, gender, date_of_birth, medical_notes, photo_url):
    """
    Update a patient's profile. Handles optional photo URL.
    Updates both the users table and the patient table (for medical_notes).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Build the users update query dynamically
        update_query = '''
            UPDATE users 
            SET full_name = %s, phone_no = %s, address = %s, 
                email = %s, gender = %s, date_of_birth = %s, updated_at = CURRENT_TIMESTAMP
        '''
        params = [full_name, phone_no, address, email, gender, date_of_birth]

        if photo_url:
            update_query += ", profile_photo = %s"
            params.append(photo_url)

        update_query += " WHERE user_id = %s AND role = 'patient'"
        params.append(patient_id)

        cursor.execute(update_query, tuple(params))
        
        # Update medical notes in the patient table
        cursor.execute('''
            UPDATE patient 
            SET medical_notes = %s
            WHERE patient_id = %s
        ''', (medical_notes, patient_id))
        
        conn.commit()
        cursor.close()


# ---------------------- Hard Delete Patient (Cascade) ----------------------
def delete_patient_cascade(patient_id):
    """
    Permanently delete a patient and all associated data (prescriptions, logs, notifications, etc.).
    Uses manual deletion for tables that don't have ON DELETE CASCADE.
    (Note: patient_caregiver_mapping has ON DELETE CASCADE in the schema.)
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        # Delete from AI predictions
        cursor.execute('DELETE FROM ai_adherence_prediction WHERE patient_id = %s', (patient_id,))
        # Delete notifications for this patient
        cursor.execute('DELETE FROM notifications WHERE recipient_id = %s', (patient_id,))
        # Delete adherence logs linked via prescriptions
        cursor.execute('''
            DELETE FROM adherence_logs 
            WHERE prescription_id IN (SELECT prescription_id FROM prescription_config WHERE patient_id = %s)
        ''', (patient_id,))
        # Delete prescription configs
        cursor.execute('DELETE FROM prescription_config WHERE patient_id = %s', (patient_id,))
        # patient_caregiver_mapping is deleted by ON DELETE CASCADE
        # Delete the patient record
        cursor.execute('DELETE FROM patient WHERE patient_id = %s', (patient_id,))
        # Finally delete the user record
        cursor.execute('DELETE FROM users WHERE user_id = %s AND role = %s', (patient_id, 'patient'))
        conn.commit()
        cursor.close()


# ---------------------- Soft Delete Patient ----------------------
def soft_delete_patient(patient_id):
    """
    Soft-delete a patient by setting is_active = 0.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('UPDATE users SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE user_id = %s AND role = %s', (patient_id, 'patient'))
        conn.commit()
        cursor.close()


# ---------------------- Unlink Patient from Caregiver ----------------------
def unlink_patient_from_caregiver(caregiver_id, patient_id):
    """
    Remove the mapping between a patient and a caregiver.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('DELETE FROM patient_caregiver_mapping WHERE caregiver_id = %s AND patient_id = %s', (caregiver_id, patient_id))
        conn.commit()
        cursor.close()


# ---------------------- Caregiver Profile Retrieval ----------------------
def get_caregiver_profile(caregiver_id):
    """
    Fetch a caregiver's profile (user details joined with caregiver table).
    Returns a dictionary or None.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT u.user_id as caregiver_id, u.email, u.full_name, u.phone_no, u.address, 
                   u.gender, u.date_of_birth, u.is_active, u.created_at, u.updated_at,u.profile_photo
            FROM users u
            JOIN caregiver c ON u.user_id = c.caregiver_id
            WHERE u.user_id = %s AND u.role = 'caregiver'
        ''', (caregiver_id,))
        caregiver = cursor.fetchone()
        cursor.close()
    return caregiver


# ---------------------- Get Caregiver's Patients List (with device info) ----------------------
def get_caregiver_patients_list(caregiver_id, status='active'):
    """
    Return a list of patients assigned to a caregiver, with optional status filter.
    :param status: 'active', 'inactive', or 'all' (default 'active')
    Returns a list of patient dicts, each containing patient info, the latest prescription info,
    device details, and inventory.
    Uses a CTE (RankedPatients) to get the most recent prescription per patient.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        # Build the filter for is_active based on status parameter
        if status == 'active':
            active_filter = 'AND u.is_active = true'
        elif status == 'inactive':
            active_filter = 'AND u.is_active = false'
        else:  # 'all'
            active_filter = ''

        query = f'''
            WITH RankedPatients AS (
                SELECT 
                    u.user_id as patient_id,
                    u.email,
                    u.full_name,
                    u.date_of_birth,
                    u.gender,
                    u.phone_no,
                    u.address,
                    p.medical_notes,
                    u.profile_photo,
                    u.is_active,
                    d.device_id,
                    d.last_reported_battery AS battery_level,
                    d.device_serial,
                    d.last_battery_report AS last_active_timestamp,
                    d.last_known_ip,
                    m.current_inventory AS inventory,
                    m.refill_threshold AS refill_threshold,
                    (SELECT COUNT(*) 
                     FROM prescription_config pc2 
                     WHERE pc2.patient_id = p.patient_id 
                       AND (pc2.end_date IS NULL OR pc2.end_date >= CURDATE())
                    ) AS prescription_count,
                    ROW_NUMBER() OVER (PARTITION BY p.patient_id ORDER BY pc.created_at DESC) as rn
                FROM patient p
                INNER JOIN patient_caregiver_mapping pcm ON p.patient_id = pcm.patient_id
                INNER JOIN users u ON p.patient_id = u.user_id
                LEFT JOIN prescription_config pc ON pc.patient_id = p.patient_id
                LEFT JOIN medications m ON pc.medication_id = m.medication_id
                LEFT JOIN iot_device d ON m.device_id = d.device_id
                WHERE pcm.caregiver_id = %s {active_filter}
            )
            SELECT patient_id, email, full_name, date_of_birth, gender, phone_no, address,
                   medical_notes, profile_photo, is_active, device_id, battery_level, device_serial,
                   last_active_timestamp, last_known_ip, inventory, refill_threshold,
                   prescription_count
            FROM RankedPatients WHERE rn = 1
        '''
        cursor.execute(query, (caregiver_id,))
        patients = cursor.fetchall()
        cursor.close()
    return patients


# ---------------------- Update Caregiver Profile ----------------------
def update_caregiver_profile(caregiver_id, full_name, phone_no, address, email, gender, date_of_birth, photo_url):
    """
    Update a caregiver's profile. Handles optional photo URL.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        update_query = '''
            UPDATE users 
            SET full_name = %s, phone_no = %s, address = %s, 
                email = %s, gender = %s, date_of_birth = %s, updated_at = CURRENT_TIMESTAMP
        '''
        params = [full_name, phone_no, address, email, gender, date_of_birth]
        if photo_url:
            update_query += ", profile_photo = %s"
            params.append(photo_url)
        update_query += " WHERE user_id = %s AND role = 'caregiver'"
        params.append(caregiver_id)
        cursor.execute(update_query, tuple(params))
        conn.commit()
        cursor.close()


# ---------------------- Hard Delete Patient (Simplified) ----------------------
def hard_delete_patient(patient_id):
    """
    Permanently delete a patient from the users table only.
    (This is a simpler version; does not cascade to related tables.
     Typically you would use delete_patient_cascade for full removal.)
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            'DELETE FROM users WHERE user_id = %s AND role = %s',
            (patient_id, 'patient')
        )
        conn.commit()
        cursor.close()


# ---------------------- Link Patient to Caregiver ----------------------
def link_patient_to_caregiver(caregiver_id, patient_id):
    """
    Create a mapping entry to assign a patient to a caregiver.
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO patient_caregiver_mapping (patient_id, caregiver_id)
            VALUES (%s, %s)
        ''', (patient_id, caregiver_id))
        conn.commit()
        cursor.close()


# ---------------------- Soft Delete Caregiver ----------------------
def soft_delete_caregiver(caregiver_id):
    """
    Soft-delete a caregiver (set is_active = 0).
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE users 
            SET is_active = 0, updated_at = CURRENT_TIMESTAMP 
            WHERE user_id = %s AND role = 'caregiver'
        ''', (caregiver_id,))
        conn.commit()
        cursor.close()