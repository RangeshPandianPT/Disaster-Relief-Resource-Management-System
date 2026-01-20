"""
DRRMS Database Connection Handler
Provides connection pooling and query execution utilities.
"""

import mysql.connector
from mysql.connector import pooling, Error
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 3306)),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', 'Rangesh@07'),
    'database': os.getenv('DB_NAME', 'drrms_db'),
    'charset': 'utf8mb4',
    'collation': 'utf8mb4_unicode_ci'
}

# Connection pool
connection_pool = None


def init_pool(pool_size=5):
    """Initialize connection pool."""
    global connection_pool
    try:
        connection_pool = pooling.MySQLConnectionPool(
            pool_name="drrms_pool",
            pool_size=pool_size,
            pool_reset_session=True,
            **DB_CONFIG
        )
        return True
    except Error as e:
        print(f"Error creating connection pool: {e}")
        return False


def get_connection():
    """Get a connection from the pool."""
    global connection_pool
    if connection_pool is None:
        init_pool()
    
    try:
        return connection_pool.get_connection()
    except Error as e:
        # Fallback to direct connection
        return mysql.connector.connect(**DB_CONFIG)


def execute_query(query, params=None, fetch=True):
    """Execute a query and return results."""
    conn = None
    cursor = None
    try:
        conn = get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(query, params or ())
        
        if fetch:
            results = cursor.fetchall()
            return results
        else:
            conn.commit()
            return cursor.lastrowid
            
    except Error as e:
        print(f"Database error: {e}")
        if conn:
            conn.rollback()
        return None
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


def execute_many(query, data_list):
    """Execute a query with multiple data sets."""
    conn = None
    cursor = None
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.executemany(query, data_list)
        conn.commit()
        return cursor.rowcount
    except Error as e:
        print(f"Database error: {e}")
        if conn:
            conn.rollback()
        return 0
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


def call_procedure(proc_name, params=None):
    """Call a stored procedure."""
    conn = None
    cursor = None
    try:
        conn = get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.callproc(proc_name, params or ())
        
        results = []
        for result in cursor.stored_results():
            results.extend(result.fetchall())
        
        conn.commit()
        return results
    except Error as e:
        print(f"Procedure error: {e}")
        return None
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


def test_connection():
    """Test database connectivity."""
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.fetchone()
        cursor.close()
        conn.close()
        return True
    except Error as e:
        print(f"Connection test failed: {e}")
        return False


if __name__ == '__main__':
    # Test the connection
    if test_connection():
        print("✅ Database connection successful!")
        
        # Test query
        result = execute_query("SELECT COUNT(*) as count FROM Disaster")
        if result:
            print(f"📊 Total disasters in database: {result[0]['count']}")
    else:
        print("❌ Database connection failed!")
