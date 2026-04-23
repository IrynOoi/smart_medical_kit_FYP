import psycopg2
from psycopg2.extras import RealDictCursor

DB_CONFIG = {
    'host': 'localhost',
    'database': 'fyp_db',
    'user': 'postgres',
    'password': '123456',
    'port': 5433
}

def check_db():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get all patients
        cursor.execute("SELECT u.user_id, u.full_name, u.role FROM users u WHERE role = 'patient'")
        patients = cursor.fetchall()
        print("Patients:", patients)
        
        cursor.close()
        conn.close()
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    check_db()
