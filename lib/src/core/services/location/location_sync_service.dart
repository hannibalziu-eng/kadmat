import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants.dart';

class LocationSyncService {
  static const String _boxName = 'location_queue';
  static const Duration _missingRpcCooldown = Duration(minutes: 3);
  Box? _queueBox;
  bool _isInitializing = false;
  DateTime? _missingRpcCooldownUntil;
  bool _missingRpcWarningShown = false;

  // Singleton for within the isolate
  static final LocationSyncService _instance = LocationSyncService._internal();
  factory LocationSyncService() => _instance;
  LocationSyncService._internal();

  /// Initialize Hive and Supabase (if needed)
  /// Must be called once when the background isolate starts
  Future<void> initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      // Initialize Supabase if not already (check current client)
      try {
        Supabase.instance.client;
      } catch (_) {
        debugPrint('🌍 Initializing Supabase in Background Isolate...');
        await Supabase.initialize(
          url: AppConstants.supabaseUrl,
          anonKey: AppConstants.supabaseAnonKey,
        );
      }

      // Initialize Hive
      await Hive.initFlutter();
      if (!Hive.isBoxOpen(_boxName)) {
        _queueBox = await Hive.openBox(_boxName);
      } else {
        _queueBox = Hive.box(_boxName);
      }
      debugPrint(
        '📦 LocationQueue initialized. Pending items: ${_queueBox?.length}',
      );
    } catch (e) {
      debugPrint('❌ Failed to initialize LocationSyncService: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Update location to Supabase or queue if offline
  Future<void> updateLocation({
    required double lat,
    required double lng,
    required String userId,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.contains(ConnectivityResult.mobile) ||
        connectivity.contains(ConnectivityResult.wifi);

    final payload = {
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': userId,
    };

    if (isOnline) {
      if (_isMissingRpcCooldownActive()) {
        await _queueLatestForUser(payload);
        return;
      }

      try {
        await _sendToSupabase(lat, lng, userId);

        // If successful, try to flush queue
        if ((_queueBox?.length ?? 0) > 0) {
          _flushQueue();
        }
      } catch (e) {
        if (_isMissingUpdateLocationRpcError(e)) {
          _activateMissingRpcCooldown();
          await _queueLatestForUser(payload);
          return;
        }
        debugPrint('⚠️ Sync failed, queuing: $e');
        await _queue(payload);
      }
    } else {
      await _queue(payload);
    }
  }

  Future<void> _sendToSupabase(double lat, double lng, String userId) async {
    // Use RPC for atomic update or direct upsert
    // Assuming we have a user_locations table or similar
    // Or updating a column on profiles/technicians

    // Using PostGIS RPC is best practice: update_technician_location

    await Supabase.instance.client.rpc(
      'update_user_location',
      params: {'p_user_id': userId, 'p_lat': lat, 'p_lng': lng},
    );

    debugPrint('✅ Location synced: $lat, $lng');
  }

  Future<void> _queue(Map<String, dynamic> data) async {
    await _queueBox?.add(data);
    debugPrint('📥 Location queued. Total: ${_queueBox?.length}');
  }

  Future<void> _queueLatestForUser(Map<String, dynamic> data) async {
    final userId = data['user_id'];
    if (userId == null || _queueBox == null) {
      await _queue(data);
      return;
    }

    dynamic existingKey;
    final queueMap = _queueBox!.toMap();
    for (final entry in queueMap.entries) {
      final value = entry.value;
      if (value is Map && value['user_id'] == userId) {
        existingKey = entry.key;
      }
    }

    if (existingKey != null) {
      await _queueBox!.put(existingKey, data);
    } else {
      await _queueBox!.add(data);
    }
    debugPrint('📥 Location queued (latest-only). Total: ${_queueBox?.length}');
  }

  bool _isMissingUpdateLocationRpcError(Object error) {
    final raw = error.toString();
    return raw.contains('PGRST202') && raw.contains('update_user_location');
  }

  bool _isMissingRpcCooldownActive() {
    final until = _missingRpcCooldownUntil;
    if (until == null) return false;
    final active = DateTime.now().isBefore(until);
    if (!active) {
      _missingRpcCooldownUntil = null;
      _missingRpcWarningShown = false;
    }
    return active;
  }

  void _activateMissingRpcCooldown() {
    _missingRpcCooldownUntil = DateTime.now().add(_missingRpcCooldown);
    if (_missingRpcWarningShown) return;
    _missingRpcWarningShown = true;
    debugPrint(
      '⚠️ update_user_location RPC غير متوفر. تم تفعيل تباطؤ مؤقت للمزامنة لمنع تضخم الطابور.',
    );
  }

  Future<void> _flushQueue() async {
    if (_queueBox == null || _queueBox!.isEmpty) return;

    debugPrint('🔄 Flushing ${_queueBox!.length} location updates...');

    // Process usually LIFO or FIFO?
    // Usually we just care about the LATEST one for live tracking,
    // but maybe needed for history.
    // Let's iterate and send.

    final keysToDelete = <dynamic>[];

    // Map keys to map to allow safe deletion
    final Map<dynamic, dynamic> queueMap = _queueBox!.toMap();

    for (final entry in queueMap.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val is Map) {
        try {
          final userId =
              val['user_id']; // This might be tricky if user changed, but unlikely in session
          // Actually, we should probably batch these or just send latest?
          // Sending historical points might overload connection.
          // For now, let's just send them one by one.

          await _sendToSupabase(val['lat'], val['lng'], userId);
          keysToDelete.add(key);
        } catch (e) {
          debugPrint('❌ Flush error for $key: $e');
          // Stop flushing on error to preserve order/connectivity issue
          break;
        }
      }
    }

    await _queueBox!.deleteAll(keysToDelete);
    debugPrint('✅ Flushed ${keysToDelete.length} items.');
  }
}
