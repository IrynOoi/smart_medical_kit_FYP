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
        
        # Check users
        cursor.execute("SELECT user_id, full_name, role FROM users LIMIT 5")
        users = cursor.fetchall()
        print("Users:", users)
        
        # Check predictions
        cursor.execute("SELECT * FROM ai_adherence_prediction")
        predictions = cursor.fetchall()
        print("Predictions:", predictions)
        
        cursor.close()
        conn.close()
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    check_db()
