# Environment Setup Guide

## Backend Setup

### 1. Create `.env` File
Copy `.env.example` to `.env` in the `safety_safar_backend` folder:

```bash
cd safety_safar_backend
cp .env.example .env
```

### 2. Update Environment Variables
Edit `.env` and fill in the actual values:

```
# Frontend URL where your Flutter app will run
FRONTEND_URL=http://localhost:3000

# Gmail SMTP Credentials
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_specific_password (get from Gmail App Passwords)
MAIL_FROM=your_email@gmail.com
MAIL_PORT=587
MAIL_SERVER=smtp.gmail.com
MAIL_STARTTLS=True
MAIL_SSL_TLS=False
MAIL_FROM_NAME=SafetySafar Support
```

### 3. Gmail App Passwords Setup
To get `MAIL_PASSWORD`, follow these steps:

1. Enable 2-factor authentication on your Gmail account
2. Go to https://myaccount.google.com/apppasswords
3. Select "Mail" and "Windows Computer" (or your device)
4. Google will generate a 16-character password
5. Paste that into `MAIL_PASSWORD` in your `.env` file

⚠️ **Never commit the `.env` file to GitHub!** It's already in `.gitignore`.

## Frontend Setup (Flutter)

### 1. Firebase Configuration
- Get your `google-services.json` from Firebase Console
- Place it in `safety_safar_app/android/app/`
- Place `GoogleService-Info.plist` in `safety_safar_app/ios/Runner/`

### 2. Run Flutter App
```bash
cd safety_safar_app
flutter pub get
flutter run
```

## ⚠️ Important Security Notes

- **Never commit `.env` files** - They contain sensitive credentials
- **Never share API keys or passwords** in issues/PRs
- Use `.env.example` to document what variables are needed
- Always use `.gitignore` to exclude sensitive files
