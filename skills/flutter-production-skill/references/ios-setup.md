# iOS Setup Guide

Complete iOS configuration for Flutter apps with Firebase, push notifications, Google Sign-In, and App Store deployment.

## Prerequisites

- Apple Developer Account (€99/year) - Required for push notifications and TestFlight
- macOS with Xcode 15+ installed
- Physical iOS device for testing notifications (simulator doesn't support APNs)
- Firebase project configured

## Project Configuration

### 1. Open iOS Project in Xcode

```bash
# From project root
open ios/Runner.xcworkspace
```

**Important**: Always open `.xcworkspace`, not `.xcodeproj` (CocoaPods requirement)

### 2. Bundle Identifier

Set the bundle identifier in Xcode:
1. Select "Runner" project in navigator
2. Select "Runner" target
3. Go to "General" tab
4. Set "Bundle Identifier" (e.g., `com.yourcompany.appname`)

This must match:
- Firebase iOS app configuration
- Apple Developer App ID
- Any associated domains

### 3. Deployment Target

Set minimum iOS version:
1. Select "Runner" project
2. Select "Runner" target
3. Go to "General" tab
4. Set "Minimum Deployments" to iOS 16.0+

Also update in `ios/Podfile`:
```ruby
platform :ios, '16.0'
```

## Info.plist Configuration

### Location: `ios/Runner/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Name -->
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundleDisplayName</key>
    <string>YourAppName</string>

    <!-- Required for camera access -->
    <key>NSCameraUsageDescription</key>
    <string>This app needs camera access for live streaming</string>

    <!-- Required for microphone access -->
    <key>NSMicrophoneUsageDescription</key>
    <string>This app needs microphone access for live streaming audio</string>

    <!-- Required for photo library (if used) -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>This app needs access to your photos to upload images</string>

    <!-- Google Sign-In URL Schemes -->
    <key>CFBundleURLTypes</key>
    <array>
        <!-- Firebase/Google Sign-In -->
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <!-- Replace with your reversed client ID from GoogleService-Info.plist -->
                <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
            </array>
        </dict>
        <!-- Deep Links (optional) -->
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>yourapp</string>
            </array>
        </dict>
    </array>

    <!-- Background Modes -->
    <key>UIBackgroundModes</key>
    <array>
        <string>fetch</string>
        <string>remote-notification</string>
        <!-- Add if streaming -->
        <string>audio</string>
    </array>

    <!-- Allow arbitrary loads for development (remove in production) -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>

    <!-- Prevent screen capture (optional, for sensitive apps) -->
    <!-- <key>UIApplicationSupportsSecureWindows</key>
    <true/> -->
</dict>
</plist>
```

### Finding Google Reversed Client ID

1. Open `ios/Runner/GoogleService-Info.plist`
2. Look for `REVERSED_CLIENT_ID` key
3. Copy its value to Info.plist URL schemes

## Firebase Setup

### 1. Add iOS App to Firebase

1. Go to Firebase Console → Project Settings → Your apps
2. Click "Add app" → iOS
3. Enter Bundle ID (must match Xcode)
4. Download `GoogleService-Info.plist`
5. Drag file to `ios/Runner/` in Xcode (not Finder!)
6. Ensure "Copy items if needed" is checked
7. Ensure "Runner" target is selected

### 2. Verify Firebase Configuration

Check `ios/Runner/GoogleService-Info.plist` exists and contains:
- `BUNDLE_ID` matching your app
- `PROJECT_ID`
- `GOOGLE_APP_ID`
- `REVERSED_CLIENT_ID`

## Push Notifications (APNs)

### Step 1: Enable Push Notifications Capability

In Xcode:
1. Select "Runner" project
2. Select "Runner" target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" → check "Remote notifications"

### Step 2: Create APNs Key (Recommended)

In Apple Developer Portal:
1. Go to "Certificates, Identifiers & Profiles"
2. Select "Keys" in sidebar
3. Click "+" to create new key
4. Check "Apple Push Notifications service (APNs)"
5. Give it a name (e.g., "MyApp Push Key")
6. Click "Continue" → "Register"
7. **Download the .p8 file** (you can only download once!)
8. Note the Key ID

### Step 3: Upload APNs Key to Firebase

1. Go to Firebase Console → Project Settings
2. Select "Cloud Messaging" tab
3. Under "Apple app configuration", find your iOS app
4. Upload APNs Authentication Key (.p8 file)
5. Enter Key ID
6. Enter Team ID (from Apple Developer account)

### Step 4: Configure in Flutter

```dart
// In main.dart or initialization code
await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
  alert: true,
  badge: true,
  sound: true,
);

// Request permission (iOS requires explicit permission)
final settings = await FirebaseMessaging.instance.requestPermission(
  alert: true,
  announcement: false,
  badge: true,
  carPlay: false,
  criticalAlert: false,
  provisional: false,
  sound: true,
);

if (settings.authorizationStatus == AuthorizationStatus.authorized) {
  print('User granted permission');
  final token = await FirebaseMessaging.instance.getAPNSToken();
  print('APNs token: $token');
}
```

## Google Sign-In

### Step 1: Configure in Firebase

1. Firebase Console → Authentication → Sign-in method
2. Enable "Google"
3. Add support email

### Step 2: OAuth Client ID

Firebase automatically creates OAuth client IDs. Verify in:
1. Google Cloud Console → APIs & Services → Credentials
2. You should see an iOS client ID

### Step 3: Add URL Scheme

Already covered in Info.plist above. The URL scheme should be the `REVERSED_CLIENT_ID` from GoogleService-Info.plist.

### Step 4: Code Implementation

```dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<UserCredential?> signInWithGoogle() async {
  // Trigger the authentication flow
  final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

  if (googleUser == null) {
    // User cancelled the sign-in
    return null;
  }

  // Obtain the auth details
  final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

  // Create a credential
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  // Sign in to Firebase
  return await FirebaseAuth.instance.signInWithCredential(credential);
}
```

## Deep Links (Universal Links)

### Step 1: Associated Domains Capability

In Xcode:
1. Select "Runner" target
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "Associated Domains"
5. Add domain: `applinks:yourdomain.com`

### Step 2: Create apple-app-site-association

Host this JSON at `https://yourdomain.com/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.yourcompany.appname",
        "paths": [
          "/invite/*",
          "/list/*",
          "/task/*"
        ]
      }
    ]
  }
}
```

- `TEAMID` is your Apple Developer Team ID
- `com.yourcompany.appname` is your bundle identifier

### Step 3: Handle Deep Links in Flutter

```dart
// Using go_router
GoRouter(
  routes: [
    GoRoute(
      path: '/invite/:code',
      builder: (context, state) {
        final code = state.pathParameters['code']!;
        return InviteScreen(inviteCode: code);
      },
    ),
  ],
);

// Or manually with uni_links package
import 'package:uni_links/uni_links.dart';

void initDeepLinks() async {
  // Handle link when app is launched from link
  final initialLink = await getInitialLink();
  if (initialLink != null) {
    _handleDeepLink(initialLink);
  }

  // Handle links when app is already running
  linkStream.listen((String? link) {
    if (link != null) {
      _handleDeepLink(link);
    }
  });
}

void _handleDeepLink(String link) {
  final uri = Uri.parse(link);
  if (uri.pathSegments.isNotEmpty) {
    switch (uri.pathSegments.first) {
      case 'invite':
        final code = uri.pathSegments[1];
        // Navigate to invite screen
        break;
      case 'list':
        final listId = uri.pathSegments[1];
        // Navigate to list
        break;
    }
  }
}
```

## Signing & Certificates

### Development

For development, Xcode can automatically manage signing:
1. Select "Runner" target
2. Go to "Signing & Capabilities"
3. Check "Automatically manage signing"
4. Select your team

### Distribution (Release)

For App Store/TestFlight:

#### Create Distribution Certificate
1. Apple Developer → Certificates
2. Create "Apple Distribution" certificate
3. Download and double-click to install in Keychain

#### Create App ID
1. Apple Developer → Identifiers → App IDs
2. Register new App ID
3. Enable capabilities: Push Notifications, Sign in with Apple (if used)

#### Create Provisioning Profile
1. Apple Developer → Profiles
2. Create "App Store" profile
3. Select your App ID
4. Select your Distribution certificate
5. Download and double-click to install

### Exporting Signing Identity

For CI/CD or team sharing:
```bash
# Export certificate and private key from Keychain Access
# 1. Open Keychain Access
# 2. Find your certificate under "My Certificates"
# 3. Right-click → Export
# 4. Save as .p12 file with password
```

## Building for Release

### Archive and Upload

```bash
# Build release
flutter build ios --release

# Or build IPA directly
flutter build ipa --release
```

Then in Xcode:
1. Product → Archive
2. Window → Organizer
3. Select archive → Distribute App
4. Select "App Store Connect" → Upload

### TestFlight

1. Upload build via Xcode or Transporter app
2. Go to App Store Connect
3. Select your app → TestFlight
4. Wait for build processing
5. Add test information
6. Invite testers (internal or external)

### Troubleshooting Build Issues

#### Pod Install Failures
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

#### Signing Issues
```bash
# Check provisioning profiles
security find-identity -v -p codesigning
```

#### Archive Fails
1. Ensure all capabilities match between Xcode and Apple Developer
2. Check provisioning profile is not expired
3. Verify bundle ID matches everywhere

## Common iOS-Specific Patterns

### Status Bar Style

```dart
// In your app theme or specific screens
SystemChrome.setSystemUIOverlayStyle(
  const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light, // iOS
    statusBarIconBrightness: Brightness.dark, // Android
  ),
);
```

### Safe Area Handling

```dart
SafeArea(
  child: Scaffold(
    // Your content
  ),
);

// Or get safe area insets manually
final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
```

### Keyboard Handling

```dart
// Dismiss keyboard on tap outside
GestureDetector(
  onTap: () => FocusScope.of(context).unfocus(),
  child: Scaffold(
    // Content
  ),
);

// Scroll when keyboard appears
SingleChildScrollView(
  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
  child: // Content
);
```

### Platform-Specific Code

```dart
import 'dart:io';

if (Platform.isIOS) {
  // iOS-specific code
} else if (Platform.isAndroid) {
  // Android-specific code
}

// Or use Theme.of(context).platform
```

## Checklist Before Submission

- [ ] All required Info.plist keys have usage descriptions
- [ ] App icons are set (all sizes in Assets.xcassets)
- [ ] Launch screen is configured
- [ ] Bundle ID matches everywhere
- [ ] Version and build numbers are correct
- [ ] Push notifications work on physical device
- [ ] Deep links work
- [ ] All capabilities are enabled in Apple Developer
- [ ] Provisioning profile includes all capabilities
- [ ] Privacy policy URL is set in App Store Connect
- [ ] Screenshots are prepared for all device sizes
