import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../api/api_client.dart';
import 'pending_request.dart';

part 'work_queue_service.g.dart';

@Riverpod(keepAlive: true)
WorkQueueService workQueueService(Ref ref) {
  final apiClient = ref.watch(apiClientProvider);
  final service = WorkQueueService(apiClient);
  ref.onDispose(service.dispose);
  return service;
}

class WorkQueueService {
  final Dio _apiClient;
  late Box<PendingRequest> _queueBox;
  final _uuid = const Uuid();
  bool _isSyncing = false;
  late final Future<void> _ready;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  WorkQueueService(this._apiClient) {
    _ready = _init();
  }

  Future<void> _init() async {
    // Register adapter should be done in main.dart usually,
    // but ensuring box is open here.
    if (!Hive.isBoxOpen('work_queue_v1')) {
      _queueBox = await Hive.openBox<PendingRequest>('work_queue_v1');
    } else {
      _queueBox = Hive.box<PendingRequest>('work_queue_v1');
    }

    // Listen to meaningful connectivity changes
    // Only trigger on connectivity GAINED, not every change
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        syncPendingRequests();
      }
    });

    // Initial sync attempt
    syncPendingRequests();
  }

  /// Add a request to the local queue when offline or failed
  Future<void> queueRequest({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    await _ready;

    final request = PendingRequest(
      id: _uuid.v4(),
      endpoint: endpoint,
      method: method,
      payload: payload,
      createdAt: DateTime.now(),
    );

    await _queueBox.put(request.id, request);
    debugPrint(
      '📦 [WorkQueue] Request queued: ${request.id} ($method $endpoint)',
    );

    // Try to sync immediately if we might have connection
    syncPendingRequests();
  }

  /// Process the queue
  Future<void> syncPendingRequests() async {
    await _ready;

    if (_isSyncing) return;
    if (_queueBox.isEmpty) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none) &&
        connectivityResult.length == 1) {
      debugPrint('🚫 [WorkQueue] No internet, skipping sync');
      return;
    }

    _isSyncing = true;
    debugPrint('🔄 [WorkQueue] Syncing ${_queueBox.length} requests...');

    final requests = _queueBox.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // FIFO

    for (final request in requests) {
      try {
        debugPrint(
          '🚀 [WorkQueue] Processing: ${request.id} (${request.retryCount}/3)',
        );
        await _executeRequest(request);

        // Success: Remove from queue
        await request.delete();
        debugPrint('✅ [WorkQueue] Request synced: ${request.id}');
      } catch (e) {
        debugPrint('❌ [WorkQueue] Sync failed for ${request.id}: $e');

        // Retry logic
        if (request.retryCount < 3) {
          request.retryCount++;
          await request.save();
        } else {
          // Give up after 3 retries to prevent blocking
          // In a real app, maybe move to "failed_requests" box for manual review
          await request.delete();
          debugPrint('💀 [WorkQueue] Request dead-lettered: ${request.id}');
        }
      }
    }

    _isSyncing = false;
  }

  Future<Response> _executeRequest(PendingRequest request) async {
    switch (request.method.toUpperCase()) {
      case 'POST':
        return _apiClient.post(request.endpoint, data: request.payload);
      case 'PUT':
        return _apiClient.put(request.endpoint, data: request.payload);
      case 'PATCH':
        return _apiClient.patch(request.endpoint, data: request.payload);
      case 'DELETE':
        return _apiClient.delete(request.endpoint, data: request.payload);
      default:
        throw Exception('Unknown method: ${request.method}');
    }
  }

  // Expose queue length for UI indicators
  int get queueLength => _queueBox.length;

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
