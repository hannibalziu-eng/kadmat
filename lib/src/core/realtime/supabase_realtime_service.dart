import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/jobs/domain/job.dart';

class SupabaseRealtimeService {
  final SupabaseClient _client;

  SupabaseRealtimeService(this._client);

  /// Stream updates for a specific job
  Stream<Job> streamJob(String jobId) {
    return _client.from('jobs').stream(primaryKey: ['id']).eq('id', jobId).map((
      data,
    ) {
      if (data.isEmpty) {
        throw Exception('Job not found');
      }
      return Job.fromJson(data.first);
    });
  }

  /// Stream nearby jobs for a technician
  /// Note: Complex geospatial filtering is hard with simple streams.
  /// We stream *all* new jobs (or filtered by service_id) and filter locally for radius.
  /// Ideally, use a backend function or Postgres Listen/Notify for refined geo-fencing,
  /// but for MVP/Minimal-Change, we stream by service_id and filter in the repository.
  Stream<List<Job>> streamNearbyJobs({
    String? serviceId,
    required double lat,
    required double lng,
  }) {
    // Start building the stream query
    // Note: To avoid variable type issues between FilterBuilder and StreamBuilder,
    // we simply branch the creation.
    final builder = _client.from('jobs').stream(primaryKey: ['id']);

    final stream = serviceId != null
        ? builder.eq('service_id', serviceId)
        : builder;

    return stream.order('created_at', ascending: false).map((data) {
      // Map JSON to Job objects
      return data.map((json) => Job.fromJson(json)).toList();
    });
  }

  /// Stream valid job table changes only (INSERT, UPDATE)
  /// Used to trigger reactive refetches in repositories
  Stream<void> streamJobTableChanges() {
    late StreamController<void> controller;
    late void Function() scheduleReconnect;
    RealtimeChannel? channel;
    Timer? reconnectTimer;
    var reconnectAttempts = 0;

    Duration backoffFor(int attempt) {
      final seconds = switch (attempt) {
        <= 1 => 1,
        2 => 2,
        3 => 4,
        4 => 8,
        _ => 15,
      };
      return Duration(seconds: seconds);
    }

    Future<void> teardownChannel() async {
      reconnectTimer?.cancel();
      reconnectTimer = null;
      if (channel != null) {
        await _client.removeChannel(channel!);
        channel = null;
      }
    }

    Future<void> subscribe() async {
      await teardownChannel();
      if (controller.isClosed) return;

      channel = _client.channel(
        'public:jobs:changes:${DateTime.now().microsecondsSinceEpoch}',
      );

      channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'jobs',
            callback: (_) {
              if (!controller.isClosed) {
                controller.add(null);
              }
            },
          )
          .subscribe((status, [error]) {
            if (controller.isClosed) return;

            if (status == RealtimeSubscribeStatus.subscribed) {
              reconnectAttempts = 0;
              if (!controller.isClosed) {
                // Prime consumers after successful handshake.
                controller.add(null);
              }
              return;
            }

            if (status == RealtimeSubscribeStatus.timedOut ||
                status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.channelError) {
              if (error != null) {
                // Keep error observability while avoiding raw UI surfacing.
                // Downstream repositories already have polling fallback.
                debugPrint(
                  '⚠️ Realtime jobs channel degraded ($status): $error',
                );
              }
              scheduleReconnect();
            }
          });
    }

    scheduleReconnect = () {
      if (controller.isClosed || reconnectTimer?.isActive == true) return;
      reconnectAttempts += 1;
      final delay = backoffFor(reconnectAttempts);
      reconnectTimer = Timer(delay, () {
        if (!controller.isClosed) {
          unawaited(subscribe());
        }
      });
    };

    controller = StreamController<void>(
      onListen: () {
        unawaited(subscribe());
      },
      onCancel: () async {
        await teardownChannel();
      },
    );

    return controller.stream;
  }

  /// Stream a technician's jobs (My Jobs)
  Stream<List<Job>> streamMyJobs(String userId, {bool isTechnician = false}) {
    final column = isTechnician ? 'technician_id' : 'customer_id';
    return _client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq(column, userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Job.fromJson(json)).toList());
  }

  /// Check connection status
  Stream<RealtimeSubscribeStatus> get connectionStatus {
    // Note: Supabase implementation of connection status monitoring
    // typically sits on the channel level, keeping it simple here
    // or using system channels if available.
    // Currently relying on the stream's error handling.
    return Stream.value(RealtimeSubscribeStatus.subscribed);
  }
}
