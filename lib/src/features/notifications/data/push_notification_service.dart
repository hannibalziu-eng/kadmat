import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadmat/src/core/api/api_client.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/core/router_modular.dart';
import 'package:flutter/foundation.dart';
import 'package:kadmat/src/features/auth/data/auth_repository.dart';

/// Provider for PushNotificationService
final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(ref);
});

class PushNotificationService {
  final Ref _ref;
  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  PushNotificationService(this._ref);

  /// Initialize Firebase Messaging & Local Notifications
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      debugPrint('ℹ️ PushNotificationService skipped on Web');
      _isInitialized = true;
      return;
    }

    _fcm ??= FirebaseMessaging.instance;
    final fcm = _fcm;
    if (fcm == null) return;

    try {
      // 1. Request Permission
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ User granted provisional permission');
      } else {
        debugPrint('❌ User declined or has not accepted permission');
        return;
      }

      // 2. Setup Local Notifications (for foreground)
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Note: Requesting permission on iOS is redundant here as requestPermission does it,
      // but needed for older versions or explicit local notification setup.
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onSelectNotification,
      );

      // 3. Setup FCM Listeners

      // On Message (Foreground)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // On Message Opened App (Background -> Foreground)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Get Initial Message (Terminated -> Foreground)
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // 4. Update Token
      final token = await fcm.getToken();
      if (token != null) {
        debugPrint('📲 FCM Token: $token');
        // We don't register here immediately.
        // We register after login in LoginController or HomeScreen.
      }

      // Listen for regular token refresh
      fcm.onTokenRefresh.listen(registerToken);
      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ PushNotificationService init skipped: $e');
    }
  }

  /// Send token to Backend
  Future<void> registerToken(String token) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.post(
        '/notifications/fcm-token',
        data: {'fcmToken': token},
      );
      debugPrint('✅ FCM Token registered with backend');
    } catch (e) {
      debugPrint('❌ Failed to register FCM token: $e');
    }
  }

  /// Get current token and register it
  Future<void> registerCurrentToken() async {
    if (kIsWeb) return;
    await initialize();

    try {
      final fcm = _fcm ?? FirebaseMessaging.instance;
      final token = await fcm.getToken();
      if (token != null) {
        await registerToken(token);
      }
    } catch (e) {
      debugPrint('⚠️ registerCurrentToken skipped: $e');
    }
  }

  /// Handle Foreground Message
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground Message: ${message.notification?.title}');

    if (message.notification != null) {
      _showLocalNotification(message);
    }
  }

  /// Show Local Notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'kadmat_notifications', // channelId
          'Kadmat Notifications', // channelName
          channelDescription: 'Important notifications from Kadmat',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  /// Handle Notification Tap (Foreground banner or Background)
  void _onSelectNotification(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _navigateBasedOnPayload(data);
    }
  }

  /// Handle Notification Tap (From Background/Terminated)
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔄 Notification caused app to open: ${message.data}');
    _navigateBasedOnPayload(message.data);
  }

  /// Deep Linking Logic
  void _navigateBasedOnPayload(Map<String, dynamic> data) {
    final type = data['type'];
    final router = _ref.read(goRouterProvider);
    final userType = _ref.read(authRepositoryProvider).userType;

    if (type == 'chat_message') {
      final jobId = data['job_id'];
      if (jobId != null) {
        router.push(AppRoutes.buildJobChatPath(jobId));
      }
    } else if (type == 'new_job_offer' ||
        type == 'job_accepted' ||
        type == 'price_request' ||
        type == 'completion_request') {
      final jobId = data['job_id'];
      if (jobId != null) {
        if (userType == 'technician') {
          router.push(AppRoutes.buildTechnicianJobDetailPath(jobId));
        } else {
          router.push(AppRoutes.buildCustomerSearchingPath(jobId));
        }
      }
    }
  }
}
