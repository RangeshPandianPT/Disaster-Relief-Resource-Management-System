"""
Firebase Authentication Helper
"""

import firebase_admin
from firebase_admin import credentials, auth
from flask import session, redirect, url_for, request
from functools import wraps
import os


def init_firebase(app):
    """Initialize Firebase Admin SDK."""
    try:
        creds_path = app.config.get('FIREBASE_CREDENTIALS_PATH', 'firebase-credentials.json')
        if os.path.exists(creds_path):
            creds = credentials.Certificate(creds_path)
            firebase_admin.initialize_app(creds)
        else:
            print(f"Warning: Firebase credentials file not found at {creds_path}")
            print("Firebase authentication will not work until credentials are configured.")
    except Exception as e:
        print(f"Error initializing Firebase: {e}")


def verify_token(token):
    """Verify Firebase ID token."""
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        print(f"Error verifying token: {e}")
        return None


def get_current_user():
    """Get current user from session."""
    return session.get('user')


def is_logged_in():
    """Check if user is logged in."""
    return 'user' in session and session.get('user') is not None


def login_required(f):
    """Decorator to require login for a route."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not is_logged_in():
            return redirect(url_for('auth.login', next=request.url))
        return f(*args, **kwargs)
    return decorated_function
