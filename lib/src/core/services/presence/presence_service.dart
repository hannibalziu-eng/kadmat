import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserPresenceStatus { online, away, busy, dnd, offline }

enum ConnectionQuality { good, moderate, poor, offline }

class PresenceService {
  final SupabaseClient _client;
  RealtimeChannel? _channel;
  final StreamController<UserPresenceStatus> _statusController =
      StreamController.broadcast();

  final StreamController<ConnectionQuality> _qualityController =
      StreamController.broadcast();

  // Current local status
  UserPresenceStatus _currentStatus = UserPresenceStatus.offline;
  UserPresenceStatus get currentStatus => _currentStatus;

  ConnectionQuality _currentQuality = ConnectionQuality.good;
  ConnectionQuality get currentQuality => _currentQuality;

  StreamSubscription? _connectivitySubscription;
  Timer? _heartbeatTimer;
  String? _userId;

  PresenceService(this._client);

  Stream<UserPresenceStatus> get statusStream => _statusController.stream;
  Stream<ConnectionQuality> get qualityStream => _qualityController.stream;

  Future<void> initialize(String userId) async {
    _userId = userId;
    if (_channel != null) return;

    // Monitor Connectivity
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      _handleConnectivityChange(result, userId);
    });

    _channel = _client.channel(
      'online_users',
      opts: const RealtimeChannelConfig(self: true),
    );

    _channel?.onPresenceSync((payload) {
      debugPrint('🟢 Presence Sync: $payload');
    });

    _channel?.onPresenceJoin((payload) {
      debugPrint('👋 User Joined: ${payload.newPresences}');
    });

    _channel?.onPresenceLeave((payload) {
      debugPrint('👋 User Left: ${payload.leftPresences}');
    });

    _channel?.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await setStatus(_currentStatus, userId);
      } else if (status == RealtimeSubscribeStatus.closed) {
        _currentQuality = ConnectionQuality.offline;
        _qualityController.add(ConnectionQuality.offline);
        _stopHeartbeat();
      }
    });
  }

  void _handleConnectivityChange(
    List<ConnectivityResult> results,
    String userId,
  ) {
    final isOffline =
        results.contains(ConnectivityResult.none) && results.length == 1;

    if (isOffline) {
      _currentQuality = ConnectionQuality.offline;
      _qualityController.add(ConnectionQuality.offline);
      // Don't necessarily disconnect presence object, but mark status?
      // Actually if net is gone, socket is dead.
    } else {
      // Re-check quality
      // If we came back online and were supposed to be online, re-track
      if (_currentStatus == UserPresenceStatus.online && _channel != null) {
        // Give socket a moment to reconnect, then re-track
        Future.delayed(const Duration(seconds: 2), () {
          if (_currentStatus == UserPresenceStatus.online && _userId != null) {
            setStatus(UserPresenceStatus.online, _userId!);
          }
        });
      }
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      try {
        // Simple latency check: simple RPC or DB read
        // Or just check socket state
        // We can use a lightweight query
        // await _client.rpc('ping'); // requires RPC
        // fallback: just check connectivity type

        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity.contains(ConnectivityResult.mobile)) {
          // Mobile data often higher latency
          _currentQuality = ConnectionQuality.moderate;
        } else if (connectivity.contains(ConnectivityResult.wifi)) {
          _currentQuality = ConnectionQuality.good;
        } else {
          _currentQuality = ConnectionQuality.offline;
        }
        _qualityController.add(_currentQuality);
      } catch (e) {
        _currentQuality = ConnectionQuality.poor;
        _qualityController.add(ConnectionQuality.poor);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  Future<void> setStatus(UserPresenceStatus status, String userId) async {
    if (_channel == null) return;

    _currentStatus = status;
    _statusController.add(status);

    // Resume/Start heartbeat if online
    if (status == UserPresenceStatus.online) {
      _startHeartbeat();
    } else {
      _stopHeartbeat();
    }

    final payload = {
      'user_id': userId,
      'status': status.name,
      'last_seen': DateTime.now().toIso8601String(),
    };

    // 1. Send to Supabase Realtime Presence
    await _channel?.track(payload);

    // 2. Persist to Database
    //
    // Some production environments may not yet include the optional
    // presence columns (`status`, `last_seen`). In that case we still must
    // persist `is_online` so technician dispatch keeps working.
    try {
      await _client
          .from('users')
          .update({
            'is_online': status != UserPresenceStatus.offline,
            'status': status.name,
            'last_seen': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      debugPrint('⚠️ Failed full presence sync, trying is_online fallback: $e');
      try {
        await _client
            .from('users')
            .update({'is_online': status != UserPresenceStatus.offline})
            .eq('id', userId);
      } catch (fallbackError) {
        debugPrint('❌ Failed fallback is_online sync: $fallbackError');
      }
    }
  }

  Future<void> disconnect() async {
    _stopHeartbeat();
    _connectivitySubscription?.cancel();
    if (_channel != null) {
      await _channel?.untrack();
      await _client.removeChannel(_channel!);
      _channel = null;
    }
    _currentStatus = UserPresenceStatus.offline;
    _statusController.add(UserPresenceStatus.offline);
  }
}

final presenceServiceProvider = Provider<PresenceService>((ref) {
  return PresenceService(Supabase.instance.client);
});
