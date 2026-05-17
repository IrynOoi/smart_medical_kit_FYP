#notification.py
from db import get_db_connection

def insert_notification(patient_id, title, message, notif_type='REMINDER'):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO notifications (patient_id, title, message, type)
            VALUES (%s, %s, %s, %s)
        ''', (patient_id, title, message, notif_type))
        conn.commit()
        cursor.close()

def get_patient_notifications(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute('''
            SELECT notification_id, patient_id, title, message, type, is_read, created_at
            FROM notifications WHERE patient_id = %s
            ORDER BY created_at DESC LIMIT 20
        ''', (patient_id,))
        notifications = cursor.fetchall()
        cursor.close()
    return notifications

def mark_notification_as_read(notification_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('UPDATE notifications SET is_read = 1 WHERE notification_id = %s', (notification_id,))
        conn.commit()
        cursor.close()

def mark_all_reminders_read(patient_id):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE notifications
            SET is_read = 1
            WHERE patient_id = %s AND type = 'REMINDER' AND is_read = 0
        ''', (patient_id,))
        conn.commit()
        cursor.close()

def mark_single_reminder_read(patient_id, medication_name):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        search_term = f"%{medication_name}%"
        cursor.execute('''
            UPDATE notifications
            SET is_read = 1
            WHERE patient_id = %s 
              AND type = 'REMINDER' 
              AND is_read = 0
              AND message LIKE %s
        ''', (patient_id, search_term))
        conn.commit()
        cursor.close()
