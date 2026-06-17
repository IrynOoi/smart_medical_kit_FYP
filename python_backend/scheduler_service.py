#scheduler_service.py
from db import get_db_connection
from datetime import timedelta
from datetime import datetime
from apscheduler.schedulers.background import BackgroundScheduler
from models.notification_model import sync_stock_notifications

def create_tasks_for_hardware_and_app():
    now = datetime.now().replace(second=0, microsecond=0)
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SET time_zone = '+08:00';")
            
            cursor.execute("""
                SELECT pc.*, m.medication_name, ps.dispense_time, ps.day_of_week 
                FROM prescription_config pc
                JOIN medications m ON pc.medication_id = m.medication_id
                JOIN prescription_schedules ps ON pc.prescription_id = ps.prescription_id
                WHERE pc.end_date IS NULL OR pc.end_date >= CURRENT_DATE
            """)
            prescriptions = cursor.fetchall()
            
            for p in prescriptions:
                # Check day of the week matching (1=Mon, ..., 7=Sun)
                if p['day_of_week'] is not None and p['day_of_week'] != now.isoweekday():
                    continue

                if isinstance(p['dispense_time'], timedelta):
                    seconds = p['dispense_time'].total_seconds()
                    hours = int(seconds // 3600)
                    minutes = int((seconds % 3600) // 60)
                else:
                    hours = p['dispense_time'].hour
                    minutes = p['dispense_time'].minute
                    
                dispense_minutes = hours * 60 + minutes
                
                # ==========================================
                # 📱 Action 1: 提前 2~10 分钟生成 App 通知
                # ==========================================
                for minutes_ahead in range(2, 11):
                    check_time = now + timedelta(minutes=minutes_ahead)
                    check_total_minutes = check_time.hour * 60 + check_time.minute
                    if check_total_minutes == dispense_minutes:
                        
                        # ✅ FIX: 用精确的计划时间去重，而不是 CURDATE()
                        target_time = now.replace(hour=hours, minute=minutes, second=0, microsecond=0)
                        scheduled_time_str = target_time.strftime("%Y-%m-%d %I:%M %p")
                        
                        cursor.execute("""
                            SELECT 1 FROM notifications
                            WHERE recipient_id = %s
                              AND type = 'REMINDER'
                              AND message LIKE %s
                              AND message LIKE %s
                        """, (
                            p['patient_id'],
                            f"%{p['medication_name']}%",
                            f"%{scheduled_time_str}%"  # ← 用精确时间去重
                        ))
                        
                        if not cursor.fetchone():
                            # ✅ FIX: 把计划时间写进 message，便于去重和显示
                            msg = (
                                f"Time to take {float(p['dosage_tablet']):.0f} tablet(s) of "
                                f"{p['medication_name']} at {scheduled_time_str}."
                            )
                            cursor.execute("""
                                INSERT INTO notifications (recipient_id, title, message, type, is_read)
                                VALUES (%s, 'Medication Reminder', %s, 'REMINDER', 0)
                            """, (p['patient_id'], msg))
                            print(f"[App] Notification for {p['medication_name']} at {scheduled_time_str}")
                        break  # 同一药物只发一次提前通知
                
                # ==========================================
                # 🤖 Action 2: 精确时间触发硬件（加容错窗口）
                # ==========================================
                # ✅ FIX: 检查当前分钟 ±1 分钟，防止 scheduler 漂移导致漏触发
                for delta in [0, -1, 1]:
                    check_now = now + timedelta(minutes=delta)
                    check_total_minutes = check_now.hour * 60 + check_now.minute
                    if check_total_minutes == dispense_minutes:
                        target_time = now.replace(hour=hours, minute=minutes, second=0, microsecond=0)
                        formatted_time = target_time.strftime("%Y-%m-%d %H:%M:00")
                        cursor.execute("""
                            SELECT 1 FROM adherence_logs 
                            WHERE prescription_id = %s AND scheduled_time = %s
                        """, (p['prescription_id'], formatted_time))
                        
                        if not cursor.fetchone():
                            cursor.execute("""
                                INSERT INTO adherence_logs (prescription_id, device_id, scheduled_time, status)
                                SELECT %s, device_id, %s, 'PENDING'
                                FROM medications 
                                WHERE medication_id = %s AND device_id IS NOT NULL
                            """, (p['prescription_id'], formatted_time, p['medication_id']))
                            print(f"[Hardware] Triggered for {p['medication_name']} at {formatted_time}")
                        break  # 找到匹配就停
            
            conn.commit()
            cursor.close()
            sync_stock_notifications()
    except Exception as e:
        print(f"Scheduler Error: {e}")


def start_scheduler():
    scheduler = BackgroundScheduler()
    # Run the task every minute to check for upcoming medications
    scheduler.add_job(create_tasks_for_hardware_and_app, 'interval', minutes=1)
    scheduler.start()
    print("Background scheduler started successfully.")
