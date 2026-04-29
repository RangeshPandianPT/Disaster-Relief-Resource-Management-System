"""
Authentication routes for Firebase login/logout.
"""

from flask import Blueprint, render_template, request, jsonify, session, redirect, url_for
from auth import verify_token, is_logged_in
import json
import base64

auth_bp = Blueprint('auth', __name__, url_prefix='/auth')


@auth_bp.route('/login', methods=['GET'])
def login():
    """Render login page."""
    if is_logged_in():
        return redirect(url_for('dashboard'))
    return render_template('login.html')


@auth_bp.route('/verify-token', methods=['POST'])
def verify():
    """Verify Firebase token and create session."""
    try:
        data = request.get_json()
        token = data.get('token')
        
        if not token:
            return jsonify({'success': False, 'error': 'No token provided'}), 400
        
        # Check if it's a demo token (base64 encoded JSON)
        try:
            decoded = json.loads(base64.b64decode(token).decode('utf-8'))
            if 'uid' in decoded and 'email' in decoded:
                # Demo authentication - accept any demo token
                session['user'] = {
                    'uid': decoded.get('uid'),
                    'email': decoded.get('email'),
                    'name': decoded.get('name', decoded.get('email', 'User')),
                    'picture': decoded.get('picture', f"https://ui-avatars.com/api/?name={decoded.get('email', 'User')}&background=3b82f6&color=fff"),
                }
                return jsonify({
                    'success': True,
                    'user': session['user']
                })
        except (json.JSONDecodeError, UnicodeDecodeError):
            pass
        
        # Verify token with Firebase
        decoded_token = verify_token(token)
        
        if not decoded_token:
            return jsonify({'success': False, 'error': 'Invalid token'}), 401
        
        # Store user info in session
        session['user'] = {
            'uid': decoded_token.get('uid'),
            'email': decoded_token.get('email'),
            'name': decoded_token.get('name'),
            'picture': decoded_token.get('picture'),
        }
        
        return jsonify({
            'success': True,
            'user': session['user']
        })
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@auth_bp.route('/logout', methods=['POST', 'GET'])
def logout():
    """Logout user and clear session."""
    session.clear()
    return redirect(url_for('auth.login'))


@auth_bp.route('/user', methods=['GET'])
def get_user():
    """Get current user information."""
    if is_logged_in():
        return jsonify({'success': True, 'user': session['user']})
    return jsonify({'success': False, 'user': None}), 401


@auth_bp.route('/check-auth', methods=['GET'])
def check_auth():
    """Check if user is authenticated."""
    return jsonify({
        'authenticated': is_logged_in(),
        'user': session.get('user')
    })
