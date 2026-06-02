# user.py
from cleanup_connections import conn
import mysql.connector
from db import get_db_connection

def get_user_by_credentials(email, password):
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


def reactivate_patient(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            'UPDATE users SET is_active = 1, updated_at = CURRENT_TIMESTAMP WHERE user_id = %s AND role = %s',
            (patient_id, 'patient')
        )
        conn.commit()
        cursor.close()
def get_available_patients(caregiver_id, status_filter='all'):
    """
    status_filter: 'active', 'inactive', 'all'
    For 'inactive', return ALL inactive patients (linked or unlinked)
    For 'active' and 'all', return only patients NOT already linked to this caregiver
    """
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        
        if status_filter == 'inactive':
            # Return ALL inactive patients (so you can see and manage them)
            query = '''
                SELECT u.user_id as patient_id, u.full_name, u.email, p.medical_notes, u.is_active
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                WHERE u.is_active = 0
            '''
            params = []
        else:
            # For 'active' or 'all', exclude patients already linked to this caregiver
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
            # 'all' already has no is_active filter
        
        cursor.execute(query, params)
        patients = cursor.fetchall()
        cursor.close()
    return patients

def create_new_user(email, password, role, name, phone, address, gender, dob, caregiver_id=None, medical_notes=None):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO users (email, password, role, full_name, phone_no, address, gender, date_of_birth)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ''', (email, password, role, name, phone, address, gender, dob))
        
        user_id = cursor.lastrowid
        
        if role == 'caregiver':
            cursor.execute('INSERT INTO caregiver (caregiver_id) VALUES (%s)', (user_id,))
        else:  # patient
            cursor.execute('''
                INSERT INTO patient (patient_id, medical_notes)
                VALUES (%s, %s)
            ''', (user_id, medical_notes))
            
            # 修改点：只有当 caregiver_id 不为 null 时才进行关联
        if caregiver_id:  

            cursor.execute('''

                INSERT INTO patient_caregiver_mapping (patient_id, caregiver_id)

                VALUES (%s, %s)

            ''', (user_id, caregiver_id))
        
        conn.commit()
        cursor.close()
    return user_id
def get_user_id_by_email(email):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT user_id FROM users WHERE email = %s', (email,))
        user = cursor.fetchone()
        cursor.close()
    return user

def update_user_password(email, new_password):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE users 
            SET password = %s, updated_at = CURRENT_TIMESTAMP 
            WHERE email = %s
        ''', (new_password, email))
        conn.commit()
        cursor.close()

def get_patient_profile(patient_id):
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

def update_patient_profile(patient_id, full_name, phone_no, address, email, gender, date_of_birth, medical_notes, photo_url):
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

        update_query += " WHERE user_id = %s AND role = 'patient'"
        params.append(patient_id)

        cursor.execute(update_query, tuple(params))
        
        cursor.execute('''
            UPDATE patient 
            SET medical_notes = %s
            WHERE patient_id = %s
        ''', (medical_notes, patient_id))
        
        conn.commit()
        cursor.close()

def delete_patient_cascade(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('DELETE FROM ai_adherence_prediction WHERE patient_id = %s', (patient_id,))
        cursor.execute('DELETE FROM notifications WHERE recipient_id = %s', (patient_id,))
        cursor.execute('''
            DELETE FROM adherence_logs 
            WHERE prescription_id IN (SELECT prescription_id FROM prescription_config WHERE patient_id = %s)
        ''', (patient_id,))
        cursor.execute('DELETE FROM prescription_config WHERE patient_id = %s', (patient_id,))
        # You don't need a specific delete for patient_caregiver_mapping because your SQL schema specifies ON DELETE CASCADE!
        cursor.execute('DELETE FROM patient WHERE patient_id = %s', (patient_id,))
        cursor.execute('DELETE FROM users WHERE user_id = %s AND role = %s', (patient_id, 'patient'))
        conn.commit()
        cursor.close()

def soft_delete_patient(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('UPDATE users SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE user_id = %s AND role = %s', (patient_id, 'patient'))
        conn.commit()
        cursor.close()

def unlink_patient_from_caregiver(caregiver_id, patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('DELETE FROM patient_caregiver_mapping WHERE caregiver_id = %s AND patient_id = %s', (caregiver_id, patient_id))
        conn.commit()
        cursor.close()

def get_caregiver_profile(caregiver_id):
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

def get_caregiver_patients_list(caregiver_id, status='active'):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        # Build the WHERE clause for is_active
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

def update_caregiver_profile(caregiver_id, full_name, phone_no, address, email, gender, date_of_birth, photo_url):
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




# models/user.py  (add this function)
def hard_delete_patient(patient_id):
    """Permanently delete the patient and all cascaded data."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            'DELETE FROM users WHERE user_id = %s AND role = %s',
            (patient_id, 'patient')
        )
        conn.commit()
        cursor.close()

def link_patient_to_caregiver(caregiver_id, patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO patient_caregiver_mapping (patient_id, caregiver_id)
            VALUES (%s, %s)
        ''', (patient_id, caregiver_id))
        conn.commit()
        cursor.close()



def soft_delete_caregiver(caregiver_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE users 
            SET is_active = 0, updated_at = CURRENT_TIMESTAMP 
            WHERE user_id = %s AND role = 'caregiver'
        ''', (caregiver_id,))
        conn.commit()
        cursor.close()