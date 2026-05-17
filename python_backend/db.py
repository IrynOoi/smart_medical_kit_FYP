# db.py
import mysql.connector
from mysql.connector.pooling import MySQLConnectionPool
from contextlib import contextmanager
from config import DB_CONFIG

# Create a connection pool for MySQL
db_pool = mysql.connector.pooling.MySQLConnectionPool(
    pool_name="mypool",
    pool_size=10,
    **DB_CONFIG
)

@contextmanager
def get_db_connection():
    conn = None
    try:
        conn = db_pool.get_connection()
        yield conn
    except Exception as e:
        if conn:
            conn.rollback()
        raise e
    finally:
        if conn and conn.is_connected():
            conn.close()

def init_db():
    """Test database connection"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT 1')
            cursor.fetchone()  # 🌟 关键修复：把结果读取出来，解决 "Unread result found" 报错
            cursor.close()
        print("MySQL (cPanel) connected successfully!") # 把名字改对，不再自己吓自己
    except Exception as e:
        print(f"Failed to connect to MySQL: {e}")
