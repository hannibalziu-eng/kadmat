import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants.dart';

class LocationSyncService {
  static const String _boxName = 'location_queue';
  Box? _queueBox;
  bool _isInitializing = false;

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
      try {
        await _sendToSupabase(lat, lng, userId);

        // If successful, try to flush queue
        if ((_queueBox?.length ?? 0) > 0) {
          _flushQueue();
        }
      } catch (e) {
        debugPrint('⚠️ Sync failed, queuing: $e');
        _queue(payload);
      }
    } else {
      _queue(payload);
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

  void _queue(Map<String, dynamic> data) {
    _queueBox?.add(data);
    debugPrint('📥 Location queued. Total: ${_queueBox?.length}');
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
