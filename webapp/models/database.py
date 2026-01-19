"""
Database connection and query utilities for the webapp.
"""

import mysql.connector
from mysql.connector import pooling, Error
from flask import current_app, g


def get_db():
    """Get database connection for current request."""
    if 'db' not in g:
        try:
            g.db = mysql.connector.connect(
                host=current_app.config['DB_HOST'],
                port=current_app.config['DB_PORT'],
                user=current_app.config['DB_USER'],
                password=current_app.config['DB_PASSWORD'],
                database=current_app.config['DB_NAME'],
                charset='utf8mb4'
            )
        except Error as e:
            print(f"Database connection error: {e}")
            return None
    return g.db


def close_db(e=None):
    """Close database connection."""
    db = g.pop('db', None)
    if db is not None:
        db.close()


def query_db(query, args=(), one=False):
    """Execute a query and return results."""
    db = get_db()
    if db is None:
        return None
    
    try:
        cursor = db.cursor(dictionary=True)
        cursor.execute(query, args)
        
        if query.strip().upper().startswith('SELECT'):
            rv = cursor.fetchall()
            cursor.close()
            return (rv[0] if rv else None) if one else rv
        else:
            db.commit()
            lastrowid = cursor.lastrowid
            cursor.close()
            return lastrowid
    except Error as e:
        print(f"Query error: {e}")
        db.rollback()
        return None


def init_app(app):
    """Initialize database with Flask app."""
    app.teardown_appcontext(close_db)
