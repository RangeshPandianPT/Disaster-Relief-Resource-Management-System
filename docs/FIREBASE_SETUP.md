# Firebase Authentication Setup

This DRRMS webapp now includes Firebase Authentication integration. Follow these steps to set it up:

## 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a new project"
3. Enter project name and follow the setup wizard
4. Enable Google Sign-In in Authentication methods

## 2. Get Firebase Configuration

1. In Firebase Console, go to Project Settings (gear icon)
2. Copy your Firebase config:
   - API Key
   - Auth Domain
   - Project ID
   - Storage Bucket
   - Messaging Sender ID
   - App ID

## 3. Create Service Account Credentials

1. In Firebase Console, go to Service Accounts
2. Click "Generate New Private Key"
3. Save the JSON file as `firebase-credentials.json` in the `webapp/` directory

## 4. Configure Environment Variables

Create a `.env` file in the `webapp/` directory with:

```
# Firebase Configuration
FIREBASE_API_KEY=your_api_key_here
FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_project.appspot.com
FIREBASE_MESSAGING_SENDER_ID=your_messaging_sender_id
FIREBASE_APP_ID=your_app_id

# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=Rangesh@07
DB_NAME=drrms_db

# Flask Configuration
SECRET_KEY=your_secret_key_here
```

## 5. Install Dependencies

```bash
cd webapp
pip install -r requirements.txt
```

## 6. Run the Application

```bash
python -c "from app import create_app; app = create_app(); app.run()"
```

The application will be available at `http://localhost:5000`

## Features

✅ **Google Sign-In** - Secure authentication with Google accounts
✅ **Email Authentication** - Support for email/password login (FirebaseUI)
✅ **Session Management** - User sessions with Flask-Session
✅ **Protected Routes** - All pages require login
✅ **User Profile** - Display user info in navbar with avatar
✅ **Logout** - Secure logout with session clearing

## Troubleshooting

### Firebase is not configured
- Make sure `.env` file exists in `webapp/` directory
- Check all Firebase configuration values are correct
- Verify `firebase-credentials.json` is in `webapp/` directory

### Login page appears instead of dashboard
- Check your Firebase credentials are valid
- Make sure you're using the correct Firebase project
- Clear browser cache and try again

### User profile not showing
- Verify the user is properly authenticated
- Check browser console for errors
- Make sure Firebase SDK is loaded

## Project Structure

```
webapp/
├── app.py                    # Main Flask app with Firebase init
├── auth.py                   # Firebase auth helper functions
├── config.py                 # Configuration with Firebase settings
├── requirements.txt          # Updated with firebase-admin
├── firebase-credentials.json # Firebase service account (create this)
├── .env                      # Environment variables (create this)
├── routes/
│   ├── auth.py              # Authentication routes
│   └── api.py               # API endpoints
└── templates/
    ├── login.html           # New login page with FirebaseUI
    └── base.html            # Updated with user profile
```

## API Endpoints

### Authentication
- `GET /auth/login` - Login page
- `POST /auth/verify-token` - Verify Firebase token
- `GET /auth/logout` - Logout user
- `GET /auth/user` - Get current user info
- `GET /auth/check-auth` - Check authentication status

### Protected Routes (require login)
- `GET /` - Dashboard
- `GET /disasters` - Disasters page
- `GET /inventory` - Inventory page
- `GET /requests` - Requests page
- `GET /volunteers` - Volunteers page
- `GET /donations` - Donations page
