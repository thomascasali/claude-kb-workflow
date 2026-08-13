# Flutter Troubleshooting Guide

Common issues and solutions for Flutter production apps.

## Build Errors

### Gradle Memory Issues

**Error:** `OutOfMemoryError` during build or slow builds

**Fix:** Update `android/gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
org.gradle.parallel=true
org.gradle.daemon=true
org.gradle.caching=true
```

### Kotlin Cache Corruption

**Error:** Random build failures after switching branches or pulling updates

**Fix:** Add to `android/gradle.properties`:
```properties
kotlin.incremental=false
kotlin.incremental.useClasspathSnapshot=false
```

Then clean:
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
```

### ProGuard/R8 Missing Classes

**Error:** `Warning: Missing class: org.slf4j.Logger` or similar

**Fix:** Add to `android/app/proguard-rules.pro`:
```proguard
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }
```

### Duplicate Classes Error

**Error:** `Duplicate class found in modules`

**Fix:** Add exclusions in `android/app/build.gradle.kts`:
```kotlin
configurations.all {
    exclude(group = "com.google.protobuf", module = "protobuf-lite")
}
```

### Dex Limit Exceeded

**Error:** `Cannot fit requested classes in a single dex file`

**Fix:** Enable multidex in `android/app/build.gradle.kts`:
```kotlin
android {
    defaultConfig {
        multiDexEnabled = true
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
```

## iOS Build Errors

### Pod Install Fails

**Error:** Various CocoaPods errors

**Fix:**
```bash
cd ios
rm -rf Pods Podfile.lock
rm -rf ~/Library/Caches/CocoaPods
pod cache clean --all
pod install --repo-update
cd ..
flutter clean
flutter pub get
```

### Xcode Signing Issues

**Error:** "Signing for 'Runner' requires a development team"

**Fix:**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → Signing & Capabilities
3. Select your team
4. If automatic signing fails, manually select provisioning profile

### Architecture Mismatch (M1/M2 Macs)

**Error:** Build fails on Apple Silicon

**Fix:** In `ios/Podfile`:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end
```

### Firebase iOS Build Error

**Error:** `Multiple commands produce 'GoogleService-Info.plist'`

**Fix:** Ensure GoogleService-Info.plist is only added once:
1. In Xcode, check Build Phases → Copy Bundle Resources
2. Remove duplicates if present

## Runtime Errors

### Type Cast Errors

**Error:** `type 'Null' is not a subtype of type 'int' in type cast`

**Cause:** Parsing entire response instead of nested object

**Wrong:**
```dart
return Task.fromJson(response.data);  // response.data is wrapper
```

**Correct:**
```dart
return Task.fromJson(response.data['task']);  // Extract nested object
```

**Defensive parsing:**
```dart
factory Task.fromJson(Map<String, dynamic> json) {
  return Task(
    id: json['id']?.toString() ?? '',
    title: json['title'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
  );
}
```

### NotifyListeners After Dispose

**Error:** `A ChangeNotifier was used after being disposed`

**Fix:** Guard all state changes:
```dart
class MyProvider extends ChangeNotifier {
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void updateState() {
    if (_disposed) return;
    // Update state
    notifyListeners();
  }
}
```

### Navigator Used After Async Gap

**Error:** Navigator fails after `await` operations

**Fix:** Check `mounted` or capture navigator before async:
```dart
// Option 1: Check mounted (StatefulWidget)
Future<void> doSomething() async {
  await someAsyncOperation();
  if (!mounted) return;
  Navigator.of(context).pop();
}

// Option 2: Capture navigator before
Future<void> doSomething() async {
  final navigator = Navigator.of(context);
  await someAsyncOperation();
  navigator.pop();
}

// Option 3: With Riverpod ref
Future<void> doSomething(WidgetRef ref) async {
  await someAsyncOperation();
  if (!ref.context.mounted) return;
  Navigator.of(ref.context).pop();
}
```

### Stream Not Updating UI

**Error:** Firestore stream changes don't reflect in UI

**Causes and fixes:**

1. **Not using StreamBuilder correctly:**
```dart
// Wrong: Listening in initState
@override
void initState() {
  stream.listen((data) => setState(() => _data = data));
}

// Correct: Use StreamBuilder
StreamBuilder<List<Task>>(
  stream: ref.watch(tasksStreamProvider(listId)),
  builder: (context, snapshot) {
    if (snapshot.hasError) return ErrorWidget(snapshot.error!);
    if (!snapshot.hasData) return const LoadingWidget();
    return TasksList(tasks: snapshot.data!);
  },
);
```

2. **Query changed but stream not reset:**
```dart
// With Riverpod: family provider auto-handles this
@riverpod
Stream<List<Task>> tasks(Ref ref, String listId) {
  return FirebaseFirestore.instance
      .collection('lists')
      .doc(listId)
      .collection('tasks')
      .snapshots()
      .map((s) => s.docs.map((d) => Task.fromFirestore(d)).toList());
}
```

### Firestore Permission Denied

**Error:** `PERMISSION_DENIED: Missing or insufficient permissions`

**Debug steps:**
1. Check Security Rules in Firebase Console
2. Verify user is authenticated: `FirebaseAuth.instance.currentUser`
3. Check document path is correct
4. Test rules in Firebase Console Rules Playground

**Common rule issues:**
```javascript
// Wrong: Using request.auth.uid on non-authenticated requests
allow read: if request.auth.uid == resource.data.ownerId;

// Correct: Check auth first
allow read: if request.auth != null && request.auth.uid == resource.data.ownerId;
```

## Firebase/FCM Issues

### FCM Token Not Received

**Debug:**
```dart
final token = await FirebaseMessaging.instance.getToken();
debugPrint('FCM Token: $token');

if (token == null) {
  // Check:
  // - google-services.json / GoogleService-Info.plist correct
  // - Firebase project setup
  // - Internet connectivity
  // - (iOS) APNs configured
}

// For iOS, also check APNs token
final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
debugPrint('APNs Token: $apnsToken');
```

### Notifications Not Showing in Foreground

**Cause:** FCM doesn't auto-show notifications when app is in foreground

**Fix:** Use flutter_local_notifications:
```dart
FirebaseMessaging.onMessage.listen((message) {
  final notification = message.notification;
  if (notification == null) return;

  flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance',
        'High Importance Notifications',
        importance: Importance.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
});
```

### iOS Notifications Not Working

**Checklist:**
1. APNs key uploaded to Firebase Console
2. Push Notifications capability enabled in Xcode
3. Background Modes → Remote notifications enabled
4. Physical device (simulator doesn't support APNs)
5. Permission requested and granted

```dart
// Check permission status
final settings = await FirebaseMessaging.instance.getNotificationSettings();
debugPrint('Auth status: ${settings.authorizationStatus}');
```

### Notification Tap Not Opening Correct Screen

**Fix:** Handle all three scenarios:
```dart
// 1. App in foreground
FirebaseMessaging.onMessage.listen(_handleMessage);

// 2. App in background, notification tapped
FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

// 3. App terminated, opened via notification
final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
if (initialMessage != null) {
  _handleMessageTap(initialMessage);
}

void _handleMessageTap(RemoteMessage message) {
  final data = message.data;
  final type = data['type'];
  final listId = data['listId'];
  final taskId = data['taskId'];

  // Navigate based on type
  if (type == 'task_created' && listId != null) {
    // Use GoRouter or Navigator
    context.go('/list/$listId/task/$taskId');
  }
}
```

## Streaming Issues

### Camera Preview Black Screen

**Causes and fixes:**

1. **Permission not granted:**
```dart
final status = await Permission.camera.status;
debugPrint('Camera permission: $status');
if (!status.isGranted) {
  await Permission.camera.request();
}
```

2. **Controller not initialized:**
```dart
await _controller.create(...);
debugPrint('Controller created: ${_controller != null}');
// Wait for camera to initialize
await Future.delayed(const Duration(milliseconds: 500));
```

3. **Preview widget not in tree:**
```dart
// Ensure CameraPreview is properly sized
SizedBox(
  width: MediaQuery.of(context).size.width,
  height: MediaQuery.of(context).size.height,
  child: CameraPreview(controller: _controller),
);
```

### RTMP Connection Fails

**Debug checklist:**
1. Verify RTMP URL format: `rtmp://host:port/app/streamkey`
2. Test server reachability: `telnet server 1935`
3. Check firewall allows outbound 1935
4. Verify stream key matches server config

**Common URL mistakes:**
```dart
// Wrong - missing port
'rtmp://stream.example.com/live/key'

// Wrong - wrong path structure
'rtmp://stream.example.com:1935/key'

// Correct
'rtmp://stream.example.com:1935/live/key'
```

### Stream Stops in Background

**Fix:** Use foreground service + wakelock:
```dart
// Start foreground service
await FlutterForegroundTask.startService(
  notificationTitle: 'Streaming',
  notificationText: 'Live stream in progress',
);

// Enable wakelock
await WakelockPlus.enable();
```

## Performance Issues

### UI Jank During Heavy Operations

**Fix:** Offload to isolate:
```dart
// For JSON parsing of large responses
final result = await compute(parseTaskList, responseData);

List<Task> parseTaskList(Map<String, dynamic> data) {
  final items = data['items'] as List;
  return items.map((e) => Task.fromJson(e)).toList();
}
```

### Memory Leak with Streams

**Fix:** Always cancel subscriptions:
```dart
class _MyScreenState extends State<MyScreen> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = someStream.listen((data) {
      // Handle
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

### ListView Performance

**Fix:** Use builder constructors:
```dart
// Wrong: Creates all items at once
ListView(
  children: items.map((item) => ItemWidget(item)).toList(),
);

// Correct: Creates items lazily
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
);
```

## Release Build Issues

### App Crashes Only in Release

**Cause:** ProGuard removing needed classes

**Debug:**
1. Check `build/app/outputs/mapping/release/mapping.txt` for removed classes
2. Add keep rules for problematic classes
3. Test with minification disabled first:

```kotlin
buildTypes {
    release {
        isMinifyEnabled = false  // Temporarily disable
    }
}
```

### Firebase Not Working in Release

**Cause:** SHA-256 fingerprint mismatch

**Fix:**
1. Get release SHA-256:
```bash
keytool -list -v -keystore upload-keystore.jks -alias upload
```
2. Add to Firebase Console → Project Settings → Your apps → Add fingerprint

### API Calls Fail in Release

**Cause:** Network security config or ProGuard

**Fix 1:** Network security (Android 9+):
```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">yourdomain.com</domain>
    </domain-config>
</network-security-config>
```

Reference in AndroidManifest:
```xml
<application
    android:networkSecurityConfig="@xml/network_security_config">
```

**Fix 2:** ProGuard OkHttp rules:
```proguard
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
```

## Testing on Real Devices

### ADB Wireless Debugging

```bash
# Connect device via USB first
adb tcpip 5555

# Get device IP (Settings → About → Status)
adb connect 192.168.1.xxx:5555

# Disconnect USB, run app
flutter run
```

### View Logs from Release Build

```bash
# Android
adb logcat -s flutter,FirebaseMessaging

# Filter by app
adb logcat | grep -E "(flutter|Firebase|YourAppName)"
```

### Force Stop and Clear Data

```bash
# Android
adb shell am force-stop com.yourcompany.appname
adb shell pm clear com.yourcompany.appname

# iOS
# Use Settings → General → iPhone Storage → Your App → Offload/Delete
```

## Quick Fixes Reference

| Problem | Quick Fix |
|---------|-----------|
| Build fails after update | `flutter clean && flutter pub get` |
| Pod install fails | `cd ios && rm -rf Pods Podfile.lock && pod install --repo-update` |
| Gradle sync fails | Delete `~/.gradle/caches` and rebuild |
| Emulator slow | Use physical device or enable hardware acceleration |
| Hot reload not working | Stop app, run `flutter run` again |
| Package conflicts | Check `pubspec.lock`, run `flutter pub upgrade --major-versions` |
| Firebase init fails | Regenerate `firebase_options.dart` with `flutterfire configure` |
| Null safety issues | Run `dart fix --apply` |
