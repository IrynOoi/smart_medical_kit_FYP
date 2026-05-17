#scheduler_service.py
from apscheduler.schedulers.background import BackgroundScheduler
from croniter import croniter
from datetime import datetime, timedelta
from db import get_db_connection

def create_tasks_for_hardware_and_app():
    now = datetime.now()
    
    # 🔮 Core magic: calculate the time 3 minutes later
    time_plus_3m = now + timedelta(minutes=3)
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            
            # Get all active medication schedules
            cursor.execute("""
                SELECT pc.*, m.medication_name 
                FROM prescription_config pc
                JOIN medications m ON pc.medication_id = m.medication_id
                WHERE pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE
            """)
            prescriptions = cursor.fetchall()
            
            for p in prescriptions:
                cron_expr = p['dispense_schedule'] 
                
                # ==========================================
                # 📱 Action 1: Generate in-app notification 3 minutes earlier!
                # Check: does the time 3 minutes later match the medication time?
                # ==========================================
                if croniter.match(cron_expr, time_plus_3m):
                    msg = f"Upcoming Dose: Take {float(p['dosage_tablet'])} tablet(s) of {p['medication_name']} in 3 minutes!"
                    cursor.execute("""
                        INSERT INTO notifications (patient_id, title, message, type, is_read)
                        VALUES (%s, '⚠️ Upcoming Medication', %s, 'REMINDER', 0)
                    """, (p['patient_id'], msg))
                    print(f"📲 [App] Inserted a 3-minute early app notification for {p['medication_name']}!")

                # ==========================================
                # 🤖 Action 2: Trigger hardware pillbox at exact time (0 minute delay)!
                # Check: does the current time exactly match the medication time?
                # ==========================================
                if croniter.match(cron_expr, now):
                    formatted_time = now.strftime("%Y-%m-%d %H:%M:00")
                    cursor.execute("""
                        INSERT INTO adherence_logs (prescription_id, device_id, scheduled_time, status)
                        SELECT %s, device_id, %s, 'PENDING'
                        FROM medications 
                        WHERE medication_id = %s AND device_id IS NOT NULL
                    """, (p['prescription_id'], formatted_time, p['medication_id']))
                    print(f"🤖 [Hardware] Triggered the pillbox hardware for {p['medication_name']} at the exact time!")
            
            conn.commit()
            cursor.close()
    except Exception as e:
        print(f"Scheduler Error: {e}")

def start_scheduler():
    scheduler = BackgroundScheduler()
    # Run every minute
    scheduler.add_job(func=create_tasks_for_hardware_and_app, trigger="interval", minutes=1)
    scheduler.start()
    print("⏳ IoT Scheduler Started: Handles 3-min App warning & exact-time Hardware dispense.")