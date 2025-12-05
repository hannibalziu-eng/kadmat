import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'offline_service.g.dart';

class OfflineService {
  final Connectivity _connectivity = Connectivity();
  final List<Future<void> Function()> _pendingActions = [];

  Stream<bool> get isOnline =>
      _connectivity.onConnectivityChanged.map((result) {
        return result.first != ConnectivityResult.none;
      });

  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result.first != ConnectivityResult.none;
  }

  void queueAction(Future<void> Function() action) {
    _pendingActions.add(action);
  }

  Future<void> syncPendingActions() async {
    if (await checkConnectivity()) {
      for (final action in _pendingActions) {
        try {
          await action();
        } catch (e) {
          print('Failed to sync action: $e');
        }
      }
      _pendingActions.clear();
    }
  }
}

@riverpod
OfflineService offlineService(OfflineServiceRef ref) {
  return OfflineService();
}

@riverpod
Stream<bool> isOnline(IsOnlineRef ref) {
  final service = ref.watch(offlineServiceProvider);
  return service.isOnline;
}
