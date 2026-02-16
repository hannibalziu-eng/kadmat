import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'push/push_gateway.dart';

class FcmService implements PushGateway {
  static final FcmService _instance = FcmService._internal();

  factory FcmService() => _instance;

  FcmService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  String? _fcmToken;
  bool _isInitialized = false;
  bool _isFirebaseReady = false;
  StreamSubscription<String>? _tokenRefreshSubscription;

  // Broadcast stream for navigation events
  final _navigationStreamController = StreamController<String>.broadcast();
  final _tokenRefreshController = StreamController<String>.broadcast();

  @override
  Stream<String> get navigationStream => _navigationStreamController.stream;

  /// Initialize FCM with dev-safe fallback.
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _initLocalNotifications();
    if (kIsWeb) {
      debugPrint('ℹ️ FCM runtime skipped on Web.');
      return;
    }

    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
          '⚠️ Notification permission denied. Push will stay disabled.',
        );
        return;
      }

      _isFirebaseReady = true;
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('🔥 FCM token initialized: ${_fcmToken != null}');

      _tokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen((
        token,
      ) {
        _fcmToken = token;
        if (!_tokenRefreshController.isClosed) {
          _tokenRefreshController.add(token);
        }
      });
    } catch (e) {
      debugPrint('⚠️ FCM unavailable, continuing with local fallback: $e');
      _isFirebaseReady = false;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Future<void> subscribeToTopic(String topic) async {
    if (!_isFirebaseReady || kIsWeb) return;
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('⚠️ Subscribe topic failed ($topic): $e');
    }
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isFirebaseReady || kIsWeb) return;
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('⚠️ Unsubscribe topic failed ($topic): $e');
    }
  }

  /// Initialize local notifications for in-app alerts and payload navigation.
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          debugPrint('🔔 Local notification tapped with payload: $payload');
          _navigationStreamController.add(payload);
        }
      },
    );
  }

  String? get fcmToken => _fcmToken;

  @override
  String? get currentToken => _fcmToken;

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _tokenRefreshController.close();
    await _navigationStreamController.close();
    _isInitialized = false;
  }
}

final pushGatewayProvider = Provider<PushGateway>((ref) {
  if (kIsWeb) {
    return NoopPushGateway();
  }
  return FcmService();
});
