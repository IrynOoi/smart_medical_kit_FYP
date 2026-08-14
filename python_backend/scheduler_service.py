# =====================================================================
# scheduler_service.py – Background task that runs every minute to 
# check for upcoming medication doses and trigger both:
#   1. In‑app notifications (sent 2–10 minutes before the dose)
#   2. Hardware dispense events (by inserting 'PENDING' adherence logs 
#      at the exact scheduled time, with a ±1 minute tolerance)
# =====================================================================

from db import get_db_connection
from datetime import timedelta
from datetime import datetime
from apscheduler.schedulers.background import BackgroundScheduler
from models.notification_model import sync_stock_notifications


def create_tasks_for_hardware_and_app():
    """
    Main function called every minute by the scheduler.
    It scans all active prescriptions and their schedules, then:
      - Creates in‑app notifications for doses that are 2‑10 minutes away.
      - Inserts 'PENDING' adherence logs for doses that are due now 
        (with a 1‑minute tolerance to avoid scheduling drift).
    """
    # Get current time, but strip seconds and microseconds to align with minute‑level checks.
    now = datetime.now().replace(second=0, microsecond=0)

    try:
        # Connect to the database and set timezone to Malaysia (UTC+8) 
        # so that dispense_time comparisons are correct.
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SET time_zone = '+08:00';")

            # Fetch all active prescriptions with their medication name,
            # dispense time, and day_of_week (NULL means every day).
            cursor.execute("""
                SELECT pc.*, m.medication_name, ps.dispense_time, ps.day_of_week 
                FROM prescription_config pc
                JOIN medications m ON pc.medication_id = m.medication_id
                JOIN prescription_schedules ps ON pc.prescription_id = ps.prescription_id
                WHERE pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE
            """)
            prescriptions = cursor.fetchall()

            # Loop through each prescription schedule.
            for p in prescriptions:
                # --- Day‑of‑week filter ---
                # If a specific day is set (1=Monday, ..., 7=Sunday), 
                # skip if it does not match today's isoweekday.
                if p['day_of_week'] is not None and p['day_of_week'] != now.isoweekday():
                    continue

                # --- Extract dispense time (hour and minute) ---
                # The dispense_time column can be a timedelta (from MySQL) or a time object.
                # Convert it to total minutes since midnight for easy comparison.
                if isinstance(p['dispense_time'], timedelta):
                    seconds = p['dispense_time'].total_seconds()
                    hours = int(seconds // 3600)
                    minutes = int((seconds % 3600) // 60)
                else:
                    hours = p['dispense_time'].hour
                    minutes = p['dispense_time'].minute

                dispense_minutes = hours * 60 + minutes

                # ==========================================
                # 📱 ACTION 1: Create in‑app notifications 2‑10 minutes ahead
                # ==========================================
                # The scheduler runs every minute. We check if the current time
                # plus 2 to 10 minutes equals the dispense time. If so, we insert
                # a notification (only once per dose).
                for minutes_ahead in range(2, 11):
                    check_time = now + timedelta(minutes=minutes_ahead)
                    check_total_minutes = check_time.hour * 60 + check_time.minute
                    if check_total_minutes == dispense_minutes:

                        # Build a precise scheduled time string (e.g. "2026-06-22 08:00 AM")
                        # to use in the notification message and for deduplication.
                        target_time = now.replace(hour=hours, minute=minutes, second=0, microsecond=0)
                        scheduled_time_str = target_time.strftime("%Y-%m-%d %I:%M %p")

                        # --- Prevent duplicate notifications ---
                        # Check if a notification for this patient, medication, and exact 
                        # scheduled time already exists (using LIKE on the message field).
                        cursor.execute("""
                            SELECT 1 FROM notifications
                            WHERE recipient_id = %s
                              AND type = 'REMINDER'
                              AND message LIKE %s
                              AND message LIKE %s
                        """, (
                            p['patient_id'],
                            f"%{p['medication_name']}%",
                            f"%{scheduled_time_str}%"
                        ))

                        if not cursor.fetchone():
                            # Insert the notification with the exact scheduled time in the message.
                            msg = (
                                f"Time to take {float(p['dosage_tablet']):.0f} tablet(s) of "
                                f"{p['medication_name']} at {scheduled_time_str}."
                            )
                            cursor.execute("""
                                INSERT INTO notifications (recipient_id, title, message, type, is_read)
                                VALUES (%s, 'Medication Reminder', %s, 'REMINDER', 0)
                            """, (p['patient_id'], msg))
                            print(f"[App] Notification for {p['medication_name']} at {scheduled_time_str}")
                        break  # Once we find a match for this dose, stop checking earlier minutes.

                # ==========================================
                # 🤖 ACTION 2: Insert 'PENDING' adherence log for hardware dispense
                # ==========================================
                # The ESP32 polls the server for pending doses. By inserting a 'PENDING' log
                # at the exact scheduled time, the device will be instructed to dispense.
                # We check current time ±1 minute to account for scheduler drift.
                for delta in [0, -1, 1]:
                    check_now = now + timedelta(minutes=delta)
                    check_total_minutes = check_now.hour * 60 + check_now.minute
                    if check_total_minutes == dispense_minutes:
                        target_time = now.replace(hour=hours, minute=minutes, second=0, microsecond=0)
                        formatted_time = target_time.strftime("%Y-%m-%d %H:%M:00")

                        # --- Prevent duplicate logs ---
                        # Check if a log for this prescription and exact scheduled_time already exists.
                        cursor.execute("""
                            SELECT 1 FROM adherence_logs 
                            WHERE prescription_id = %s AND scheduled_time = %s
                        """, (p['prescription_id'], formatted_time))

                        if not cursor.fetchone():
                            # Insert the pending log, copying the device_id from the linked medication.
                            cursor.execute("""
                                INSERT INTO adherence_logs (prescription_id, device_id, scheduled_time, status)
                                SELECT %s, device_id, %s, 'PENDING'
                                FROM medications 
                                WHERE medication_id = %s AND device_id IS NOT NULL
                            """, (p['prescription_id'], formatted_time, p['medication_id']))
                            print(f"[Hardware] Triggered for {p['medication_name']} at {formatted_time}")
                        break  # Stop checking other offsets once we've triggered.

            # Commit all changes to the database.
            conn.commit()
            cursor.close()

            # After processing all prescriptions, sync stock notifications 
            # (e.g., send low‑stock alerts to caregivers if thresholds are crossed).
            sync_stock_notifications()

    except Exception as e:
        # Log any error that occurs during the scheduler run.
        print(f"Scheduler Error: {e}")


def start_scheduler():
    """
    Initialise and start the background scheduler.
    The scheduler runs the `create_tasks_for_hardware_and_app` function 
    every minute, which checks for upcoming doses.
    """
    scheduler = BackgroundScheduler()
    scheduler.add_job(create_tasks_for_hardware_and_app, 'interval', minutes=1)
    scheduler.start()
    print("Background scheduler started successfully.")