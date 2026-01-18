#!/usr/bin/env python3
"""
DRRMS Database Migration Runner
Applies SQL migrations in order and tracks their status.
"""

import os
import sys
import hashlib
import time
import mysql.connector
from mysql.connector import Error
from datetime import datetime

# Configuration
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '',  # Update with your MySQL password
    'database': 'drrms_db'
}

MIGRATIONS_DIR = os.path.dirname(os.path.abspath(__file__))


def get_connection():
    """Create database connection."""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except Error as e:
        print(f"❌ Database connection failed: {e}")
        sys.exit(1)


def get_file_checksum(filepath):
    """Calculate MD5 checksum of a file."""
    with open(filepath, 'rb') as f:
        return hashlib.md5(f.read()).hexdigest()


def ensure_migration_table(cursor):
    """Create migration tracking table if not exists."""
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS _migrations (
            migration_id INT AUTO_INCREMENT PRIMARY KEY,
            version VARCHAR(10) NOT NULL UNIQUE,
            name VARCHAR(100) NOT NULL,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            applied_by VARCHAR(100),
            checksum VARCHAR(64),
            execution_time_ms INT,
            status ENUM('pending', 'applied', 'failed', 'rolled_back') DEFAULT 'pending'
        )
    """)


def get_applied_migrations(cursor):
    """Get list of already applied migrations."""
    cursor.execute("SELECT version FROM _migrations WHERE status = 'applied'")
    return {row[0] for row in cursor.fetchall()}


def get_pending_migrations():
    """Get list of migration files to apply."""
    migrations = []
    for filename in sorted(os.listdir(MIGRATIONS_DIR)):
        if filename.endswith('.sql') and filename[0].isdigit():
            version = filename.split('_')[0]
            name = filename.replace('.sql', '')
            migrations.append({
                'version': version,
                'name': name,
                'filepath': os.path.join(MIGRATIONS_DIR, filename)
            })
    return migrations


def apply_migration(cursor, migration):
    """Apply a single migration."""
    print(f"  📄 Applying: {migration['name']}...", end=' ')
    
    start_time = time.time()
    
    try:
        with open(migration['filepath'], 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        # Split by semicolon and execute each statement
        statements = [s.strip() for s in sql_content.split(';') if s.strip()]
        
        for statement in statements:
            if statement and not statement.startswith('--') and not statement.startswith('/*'):
                try:
                    cursor.execute(statement)
                except Error as e:
                    # Ignore some common non-critical errors
                    if 'Duplicate' not in str(e) and 'already exists' not in str(e):
                        raise
        
        execution_time = int((time.time() - start_time) * 1000)
        checksum = get_file_checksum(migration['filepath'])
        
        # Record migration
        cursor.execute("""
            INSERT INTO _migrations (version, name, checksum, execution_time_ms, status, applied_by)
            VALUES (%s, %s, %s, %s, 'applied', USER())
            ON DUPLICATE KEY UPDATE 
                status = 'applied',
                applied_at = CURRENT_TIMESTAMP,
                execution_time_ms = %s
        """, (migration['version'], migration['name'], checksum, execution_time, execution_time))
        
        print(f"✅ ({execution_time}ms)")
        return True
        
    except Error as e:
        print(f"❌ Failed: {e}")
        cursor.execute("""
            INSERT INTO _migrations (version, name, status)
            VALUES (%s, %s, 'failed')
            ON DUPLICATE KEY UPDATE status = 'failed'
        """, (migration['version'], migration['name']))
        return False


def show_status(cursor):
    """Display migration status."""
    cursor.execute("""
        SELECT version, name, status, applied_at, execution_time_ms
        FROM _migrations
        ORDER BY version
    """)
    
    rows = cursor.fetchall()
    
    print("\n📋 Migration Status:")
    print("-" * 70)
    print(f"{'Version':<10} {'Name':<30} {'Status':<12} {'Applied At':<20}")
    print("-" * 70)
    
    for row in rows:
        version, name, status, applied_at, exec_time = row
        status_icon = '✅' if status == 'applied' else '❌' if status == 'failed' else '⏳'
        applied_str = applied_at.strftime('%Y-%m-%d %H:%M') if applied_at else 'N/A'
        print(f"{version:<10} {name:<30} {status_icon} {status:<10} {applied_str}")
    
    print("-" * 70)


def migrate():
    """Run pending migrations."""
    print("\n🚀 DRRMS Database Migration Runner")
    print("=" * 50)
    
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        ensure_migration_table(cursor)
        conn.commit()
        
        applied = get_applied_migrations(cursor)
        pending = get_pending_migrations()
        
        to_apply = [m for m in pending if m['version'] not in applied]
        
        if not to_apply:
            print("✨ No pending migrations. Database is up to date!")
        else:
            print(f"📦 Found {len(to_apply)} pending migration(s):\n")
            
            for migration in to_apply:
                success = apply_migration(cursor, migration)
                conn.commit()
                
                if not success:
                    print("\n⚠️  Migration failed. Stopping.")
                    break
            
            print("\n✅ Migration complete!")
        
        show_status(cursor)
        
    finally:
        cursor.close()
        conn.close()


def rollback(version):
    """Rollback a specific migration (manual operation)."""
    print(f"\n⚠️  Rollback for version {version}")
    print("Please run the DOWN migration manually from the SQL file.")
    print("Then update the _migrations table:")
    print(f"  UPDATE _migrations SET status = 'rolled_back' WHERE version = '{version}';")


if __name__ == '__main__':
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == 'status':
            conn = get_connection()
            cursor = conn.cursor()
            ensure_migration_table(cursor)
            show_status(cursor)
            cursor.close()
            conn.close()
        elif command == 'rollback' and len(sys.argv) > 2:
            rollback(sys.argv[2])
        else:
            print("Usage: python migrate.py [status|rollback <version>]")
    else:
        migrate()
