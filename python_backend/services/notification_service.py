#notification_service.py
from models.notification_model import insert_notification

def send_new_prescription_notification(patient_id, medication_name):
    title = "New Prescription Added"
    message = f"Your caregiver has added a new prescription for {medication_name}. Please check your updated schedule."
    insert_notification(patient_id, title, message, 'ALERT')

def send_removed_prescription_notification(patient_id, medication_name):
    title = "Prescription Removed"
    message = f"Your caregiver has removed your prescription for {medication_name}."
    insert_notification(patient_id, title, message, 'ALERT')
