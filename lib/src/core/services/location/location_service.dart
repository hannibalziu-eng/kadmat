import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_sync_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final locationStreamProvider = StreamProvider<Position>((ref) {
  return LocationService().locationStream;
});

enum LocationTrackingMode {
  idle, // Low frequency (e.g. 30s)
  active, // High frequency (e.g. 5s)
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  FlutterBackgroundService? _serviceInstance;
  bool _isInitialized = false;

  // Lazy access to service to prevent Web crash on instantiation
  FlutterBackgroundService get _service {
    if (kIsWeb) {
      throw UnsupportedError(
        'FlutterBackgroundService is not supported on Web',
      );
    }
    _serviceInstance ??= FlutterBackgroundService();
    return _serviceInstance!;
  }

  final _locationStreamController = StreamController<Position>.broadcast();

  Stream<Position> get locationStream => _locationStreamController.stream;

  StreamSubscription<Position>? _webPositionSubscription;

  Future<void> initialize() async {
    if (kIsWeb || _isInitialized) return; // Skip background service init on Web

    const notificationChannelId = 'location_service_channel';
    const notificationId = 888;

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Android Notification Setup
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            notificationChannelId,
            'Kadmat Location Service',
            description: 'Background location tracking for technicians',
            importance: Importance.low,
          ),
        );

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'خدمة الموقع نشطة',
        initialNotificationContent: 'جاري تتبع الموقع في الخلفية...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Listen for updates ONLY when app is open (Foreground to UI)
    _service.on('update').listen((event) {
      if (event != null &&
          event.containsKey('lat') &&
          event.containsKey('lng')) {
        debugPrint('Device Location Update: ${event['lat']}, ${event['lng']}');
        // Parse and add to stream controller for UI consumption
        try {
          final position = Position(
            latitude: event['lat'] as double,
            longitude: event['lng'] as double,
            timestamp: DateTime.parse(event['timestamp'] as String),
            accuracy: (event['accuracy'] as num).toDouble(),
            altitude: 0.0,
            heading: (event['heading'] as num).toDouble(),
            speed: (event['speed'] as num).toDouble(),
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
            isMocked: event['is_mocked'] == true,
          );
          _locationStreamController.add(position);
        } catch (e) {
          debugPrint('Error parsing location update: $e');
        }
      }
    });

    _isInitialized = true;
  }

  Future<void> startTracking(String userId) async {
    if (!kIsWeb && !_isInitialized) {
      await initialize();
    }

    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      throw Exception('Location permissions denied');
    }

    // Save userId for background usage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tracking_user_id', userId);

    if (kIsWeb) {
      // Web Implementation: Direct Stream
      _webPositionSubscription?.cancel();
      _webPositionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((position) async {
            _locationStreamController.add(position);
            debugPrint(
              'Web Location Update: ${position.latitude}, ${position.longitude}',
            );

            // Sync to backend for Web
            try {
              final syncService = LocationSyncService();
              await syncService.initialize();
              await syncService.updateLocation(
                lat: position.latitude,
                lng: position.longitude,
                userId: userId,
              );
            } catch (e) {
              debugPrint('⚠️ Failed to sync location on Web: $e');
            }
          });
    } else {
      await _service.startService();
      // Send immediate config update just in case
      _service.invoke('setConfig', {'userId': userId});
    }
  }

  Future<void> stopTracking() async {
    if (kIsWeb) {
      await _webPositionSubscription?.cancel();
      _webPositionSubscription = null;
    } else {
      _service.invoke('stopService');
    }
  }

  Future<void> setTrackingMode(LocationTrackingMode mode) async {
    if (!kIsWeb) {
      _service.invoke('setMode', {'mode': mode.index});
    }
  }

  Future<bool> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }
}

// ========== BACKGROUND ISOLATE ENTRY POINT ==========

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // 1. Initialize Sync Service
  final syncService = LocationSyncService();
  await syncService.initialize();

  // 2. Get User ID (Try prefs first)
  final prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('tracking_user_id');

  // Default Settings
  LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high, // User requested continuous/high
    distanceFilter: 10, // User requested 10m
  );

  StreamSubscription<Position>? positionSubscription;

  // Handler for config/mode changes
  service.on('setConfig').listen((event) async {
    if (event != null && event.containsKey('userId')) {
      userId = event['userId'] as String;
      await prefs.setString('tracking_user_id', userId!);
    }
  });

  service.on('setMode').listen((event) {
    // Manual mode override if needed, but we will rely more on auto-adaptive
    // ... logic remains but we can enhance defaults
  });

  service.on('stopService').listen((event) {
    positionSubscription?.cancel();
    service.stopSelf();
  });

  // Start listening
  positionSubscription =
      Geolocator.getPositionStream(locationSettings: locationSettings).listen((
        Position position,
      ) {
        // Auto-Adaptive Logic: Switch accuracy based on speed
        // Speed is in m/s.
        // If moving > 2 m/s (~7 km/h), ensure high accuracy.
        // Note: Changing settings requires restarting stream, creating a loop.
        // Better to handle "logic" of sync frequency rather than stream frequency if expensive.
        // But geolocator stream settings dictate battery usage.

        // For now, let's keep the stream steady but update tracking mode if significant movement.
        _handlePositionUpdate(service, position, userId, syncService);
      });
}

// ...

void _handlePositionUpdate(
  ServiceInstance service,
  Position position,
  String? userId,
  LocationSyncService syncService,
) {
  // 1. Send to UI
  service.invoke('update', {
    'lat': position.latitude,
    'lng': position.longitude,
    'speed': position.speed,
    'heading': position.heading,
    'timestamp': position.timestamp.toIso8601String(),
    'accuracy': position.accuracy,
    'is_mocked': position.isMocked,
  });

  // 2. Sync to Backend
  // Only sync if significant change or time elapsed?
  // User wants "Continuous 5s".
  // Let SyncService handle throttling/queuing if needed.
  if (userId != null) {
    if (position.accuracy > 100) {
      debugPrint('⚠️ Skipping poor accuracy update: ${position.accuracy}m');
      return;
    }

    syncService.updateLocation(
      lat: position.latitude,
      lng: position.longitude,
      userId: userId,
    );
  } else {
    debugPrint('⚠️ Location updated but no userId set for sync.');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
