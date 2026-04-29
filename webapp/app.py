"""
DRRMS Flask Web Application
Main application entry point.
"""

from flask import Flask, render_template
from flask_session import Session
from config import config
from models import init_app
from routes import api
from routes.auth import auth_bp
from auth import init_firebase, is_logged_in, login_required


def create_app(config_name='development'):
    """Application factory."""
    app = Flask(__name__)
    
    # Load configuration
    app.config.from_object(config[config_name])
    
    # Initialize session management
    Session(app)
    
    # Initialize Firebase
    init_firebase(app)
    
    # Initialize database
    init_app(app)
    
    # Register blueprints
    app.register_blueprint(api)
    app.register_blueprint(auth_bp)
    
    # Page routes with login protection
    @app.route('/')
    @login_required
    def dashboard():
        return render_template('dashboard.html', active_page='dashboard')
    
    @app.route('/disasters')
    @login_required
    def disasters():
        return render_template('disasters.html', active_page='disasters')
    
    @app.route('/inventory')
    @login_required
    def inventory():
        return render_template('inventory.html', active_page='inventory')
    
    @app.route('/requests')
    @login_required
    def requests():
        return render_template('requests.html', active_page='requests')
    
    @app.route('/volunteers')
    @login_required
    def volunteers():
        return render_template('volunteers.html', active_page='volunteers')
    
    @app.route('/donations')
    @login_required
    def donations():
        return render_template('donations.html', active_page='donations')
    
    return app


# Create app instance
app = create_app()

if __name__ == '__main__':
    print("\n" + "=" * 50)
    print("🌍 DRRMS Web Application")
    print("=" * 50)
    print("Starting server at http://localhost:5000")
    print("Press Ctrl+C to stop")
    print("=" * 50 + "\n")
    
    app.run(debug=True, host='0.0.0.0', port=5000)
