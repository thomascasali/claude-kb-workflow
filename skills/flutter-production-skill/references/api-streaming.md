# API & Streaming Patterns

Patterns for Flutter apps with custom API backends (Laravel/REST), JWT authentication, RTMP streaming, and real-time WebSocket communication.

## API Service with Dio

### Complete API Service

```dart
// services/api_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String baseUrl;

  ApiService({required this.baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onResponse: _onResponse,
      onError: _onError,
    ));

    // Logging in debug mode
    assert(() {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
      return true;
    }());
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(response);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized - try token refresh
    if (error.response?.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Retry original request
        final response = await _retry(error.requestOptions);
        return handler.resolve(response);
      }
    }
    handler.next(error);
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      // Use clean Dio instance to avoid interceptor loop
      final response = await Dio().post(
        '$baseUrl/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newToken = response.data['token'];
      final newRefreshToken = response.data['refresh_token'];

      await _storage.write(key: 'auth_token', value: newToken);
      if (newRefreshToken != null) {
        await _storage.write(key: 'refresh_token', value: newRefreshToken);
      }

      return true;
    } catch (e) {
      // Refresh failed - clear tokens
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'refresh_token');
      return false;
    }
  }

  Future<Response> _retry(RequestOptions requestOptions) async {
    final token = await _storage.read(key: 'auth_token');
    final options = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $token',
      },
    );

    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  // HTTP methods
  Future<Response> get(String path, {Map<String, dynamic>? params}) {
    return _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path, {dynamic data}) {
    return _dio.delete(path, data: data);
  }

  // Multipart upload
  Future<Response> uploadFile(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? extraFields,
  }) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
      ...?extraFields,
    });
    return _dio.post(path, data: formData);
  }
}
```

### Laravel Response Handling

```dart
// utils/api_response.dart
class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final Map<String, List<String>>? errors;
  final PaginationMeta? meta;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.errors,
    this.meta,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic)? fromJsonT,
    String? dataKey,
  }) {
    // Handle data extraction
    T? parsedData;
    if (fromJsonT != null) {
      final rawData = dataKey != null ? json[dataKey] : json['data'];
      if (rawData != null) {
        parsedData = fromJsonT(rawData);
      }
    }

    return ApiResponse(
      success: json['success'] ?? true,
      message: json['message'],
      data: parsedData,
      errors: json['errors'] != null
          ? Map<String, List<String>>.from(
              json['errors'].map((k, v) => MapEntry(k, List<String>.from(v))),
            )
          : null,
      meta: json['meta'] != null ? PaginationMeta.fromJson(json['meta']) : null,
    );
  }

  String get firstError {
    if (errors == null || errors!.isEmpty) {
      return message ?? 'An error occurred';
    }
    return errors!.values.first.first;
  }

  bool get hasErrors => errors != null && errors!.isNotEmpty;
}

class PaginationMeta {
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  PaginationMeta({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      total: json['total'] ?? 0,
      perPage: json['per_page'] ?? 15,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
    );
  }

  bool get hasNextPage => currentPage < lastPage;
  bool get hasPrevPage => currentPage > 1;
}
```

### Error Handling

```dart
// utils/dio_error_handler.dart
String handleDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Connection timeout. Please check your internet.';

    case DioExceptionType.badResponse:
      return _handleBadResponse(error);

    case DioExceptionType.cancel:
      return 'Request was cancelled.';

    case DioExceptionType.connectionError:
      return 'No internet connection.';

    case DioExceptionType.badCertificate:
      return 'Security certificate error.';

    case DioExceptionType.unknown:
    default:
      if (error.error?.toString().contains('SocketException') ?? false) {
        return 'No internet connection.';
      }
      return 'Network error: ${error.message}';
  }
}

String _handleBadResponse(DioException error) {
  final statusCode = error.response?.statusCode;
  final data = error.response?.data;

  switch (statusCode) {
    case 400:
      return data?['message'] ?? 'Bad request.';
    case 401:
      return 'Session expired. Please login again.';
    case 403:
      return 'Access denied.';
    case 404:
      return 'Resource not found.';
    case 422:
      // Validation errors
      if (data is Map && data['errors'] != null) {
        final errors = data['errors'] as Map;
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          return firstError.first.toString();
        }
      }
      return data?['message'] ?? 'Validation failed.';
    case 429:
      return 'Too many requests. Please wait.';
    case 500:
    case 502:
    case 503:
      return 'Server error. Please try again later.';
    default:
      return data?['message'] ?? 'Request failed.';
  }
}
```

## JWT Authentication

### Token Manager

```dart
// services/token_manager.dart
class TokenManager {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _refreshKey = 'refresh_token';
  static const _expiryKey = 'token_expiry';
  static const _userKey = 'user_data';

  // Save tokens from login response
  static Future<void> saveTokens({
    required String token,
    String? refreshToken,
    DateTime? expiry,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
    if (expiry != null) {
      await _storage.write(key: _expiryKey, value: expiry.toIso8601String());
    }
  }

  // Get current token
  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  // Get refresh token
  static Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  // Check if token is expired (with 5 min buffer)
  static Future<bool> isTokenExpired() async {
    final expiryStr = await _storage.read(key: _expiryKey);
    if (expiryStr == null) return true;

    final expiry = DateTime.parse(expiryStr);
    final buffer = const Duration(minutes: 5);
    return DateTime.now().isAfter(expiry.subtract(buffer));
  }

  // Save user data
  static Future<void> saveUser(Map<String, dynamic> userData) async {
    await _storage.write(key: _userKey, value: jsonEncode(userData));
  }

  // Get saved user
  static Future<Map<String, dynamic>?> getUser() async {
    final data = await _storage.read(key: _userKey);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  // Clear all tokens
  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _expiryKey);
    await _storage.delete(key: _userKey);
  }

  // Check if logged in
  static Future<bool> hasValidToken() async {
    final token = await getToken();
    if (token == null) return false;

    final expired = await isTokenExpired();
    return !expired;
  }
}
```

### Auth Service with Auto-Login

```dart
// services/auth_service.dart
class AuthService {
  final ApiService _api;

  AuthService(this._api);

  Future<User> login(String email, String password, {bool remember = false}) async {
    final response = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
      'remember': remember,
    });

    final data = response.data;

    // Save tokens
    await TokenManager.saveTokens(
      token: data['token'],
      refreshToken: data['refresh_token'],
      expiry: data['expires_at'] != null
          ? DateTime.parse(data['expires_at'])
          : null,
    );

    // Parse and save user
    final user = User.fromJson(data['user'] ?? data);
    await TokenManager.saveUser(user.toJson());

    return user;
  }

  Future<User?> tryAutoLogin() async {
    final token = await TokenManager.getToken();
    if (token == null) return null;

    // Check if expired
    if (await TokenManager.isTokenExpired()) {
      final refreshed = await _tryRefreshToken();
      if (!refreshed) {
        await TokenManager.clear();
        return null;
      }
    }

    // Fetch fresh user data
    try {
      final response = await _api.get('/auth/user-profile');
      final user = User.fromJson(response.data['user'] ?? response.data);
      await TokenManager.saveUser(user.toJson());
      return user;
    } catch (e) {
      // If fetch fails, try cached user
      final cached = await TokenManager.getUser();
      if (cached != null) {
        return User.fromJson(cached);
      }
      await TokenManager.clear();
      return null;
    }
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await TokenManager.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${_api.baseUrl}/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      await TokenManager.saveTokens(
        token: response.data['token'],
        refreshToken: response.data['refresh_token'],
        expiry: response.data['expires_at'] != null
            ? DateTime.parse(response.data['expires_at'])
            : null,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Ignore logout API errors
    } finally {
      await TokenManager.clear();
    }
  }
}
```

## RTMP Streaming

### Streaming Service

```dart
// services/streaming_service.dart
import 'package:apivideo_live_stream/apivideo_live_stream.dart';

class StreamingService {
  LiveStreamController? _controller;
  bool _isStreaming = false;
  bool _isInitialized = false;

  bool get isStreaming => _isStreaming;
  bool get isInitialized => _isInitialized;

  Future<LiveStreamController> initialize({
    required Function(String) onError,
    required Function() onConnected,
    required Function() onDisconnected,
    VideoConfig? videoConfig,
    AudioConfig? audioConfig,
  }) async {
    _controller = LiveStreamController(
      onError: onError,
      onConnectionSuccess: () {
        _isStreaming = true;
        onConnected();
      },
      onConnectionFailed: (error) {
        _isStreaming = false;
        onError(error);
      },
      onDisconnection: () {
        _isStreaming = false;
        onDisconnected();
      },
    );

    await _controller!.create(
      initialVideoConfig: videoConfig ?? VideoConfig(
        resolution: Resolution.RESOLUTION_720,
        bitrate: 2000000,  // 2 Mbps
        fps: 30,
      ),
      initialAudioConfig: audioConfig ?? AudioConfig(
        bitrate: 128000,   // 128 kbps
        sampleRate: 44100,
        channel: Channel.stereo,
      ),
    );

    _isInitialized = true;
    return _controller!;
  }

  Future<void> startStreaming({
    required String rtmpUrl,
    required String streamKey,
  }) async {
    if (_controller == null) {
      throw Exception('Streaming controller not initialized');
    }
    if (_isStreaming) {
      throw Exception('Already streaming');
    }

    await _controller!.startStreaming(
      url: rtmpUrl,
      streamKey: streamKey,
    );
  }

  Future<void> stopStreaming() async {
    if (!_isStreaming || _controller == null) return;

    await _controller!.stopStreaming();
    _isStreaming = false;
  }

  void switchCamera() {
    _controller?.switchCamera();
  }

  void toggleMute() {
    _controller?.toggleMute();
  }

  Future<void> setVideoConfig(VideoConfig config) async {
    await _controller?.setVideoConfig(config);
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isStreaming = false;
  }
}
```

### Streaming Screen with Lifecycle

```dart
// screens/streaming_screen.dart
class StreamingScreen extends StatefulWidget {
  final String rtmpUrl;
  final String streamKey;

  const StreamingScreen({
    super.key,
    required this.rtmpUrl,
    required this.streamKey,
  });

  @override
  State<StreamingScreen> createState() => _StreamingScreenState();
}

class _StreamingScreenState extends State<StreamingScreen>
    with WidgetsBindingObserver {
  final _streamingService = StreamingService();
  bool _isInitialized = false;
  bool _isStreaming = false;
  String? _error;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeStreaming();
  }

  Future<void> _initializeStreaming() async {
    // Request permissions first
    final hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      setState(() => _error = 'Camera/microphone permission required');
      return;
    }

    // Keep screen on
    await WakelockPlus.enable();

    try {
      await _streamingService.initialize(
        onError: (error) {
          setState(() => _error = error);
          _stopHeartbeat();
        },
        onConnected: () {
          setState(() {
            _isStreaming = true;
            _error = null;
          });
          _startHeartbeat();
        },
        onDisconnected: () {
          setState(() => _isStreaming = false);
          _stopHeartbeat();
        },
      );

      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<bool> _requestPermissions() async {
    final camera = await Permission.camera.request();
    final microphone = await Permission.microphone.request();
    return camera.isGranted && microphone.isGranted;
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    // Send heartbeat to backend
    try {
      await context.read<ApiService>().post('/streaming/heartbeat', data: {
        'status': 'streaming',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Ignore heartbeat errors
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App in background - foreground service keeps streaming
        debugPrint('App paused - streaming continues in background');
        break;
      case AppLifecycleState.resumed:
        // Refresh UI state
        debugPrint('App resumed');
        break;
      case AppLifecycleState.detached:
        // App being destroyed - stop streaming
        _stopStreaming();
        break;
      default:
        break;
    }
  }

  Future<void> _startStreaming() async {
    // Start foreground service first
    await FlutterForegroundTask.startService(
      notificationTitle: 'Live Streaming',
      notificationText: 'Streaming in progress...',
    );

    await _streamingService.startStreaming(
      rtmpUrl: widget.rtmpUrl,
      streamKey: widget.streamKey,
    );
  }

  Future<void> _stopStreaming() async {
    await _streamingService.stopStreaming();
    await FlutterForegroundTask.stopService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _streamingService.dispose();
    WakelockPlus.disable();
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Streaming Error')),
        body: Center(child: Text(_error!)),
      );
    }

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview
          CameraPreview(controller: _streamingService._controller!),

          // Controls overlay
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.cameraswitch),
                  onPressed: _streamingService.switchCamera,
                ),
                ElevatedButton(
                  onPressed: _isStreaming ? _stopStreaming : _startStreaming,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStreaming ? Colors.red : Colors.green,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                  ),
                  child: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                ),
                IconButton(
                  icon: const Icon(Icons.mic_off),
                  onPressed: _streamingService.toggleMute,
                ),
              ],
            ),
          ),

          // Status indicator
          Positioned(
            top: 48,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isStreaming ? Colors.red : Colors.grey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isStreaming ? Colors.white : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isStreaming ? 'LIVE' : 'OFFLINE',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## WebSocket / Pusher

### Real-time Service

```dart
// services/realtime_service.dart
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class RealtimeService {
  PusherChannelsFlutter? _pusher;
  final Map<String, Function(dynamic)> _eventHandlers = {};
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<void> connect({
    required String apiKey,
    required String cluster,
    String? authEndpoint,
    Map<String, String>? authHeaders,
  }) async {
    _pusher = PusherChannelsFlutter.getInstance();

    await _pusher!.init(
      apiKey: apiKey,
      cluster: cluster,
      authEndpoint: authEndpoint,
      onConnectionStateChange: (currentState, previousState) {
        debugPrint('Pusher: $previousState -> $currentState');
        _isConnected = currentState == 'CONNECTED';
      },
      onError: (message, code, error) {
        debugPrint('Pusher error: $message ($code)');
      },
      onAuthorizer: authEndpoint == null
          ? null
          : (channelName, socketId, options) async {
              // Custom authorizer if needed
              return {};
            },
    );

    await _pusher!.connect();
  }

  Future<void> subscribeToChannel(
    String channelName, {
    bool isPrivate = false,
  }) async {
    final fullName = isPrivate ? 'private-$channelName' : channelName;

    await _pusher?.subscribe(
      channelName: fullName,
      onEvent: (event) {
        final handler = _eventHandlers['$fullName.${event.eventName}'];
        if (handler != null) {
          final data = event.data is String
              ? jsonDecode(event.data)
              : event.data;
          handler(data);
        }
      },
    );
  }

  void onEvent(
    String channel,
    String event,
    Function(dynamic) handler, {
    bool isPrivate = false,
  }) {
    final fullChannel = isPrivate ? 'private-$channel' : channel;
    _eventHandlers['$fullChannel.$event'] = handler;
  }

  Future<void> unsubscribe(String channelName, {bool isPrivate = false}) async {
    final fullName = isPrivate ? 'private-$channelName' : channelName;
    await _pusher?.unsubscribe(channelName: fullName);

    // Remove handlers
    _eventHandlers.removeWhere((key, _) => key.startsWith(fullName));
  }

  Future<void> disconnect() async {
    await _pusher?.disconnect();
    _eventHandlers.clear();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _pusher = null;
  }
}

// Usage example
final realtime = RealtimeService();

await realtime.connect(
  apiKey: 'your-pusher-key',
  cluster: 'eu',
  authEndpoint: 'https://api.example.com/broadcasting/auth',
);

await realtime.subscribeToChannel('campo.1', isPrivate: true);

realtime.onEvent('campo.1', 'overlay.updated', (data) {
  final overlay = StreamOverlay.fromJson(data['overlay']);
  // Update UI
}, isPrivate: true);
```

### Reconnection Logic

```dart
class RealtimeServiceWithReconnect {
  final RealtimeService _service;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  static const _reconnectDelay = Duration(seconds: 5);

  RealtimeServiceWithReconnect(this._service);

  void setupAutoReconnect() {
    // This would be called in the connection state change handler
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      _reconnectAttempts++;
      debugPrint('Reconnecting... attempt $_reconnectAttempts');

      try {
        await _service.connect(
          apiKey: 'your-key',
          cluster: 'eu',
        );
        _reconnectAttempts = 0;
      } catch (e) {
        _scheduleReconnect();
      }
    });
  }

  void cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
  }
}
```

## Foreground Service

### Service Configuration

```dart
// services/foreground_service.dart
class ForegroundService {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'streaming_service',
        channelName: 'Streaming Service',
        channelDescription: 'Keeps streaming active in background',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: [
          const NotificationButton(id: 'stop', text: 'Stop'),
        ],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> start({
    required String title,
    required String text,
  }) async {
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    return FlutterForegroundTask.startService(
      notificationTitle: title,
      notificationText: text,
      callback: _startCallback,
    );
  }

  static Future<bool> updateNotification({
    String? title,
    String? text,
  }) async {
    return FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  static Future<bool> stop() => FlutterForegroundTask.stopService();

  @pragma('vm:entry-point')
  static void _startCallback() {
    FlutterForegroundTask.setTaskHandler(StreamingTaskHandler());
  }
}

class StreamingTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp) {
    debugPrint('Foreground service started');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Called every interval (5 seconds)
    // Can be used for heartbeat
  }

  @override
  void onDestroy(DateTime timestamp) {
    debugPrint('Foreground service destroyed');
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      // Handle stop button
      ForegroundService.stop();
    }
  }
}
```

## Provider Pattern (ChangeNotifier)

### Base Provider with Error Handling

```dart
// providers/base_provider.dart
abstract class BaseProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  @protected
  void setLoading(bool value) {
    if (_disposed) return;
    _isLoading = value;
    notifyListeners();
  }

  @protected
  void setError(String? value) {
    if (_disposed) return;
    _error = value;
    notifyListeners();
  }

  void clearError() => setError(null);

  @protected
  Future<T?> safeCall<T>(Future<T> Function() action) async {
    setLoading(true);
    clearError();
    try {
      final result = await action();
      return result;
    } on DioException catch (e) {
      setError(handleDioError(e));
      return null;
    } catch (e) {
      setError(e.toString());
      return null;
    } finally {
      setLoading(false);
    }
  }

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
}
```

### Streaming Provider Example

```dart
// providers/streaming_provider.dart
class StreamingProvider extends BaseProvider {
  final StreamingService _streamingService;
  final ApiService _apiService;

  StreamOverlay? _currentOverlay;
  bool _isLive = false;

  StreamOverlay? get currentOverlay => _currentOverlay;
  bool get isLive => _isLive;

  StreamingProvider(this._streamingService, this._apiService);

  Future<void> loadOverlay(int campoId) async {
    await safeCall(() async {
      final response = await _apiService.get('/streaming/overlay/$campoId');
      _currentOverlay = StreamOverlay.fromJson(response.data['overlay']);
    });
  }

  Future<bool> startStream(String rtmpUrl, String streamKey) async {
    final result = await safeCall(() async {
      await _streamingService.startStreaming(
        rtmpUrl: rtmpUrl,
        streamKey: streamKey,
      );
      _isLive = true;
      return true;
    });
    return result ?? false;
  }

  Future<void> stopStream() async {
    await safeCall(() async {
      await _streamingService.stopStreaming();
      _isLive = false;
    });
  }

  void updateOverlay(StreamOverlay overlay) {
    _currentOverlay = overlay;
    notifyListeners();
  }
}
```
