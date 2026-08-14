#cleanup_connections.py
import psycopg2

conn = psycopg2.connect(
    host='localhost',
    database='fyp_db',
    user='postgres',
    password='123456',
    port=5433
)
conn.autocommit = True
cur = conn.cursor()

# Show current connections
cur.execute("SELECT count(*) FROM pg_stat_activity WHERE datname = 'fyp_db'")
print(f"Current connections: {cur.fetchone()[0]}")

# Terminate all idle connections except our own
cur.execute("""
    SELECT pg_terminate_backend(pid) 
    FROM pg_stat_activity 
    WHERE datname = 'fyp_db' 
      AND pid != pg_backend_pid() 
      AND state = 'idle'
""")
print(f"Terminated {cur.rowcount} idle connections")

# Show remaining
cur.execute("SELECT count(*) FROM pg_stat_activity WHERE datname = 'fyp_db'")
print(f"Remaining connections: {cur.fetchone()[0]}")

cur.close()
conn.close()
print("Done! You can now start server.py")
