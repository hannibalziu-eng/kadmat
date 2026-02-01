import 'dart:async';
import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// MOCK IMPLEMENTATION
class FcmService {
  static final FcmService _instance = FcmService._internal();

  factory FcmService() => _instance;

  FcmService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;

  // Broadcast stream for navigation events
  final _navigationStreamController = StreamController<String>.broadcast();
  Stream<String> get navigationStream => _navigationStreamController.stream;

  /// Initialize Mock FCM
  Future<void> initialize() async {
    log('⚠️ FCM is currently MOCKED/DISABLED by user request.');

    // Simulate getting a token
    _fcmToken = 'mock-fcm-token-${DateTime.now().millisecondsSinceEpoch}';
    log('🔥 Mock FCM Token: $_fcmToken');

    await _initLocalNotifications();
  }

  /// Stream of token refresh events (Empty for mock)
  Stream<String> get onTokenRefresh => const Stream.empty();

  /// Mock Subscribe
  Future<void> subscribeToTopic(String topic) async {
    log('📝 Mock Subscribe to topic: $topic');
  }

  /// Mock Unsubscribe
  Future<void> unsubscribeFromTopic(String topic) async {
    log('Cc Mock Unsubscribe from topic: $topic');
  }

  /// Initialize local notifications for foreground display (still useful for in-app alerts)
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
          log('🔔 Mock Local Notification Tapped with payload: $payload');
          _navigationStreamController.add(payload);
        }
      },
    );
  }

  String? get fcmToken => _fcmToken;
}
