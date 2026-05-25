# user.py
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
        else:
            caregiver_id = caregiver_id or 1
            cursor.execute('''
                INSERT INTO patient (patient_id, caregiver_id, medical_notes)
                VALUES (%s, %s, %s)
            ''', (user_id, caregiver_id, medical_notes))
        
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
                p.patient_id, p.caregiver_id, p.medical_notes,
                u.user_id, u.email, u.full_name, u.phone_no, u.address,
                u.gender, u.date_of_birth, u.is_active, u.created_at, u.updated_at, u.profile_photo,
                c.caregiver_id AS cg_id, cu.full_name AS cg_full_name, cu.email AS cg_email,
                cu.phone_no AS cg_phone_no, cu.address AS cg_address, cu.gender AS cg_gender,
                cu.date_of_birth AS cg_date_of_birth, cu.is_active AS cg_is_active,
                cu.created_at AS cg_created_at, cu.updated_at AS cg_updated_at, cu.profile_photo AS cg_profile_photo
            FROM patient p
            JOIN users u ON p.patient_id = u.user_id
            LEFT JOIN caregiver c ON p.caregiver_id = c.caregiver_id
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
        cursor.execute('DELETE FROM patient WHERE patient_id = %s', (patient_id,))
        cursor.execute('DELETE FROM users WHERE user_id = %s AND role = %s', (patient_id, 'patient'))
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

def get_caregiver_patients_list(caregiver_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
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
                    d.device_id,
                    d.last_reported_battery AS battery_level,
                    d.device_serial,
                    d.last_battery_report AS last_active_timestamp,
                    d.last_known_ip,
                    m.current_inventory AS inventory,
                    m.refill_threshold AS refill_threshold,
                    -- Add prescription count subquery
                    (SELECT COUNT(*) 
                     FROM prescription_config pc2 
                     WHERE pc2.patient_id = p.patient_id 
                       AND (pc2.end_date IS NULL OR pc2.end_date >= CURDATE())
                    ) AS prescription_count,
                    ROW_NUMBER() OVER (PARTITION BY p.patient_id ORDER BY pc.created_at DESC) as rn
                FROM patient p
                JOIN users u ON p.patient_id = u.user_id
                LEFT JOIN prescription_config pc ON pc.patient_id = p.patient_id
                LEFT JOIN medications m ON pc.medication_id = m.medication_id
                LEFT JOIN iot_device d ON m.device_id = d.device_id
                WHERE p.caregiver_id = %s AND u.is_active = true
            )
            SELECT patient_id, email, full_name, date_of_birth, gender, phone_no, address,
                   medical_notes, profile_photo, device_id, battery_level, device_serial,
                   last_active_timestamp, last_known_ip, inventory, refill_threshold,
                   prescription_count
            FROM RankedPatients WHERE rn = 1
        ''', (caregiver_id,))
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
