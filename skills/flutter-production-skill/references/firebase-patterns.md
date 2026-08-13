# Firebase Patterns

Comprehensive patterns for Firebase-based Flutter apps with Authentication, Firestore, and Cloud Messaging.

## Firebase Project Setup

### 1. FlutterFire CLI (Recommended)

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (generates firebase_options.dart)
flutterfire configure --project=your-project-id

# This creates:
# - android/app/google-services.json
# - ios/Runner/GoogleService-Info.plist
# - lib/firebase_options.dart
```

### 2. Manual Setup (Alternative)

1. Create project at console.firebase.google.com
2. Add Android app: use package from `android/app/build.gradle`
3. Add iOS app: use bundle ID from Xcode
4. Download config files to correct locations

## Authentication Patterns

### Google Sign-In Complete Flow

```dart
class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  Future<UserModel> signInWithGoogle() async {
    // 1. Trigger Google Sign In flow
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Sign in cancelled by user');
    }

    // 2. Get auth details
    final googleAuth = await googleUser.authentication;

    // 3. Create Firebase credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 4. Sign in to Firebase
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    // 5. Create or update user in Firestore
    return _createOrUpdateUser(user);
  }

  Future<UserModel> _createOrUpdateUser(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      // Update last login
      await docRef.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'displayName': user.displayName,
        'photoURL': user.photoURL,
      });
      return UserModel.fromFirestore(await docRef.get());
    }

    // Create new user
    final newUser = UserModel(
      uid: user.uid,
      email: user.email!,
      displayName: user.displayName ?? user.email!.split('@').first,
      photoURL: user.photoURL,
      isApproved: false, // Requires admin approval
      isAdmin: false,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    await docRef.set(newUser.toFirestore());
    return newUser;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

// Custom exception
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
```

### Riverpod Auth Providers

```dart
// Provider for auth state stream
@riverpod
Stream<User?> authState(Ref ref) {
  return FirebaseAuth.instance.authStateChanges();
}

// Provider for current user model
@riverpod
Future<UserModel?> currentUserModel(Ref ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  return doc.exists ? UserModel.fromFirestore(doc) : null;
}

// Provider for user stream (real-time)
@riverpod
Stream<UserModel?> userStream(Ref ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
}

// Auth notifier for actions
@riverpod
class AuthNotifier extends _$AuthNotifier {
  late final AuthRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.read(authRepositoryProvider);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.signInWithGoogle());
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.signOut());
  }
}
```

## Firestore Patterns

### Repository with Streams and CRUD

```dart
class TasksRepository {
  final _firestore = FirebaseFirestore.instance;

  // Reference helper
  CollectionReference<Map<String, dynamic>> _tasksRef(String listId) =>
      _firestore.collection('lists').doc(listId).collection('tasks');

  // STREAM: Real-time list of tasks
  Stream<List<Task>> watchTasks(String listId, {bool? completed}) {
    Query<Map<String, dynamic>> query = _tasksRef(listId);

    if (completed != null) {
      query = query.where('isCompleted', isEqualTo: completed);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList());
  }

  // STREAM: Single task
  Stream<Task?> watchTask(String listId, String taskId) {
    return _tasksRef(listId).doc(taskId).snapshots().map(
          (doc) => doc.exists ? Task.fromFirestore(doc) : null,
        );
  }

  // CREATE
  Future<String> createTask(String listId, Task task) async {
    final docRef = await _tasksRef(listId).add(task.toFirestore());
    return docRef.id;
  }

  // READ (single fetch)
  Future<Task?> getTask(String listId, String taskId) async {
    final doc = await _tasksRef(listId).doc(taskId).get();
    return doc.exists ? Task.fromFirestore(doc) : null;
  }

  // UPDATE
  Future<void> updateTask(String listId, String taskId, Map<String, dynamic> data) async {
    await _tasksRef(listId).doc(taskId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // DELETE
  Future<void> deleteTask(String listId, String taskId) async {
    await _tasksRef(listId).doc(taskId).delete();
  }

  // TOGGLE COMPLETION
  Future<void> toggleTaskCompletion(String listId, String taskId, String userId) async {
    final doc = await _tasksRef(listId).doc(taskId).get();
    if (!doc.exists) return;

    final isCompleted = doc.data()!['isCompleted'] ?? false;

    await _tasksRef(listId).doc(taskId).update({
      'isCompleted': !isCompleted,
      'completedAt': !isCompleted ? FieldValue.serverTimestamp() : null,
      'completedBy': !isCompleted ? userId : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
```

### Batch Operations

```dart
// Delete list with all tasks
Future<void> deleteListWithTasks(String listId) async {
  final batch = _firestore.batch();

  // Get all tasks
  final tasks = await _firestore
      .collection('lists')
      .doc(listId)
      .collection('tasks')
      .get();

  // Add task deletions to batch
  for (final doc in tasks.docs) {
    batch.delete(doc.reference);
  }

  // Add list deletion
  batch.delete(_firestore.collection('lists').doc(listId));

  // Execute batch
  await batch.commit();
}

// Move multiple tasks
Future<void> moveTasksToList(
  String sourceListId,
  String targetListId,
  List<String> taskIds,
) async {
  final batch = _firestore.batch();

  for (final taskId in taskIds) {
    final sourceRef = _firestore
        .collection('lists')
        .doc(sourceListId)
        .collection('tasks')
        .doc(taskId);

    final doc = await sourceRef.get();
    if (!doc.exists) continue;

    // Add to target
    final targetRef = _firestore
        .collection('lists')
        .doc(targetListId)
        .collection('tasks')
        .doc(); // New ID

    batch.set(targetRef, {
      ...doc.data()!,
      'movedAt': FieldValue.serverTimestamp(),
    });

    // Delete from source
    batch.delete(sourceRef);
  }

  await batch.commit();
}
```

### Transactions

```dart
// Safe counter increment
Future<void> incrementTaskCount(String listId) async {
  await _firestore.runTransaction((transaction) async {
    final listRef = _firestore.collection('lists').doc(listId);
    final snapshot = await transaction.get(listRef);

    if (!snapshot.exists) {
      throw Exception('List not found');
    }

    final currentCount = snapshot.data()!['taskCount'] ?? 0;
    transaction.update(listRef, {'taskCount': currentCount + 1});
  });
}
```

### Compound Queries

```dart
// Tasks due this week, high priority, not completed
Stream<List<Task>> watchUrgentTasks(String listId) {
  final now = DateTime.now();
  final endOfWeek = now.add(Duration(days: 7 - now.weekday));

  return _tasksRef(listId)
      .where('isCompleted', isEqualTo: false)
      .where('priority', isEqualTo: 'high')
      .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
      .orderBy('dueDate')
      .snapshots()
      .map((s) => s.docs.map((d) => Task.fromFirestore(d)).toList());
}

// Note: This query requires a composite index
// Create in Firebase Console or via firebase.json
```

### Pagination

```dart
class PaginatedTasksProvider {
  static const _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  Future<List<Task>> loadNextPage(String listId) async {
    if (!_hasMore) return [];

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('lists')
        .doc(listId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.length < _pageSize) {
      _hasMore = false;
    }

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }

    return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
  }

  void reset() {
    _lastDocument = null;
    _hasMore = true;
  }
}
```

## Security Rules

### Basic Rules Structure

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }

    function isAdmin() {
      return isAuthenticated() && getUserData().isAdmin == true;
    }

    function isApproved() {
      return isAuthenticated() && getUserData().isApproved == true;
    }

    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isOwner(userId);
      allow update: if isOwner(userId) || isAdmin();
      allow delete: if isAdmin();
    }

    // Lists collection
    match /lists/{listId} {
      function isListMember() {
        return isAuthenticated() &&
               request.auth.uid in resource.data.members;
      }

      function canEditList() {
        return isListMember() &&
               resource.data.permissions[request.auth.uid] in ['owner', 'editor'];
      }

      allow read: if isListMember();
      allow create: if isApproved();
      allow update: if canEditList();
      allow delete: if resource.data.ownerId == request.auth.uid;

      // Tasks subcollection
      match /tasks/{taskId} {
        allow read: if isListMember();
        allow create: if canEditList();
        allow update: if canEditList();
        allow delete: if canEditList();
      }
    }

    // Notifications queue (for Cloud Functions)
    match /notifications_queue/{notifId} {
      allow read: if false; // Only Cloud Functions
      allow create: if isApproved();
      allow update, delete: if false;
    }
  }
}
```

### Deploy Rules

```bash
# Deploy rules only
firebase deploy --only firestore:rules

# Deploy with indexes
firebase deploy --only firestore
```

## FCM Token Management

### Save Token on Login

```dart
Future<void> saveUserFcmToken(String userId) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;

  await FirebaseFirestore.instance.collection('users').doc(userId).update({
    'fcmToken': token,
    'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
  });
}
```

### Token Refresh Listener

```dart
void setupTokenRefresh(String userId) {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'fcmToken': newToken,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  });
}
```

### Queue Notification for Cloud Function

```dart
Future<void> queueNotification({
  required String type,
  required String listId,
  required String? taskId,
  required List<String> recipientUserIds,
  required String title,
  required String body,
  Map<String, dynamic>? data,
}) async {
  await FirebaseFirestore.instance.collection('notifications_queue').add({
    'type': type,
    'listId': listId,
    'taskId': taskId,
    'recipientUserIds': recipientUserIds,
    'title': title,
    'body': body,
    'data': data ?? {},
    'createdAt': FieldValue.serverTimestamp(),
    'processed': false,
  });
}
```

### Cloud Function (Node.js)

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotification = functions.firestore
  .document('notifications_queue/{notifId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();

    // Get FCM tokens for recipients
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', notification.recipientUserIds)
      .get();

    const tokens = usersSnapshot.docs
      .map(doc => doc.data().fcmToken)
      .filter(token => token);

    if (tokens.length === 0) {
      console.log('No tokens found');
      return;
    }

    // Send notification
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        type: notification.type,
        listId: notification.listId,
        taskId: notification.taskId || '',
        ...notification.data,
      },
      tokens: tokens,
    };

    const response = await admin.messaging().sendMulticast(message);
    console.log(`Sent ${response.successCount}/${tokens.length} notifications`);

    // Mark as processed
    await snap.ref.update({ processed: true });
  });
```

## Offline Support

### Enable Persistence (Default on Mobile)

```dart
// In main.dart (if needed to configure)
await FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

### Handle Offline State

```dart
class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  StreamSubscription? _subscription;

  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    _subscription = FirebaseFirestore.instance
        .collection('_connectivity_check')
        .doc('status')
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      final newOnline = !snapshot.metadata.isFromCache;
      if (newOnline != _isOnline) {
        _isOnline = newOnline;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

### UI Offline Indicator

```dart
Consumer<ConnectivityProvider>(
  builder: (context, connectivity, _) {
    if (connectivity.isOnline) return const SizedBox.shrink();

    return Container(
      color: Colors.orange,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.white),
          SizedBox(width: 8),
          Text('Offline - Changes will sync when online',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  },
),
```
