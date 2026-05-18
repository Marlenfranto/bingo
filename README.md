# LinkedIn QR Connector

A Flutter web application that provides a 25-box grid interface for QR code scanning and automatic LinkedIn connection requests.

## Features

- **25 Interactive Boxes Grid**: A responsive 5x5 grid where each box can be tapped to initiate QR scanning
- **Camera QR Scanner**: Real-time QR code scanning using device camera
- **LinkedIn Integration**: Automatic LinkedIn connection request sending after successful scan
- **Profile Management**: User profile page with LinkedIn URL configuration
- **One-time Scan Restriction**: Each user can only scan each box once
- **Progressive Web App**: Runs smoothly in web browsers with camera access

## How It Works

1. **Setup Profile**: First-time users need to set up their profile with name and LinkedIn URL
2. **Select Box**: Tap any of the 25 boxes to start scanning
3. **Scan QR Code**: Camera opens automatically to scan someone else's LinkedIn QR code
4. **Auto-Connect**: App automatically sends a LinkedIn connection request
5. **Track Progress**: Visual feedback shows which boxes have been scanned

## Installation & Setup

### Prerequisites
- Flutter SDK (latest stable version)
- Web browser with camera support
- LinkedIn profile URL

### Running the App

1. **Clone/Navigate to project directory**:
   ```bash
   cd namma_bingo
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run on web**:
   ```bash
   flutter run -d chrome
   # or for web server
   flutter run -d web-server --web-port=3000
   ```

4. **Build for production**:
   ```bash
   flutter build web
   ```

## App Structure

```
lib/
├── main.dart                 # App entry point with routing
├── models/
│   └── user.dart            # User and BingoBox data models
├── providers/
│   └── app_providers.dart   # State management with Riverpod
├── screens/
│   ├── home_screen.dart     # Main 25-box grid interface
│   ├── profile_screen.dart  # User profile setup/editing
│   └── camera_screen.dart   # QR code scanning camera
└── widgets/
    └── bingo_grid.dart      # Reusable grid components
```

## Dependencies

- **flutter_riverpod**: State management
- **mobile_scanner**: QR code scanning
- **camera**: Camera access
- **shared_preferences**: Data persistence
- **url_launcher**: LinkedIn URL handling
- **http/dio**: API requests
- **permission_handler**: Camera permissions

## Usage Instructions

### For First-Time Users:
1. Open the app in your web browser
2. Click "Setup Profile" to add your name and LinkedIn URL
3. Save your profile to enable box scanning

### For Scanning:
1. Tap any available (non-green) box
2. Allow camera permissions when prompted
3. Point camera at someone's LinkedIn QR code
4. Wait for automatic processing and connection request
5. Success dialog confirms the connection

### LinkedIn QR Code:
- LinkedIn profile → "More" → "QR code"
- Share your QR code for others to scan
- Scan others' QR codes to connect automatically

## Features in Detail

### State Management
- Uses Riverpod for reactive state management
- Persists user data and scan progress locally
- Real-time UI updates across screens

### Camera Integration
- Mobile scanner for cross-platform QR detection
- Torch/flash control for low light
- Front/back camera switching
- Visual scanning frame with indicators

### LinkedIn Integration
- Validates LinkedIn URL format
- Simulated connection request (demo mode)
- Real implementation would use LinkedIn API

### Responsive Design
- 5x5 grid layout adapts to screen size
- Card-based UI with Material Design 3
- Clear visual states for scanned/available boxes

## Browser Permissions

The app requires camera permissions to function:
- **Chrome**: Allow camera access when prompted
- **Safari**: Enable camera in site settings
- **Firefox**: Grant camera permissions in address bar

## Development Notes

### Camera Testing
- Requires HTTPS in production for camera access
- Use `flutter run -d chrome --web-browser-flag="--disable-web-security"` for local development
- Test with actual LinkedIn QR codes for best experience

### LinkedIn API (Production)
- Currently uses simulated API calls
- Real implementation needs LinkedIn Developer Account
- OAuth 2.0 authentication required for connection requests
- Rate limiting considerations for API calls

## Troubleshooting

**Camera not working?**
- Check browser permissions
- Ensure HTTPS connection
- Try different browser or incognito mode

**QR code not scanning?**
- Ensure good lighting conditions
- Hold steady and at appropriate distance
- Use LinkedIn's official QR code format

**Profile not saving?**
- Check LinkedIn URL format
- Ensure proper network connection
- Clear browser cache if issues persist

## Future Enhancements

- Real LinkedIn API integration
- User authentication system
- Social features (leaderboards, teams)
- Export/share functionality
- Advanced scanning statistics
- Offline mode support

## License

This project is for educational and demonstration purposes.
