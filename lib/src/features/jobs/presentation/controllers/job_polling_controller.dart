import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';

part 'job_polling_controller.g.dart';

/// Controller for polling job status with lifecycle awareness
class JobPollingController with WidgetsBindingObserver {
  final Ref ref;
  final String jobId;
  final Duration interval;
  final void Function(Job job)? onStatusChange;
  final void Function(String error)? onError;

  Timer? _timer;
  String? _lastStatus;
  bool _isActive = true;

  JobPollingController({
    required this.ref,
    required this.jobId,
    this.interval = const Duration(seconds: 5),
    this.onStatusChange,
    this.onError,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  void _startPolling() {
    _fetchJob(); // Immediate first fetch
    _timer = Timer.periodic(interval, (_) => _fetchJob());
  }

  Future<void> _fetchJob() async {
    if (!_isActive) return;

    try {
      final job = await ref.read(jobRepositoryProvider).getJobById(jobId);

      if (job != null && job.status != _lastStatus) {
        _lastStatus = job.status;
        onStatusChange?.call(job);
      }
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _isActive = false;
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _isActive = true;
      _startPolling();
    }
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// Riverpod provider for job polling with auto-refresh
@riverpod
class JobPoller extends _$JobPoller {
  Timer? _timer;

  @override
  FutureOr<Job?> build(String jobId) async {
    // Cancel timer on dispose
    ref.onDispose(() => _timer?.cancel());

    // Start polling
    _startPolling(jobId);

    // Initial fetch
    return _fetchJob(jobId);
  }

  void _startPolling(String jobId) {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      state = AsyncData(await _fetchJob(jobId));
    });
  }

  Future<Job?> _fetchJob(String jobId) async {
    try {
      return await ref.read(jobRepositoryProvider).getJobById(jobId);
    } catch (e) {
      return null;
    }
  }

  /// Force refresh the job
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchJob(arg));
  }

  /// Stop polling (call when navigating away)
  void stopPolling() {
    _timer?.cancel();
  }
}

/// Simple stream-based job watcher provider
@riverpod
Stream<Job?> jobStream(Ref ref, String jobId) {
  return ref.read(jobRepositoryProvider).watchJob(jobId);
}
