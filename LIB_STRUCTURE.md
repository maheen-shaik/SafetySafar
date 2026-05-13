# Frontend (Flutter) Project Structure

## Overview
The Safety Safar Flutter app is organized into screens, services, and utilities. This guide explains each component.

## 📁 Project Layout

```
lib/
├── main.dart                          # App entry point
├── login_screen.dart                  # User login
├── registration_screen.dart           # New user registration
├── otp_screen.dart                    # OTP verification
├── reset_password_screen.dart         # Password reset
├── home_screen.dart                   # Home dashboard
├── digital_id_screen.dart             # Digital ID feature
│
├── screens/                           # Additional feature screens
│   ├── authority_dashboard.dart       # Authority/Admin dashboard
│   ├── authority_settings_screen.dart # Authority settings
│   ├── kyc_pending_list_screen.dart   # KYC approval pending list
│   ├── kyc_review_detail_screen.dart  # KYC document review
│   ├── live_alerts_map_screen.dart    # Real-time alerts on map
│   ├── sos_alerts_screen.dart         # SOS alerts list
│   ├── tourists_list_screen.dart      # Tourist management list
│   └── tourist_dashboard.dart         # Tourist home screen
│
├── services/                          # API & data services
│   ├── discovery_service.dart         # Discovery/find services
│   ├── kyc_service.dart               # KYC (Know Your Customer) API calls
│   ├── location_tracking_service.dart # Location tracking functionality
│   └── tourist_service.dart           # Tourist data API calls
│
└── utils/                             # Utility functions & constants
    ├── api_config.dart                # API configuration & base URL
    └── country_codes.dart             # Country codes data
```

## 🎨 Screens

### Authentication Screens
- **`login_screen.dart`** - User login with email/password or Google sign-in
- **`registration_screen.dart`** - New user registration for tourists and authorities
- **`otp_screen.dart`** - OTP verification for registration/password reset
- **`reset_password_screen.dart`** - Password reset functionality

### Main Screens
- **`home_screen.dart`** - Main dashboard showing user alerts and features
- **`digital_id_screen.dart`** - Generate and display digital ID with QR code

### Tourist Features
- **`tourist_dashboard.dart`** - Tourist-specific dashboard
- **`tourists_list_screen.dart`** - List of tourists (for authorities)
- **`live_alerts_map_screen.dart`** - Real-time map showing SOS alerts
- **`sos_alerts_screen.dart`** - View and manage SOS alerts

### Authority/Admin Features
- **`authority_dashboard.dart`** - Admin dashboard with statistics and alerts
- **`authority_settings_screen.dart`** - Admin settings and configuration
- **`kyc_pending_list_screen.dart`** - List of pending KYC verifications
- **`kyc_review_detail_screen.dart`** - Review KYC documents in detail

## 🔧 Services

### API Services
Services handle all communication with the backend API:

- **`kyc_service.dart`**
  - Handle KYC document uploads
  - Verify identity documents
  - Fetch KYC status

- **`tourist_service.dart`**
  - Get tourist profile information
  - Update tourist data
  - Manage tourist account

- **`location_tracking_service.dart`**
  - Send location updates to backend
  - Track real-time location
  - Handle GPS and geolocation

- **`discovery_service.dart`**
  - Search for nearby services
  - Find emergency contacts
  - Discover tourist attractions

### How Services Work
Each service:
1. Makes HTTP requests to the backend
2. Handles authentication with JWT tokens
3. Parses JSON responses
4. Handles errors gracefully

Example:
```dart
// In a screen
final tourist = await TouristService().getTouristProfile();
```

## 🛠️ Utilities

### `api_config.dart`
- **Base URL** - Backend server endpoint (e.g., `http://localhost:8000`)
- **API endpoints** - Paths for all API routes
- **HTTP client setup** - Configuration for HTTP requests

### `country_codes.dart`
- List of country codes with flags
- Used in registration and profile forms
- Phone number country selection

## 🔄 Data Flow

```
UI Screen
    ↓
Service (Authentication + HTTP)
    ↓
Backend API
    ↓
Database
```

### Example Flow: Login
1. User enters email/password in `login_screen.dart`
2. Service calls `/auth/login` endpoint via HTTP
3. Backend validates credentials
4. JWT token returned
5. Token saved locally (shared_preferences)
6. Navigate to home screen

## 📱 Widget Architecture

Most screens follow this pattern:
```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  // UI building and logic here
}
```

## State Management
Uses **Provider** package for state management:
- Watch for changes
- Notify widgets
- Separate UI from business logic

## 🔐 Authentication Flow

1. **Registration** → `registration_screen.dart` → Backend creates user
2. **OTP Verification** → `otp_screen.dart` → Verifies email/phone
3. **Login** → `login_screen.dart` → Returns JWT token
4. **Token Storage** → Stored in `shared_preferences`
5. **API Calls** → Include token in request headers

## 📍 Real-Time Features

- **Location Tracking** - Updates sent periodically via `location_tracking_service.dart`
- **Live Alerts Map** - Updates from backend via polling or WebSocket
- **SOS System** - Emergency alerts pushed to authorities in real-time

## 🧪 Testing Locally

1. Backend must be running: `http://localhost:8000`
2. Update `api_config.dart` with correct backend URL
3. Firebase must be configured
4. Run: `flutter run`

## 📦 Key Dependencies Used

- **http** - API calls
- **provider** - State management
- **firebase_core & firebase_auth** - Authentication
- **geolocator** - Location services
- **google_maps_flutter** - Map display
- **image_picker** - Document upload
- **qr_flutter** - QR code generation
- **google_fonts** - Custom fonts
- **shared_preferences** - Local storage

## 🚀 Adding New Features

To add a new screen:
1. Create new file in `screens/` or root `lib/`
2. Create corresponding service in `services/` if API calls needed
3. Import and navigate in app routing
4. Add to `main.dart` navigation

To add new API calls:
1. Create/update service in `services/`
2. Use `http` package for requests
3. Include JWT token in headers
4. Parse response and handle errors
5. Call from UI screen

## 🔗 Quick Links

- Backend API Docs: `http://localhost:8000/docs`
- Firebase Console: https://console.firebase.google.com
- Flutter Documentation: https://flutter.dev/docs
