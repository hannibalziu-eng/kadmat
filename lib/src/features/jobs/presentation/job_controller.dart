import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/job_repository.dart';
import '../domain/job.dart';

part 'job_controller.g.dart';

@riverpod
class JobController extends _$JobController {
  @override
  FutureOr<void> build() {
    // nothing
  }

  Future<Job?> createJob({
    required String serviceId,
    required double lat,
    required double lng,
    required String addressText,
    required double initialPrice,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .createJob(
            serviceId: serviceId,
            lat: lat,
            lng: lng,
            addressText: addressText,
            initialPrice: initialPrice,
            description: description,
          );
      state = const AsyncValue.data(null);
      return job;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  /// Accept a job - this is a side-effect operation, no state changes needed
  Future<bool> acceptJob(String jobId) async {
    debugPrint('🟡 JobController.acceptJob: Starting for $jobId');
    try {
      debugPrint('🟡 JobController.acceptJob: Calling repository...');
      final result = await ref.read(jobRepositoryProvider).acceptJob(jobId);
      debugPrint('🟡 JobController.acceptJob: Success! Job ID: ${result.id}');
      return true;
    } catch (e) {
      debugPrint('🔴 JobController.acceptJob: Error: $e');
      return false;
    }
  }

  Future<bool> completeJob(String jobId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(jobRepositoryProvider).completeJob(jobId),
    );
    return state.hasError == false;
  }
}

@riverpod
Future<List<Job>> myJobs(MyJobsRef ref) {
  return ref.watch(jobRepositoryProvider).getMyJobs();
}

@riverpod
Future<List<Job>> nearbyJobs(
  NearbyJobsRef ref, {
  required double lat,
  required double lng,
}) {
  return ref.watch(jobRepositoryProvider).getNearbyJobs(lat: lat, lng: lng);
}

@riverpod
Stream<Job> watchJob(WatchJobRef ref, String jobId) {
  return ref.watch(jobRepositoryProvider).watchJob(jobId);
}

@riverpod
Stream<List<Job>> watchNearbyJobsStream(
  WatchNearbyJobsStreamRef ref, {
  required double lat,
  required double lng,
  String? serviceId,
}) {
  return ref
      .watch(jobRepositoryProvider)
      .watchNearbyJobs(lat: lat, lng: lng, serviceId: serviceId);
}
