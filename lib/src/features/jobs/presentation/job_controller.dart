import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';

import '../data/job_repository.dart';
import '../domain/job.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/exceptions/app_exceptions.dart';

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

  /// Accept a job - throws specific exceptions for better error handling
  Future<Job> acceptJob(String jobId) async {
    debugPrint('🟡 JobController.acceptJob: Starting for $jobId');
    try {
      debugPrint('🟡 JobController.acceptJob: Calling repository...');
      final result = await ref.read(jobRepositoryProvider).acceptJob(jobId);
      debugPrint('🟡 JobController.acceptJob: Success! Job ID: ${result.id}');
      return result;
    } catch (e) {
      debugPrint('🔴 JobController.acceptJob: Error: $e');
      // Re-throw specific exceptions as-is
      if (e is JobAlreadyAcceptedException ||
          e is InvalidStatusException ||
          e is TechnicianLockedException ||
          e is NetworkException ||
          e is JobNotFoundException) {
        rethrow;
      }
      // Handle DioException and convert to specific exceptions
      if (e is DioException) {
        if (e.response?.statusCode == 409) {
          throw JobAlreadyAcceptedException('تم قبول الطلب من فني آخر');
        }
        if (e.response?.statusCode == 400) {
          final errorCode = e.response?.data['error']?['code'];
          if (errorCode == 'INVALID_STATUS_TRANSITION') {
            final currentStatus = e.response?.data['error']?['currentStatus'];
            throw InvalidStatusException(
              'حالة الطلب غير صحيحة',
              currentStatus: currentStatus,
            );
          }
        }
        if (e.response?.statusCode == 404) {
          throw JobNotFoundException('لم يتم العثور على الطلب');
        }
      }
      // Re-throw as generic exception if not handled
      rethrow;
    }
  }

  Future<bool> completeJob(String jobId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(jobRepositoryProvider).requestJobCompletion(jobId),
    );
    return state.hasError == false;
  }
}

@riverpod
Future<List<Job>> myJobs(Ref ref) {
  return ref.watch(watchMyJobsRealtimeProvider.future);
}

@riverpod
Future<List<Job>> nearbyJobs(
  Ref ref, {
  required double lat,
  required double lng,
}) {
  return ref.watch(watchNearbyJobsStreamProvider(lat: lat, lng: lng).future);
}

// ========== REAL-TIME PROVIDERS ==========

/// Watch a job in real-time
/// Updates automatically when job status or data changes
// Watch single job in real-time
@riverpod
Stream<Job> watchJobRealtime(Ref ref, String jobId) {
  final repository = ref.watch(jobRepositoryProvider);
  return repository.watchJob(jobId);
}

// Watch technician lock status
@riverpod
Stream<bool> watchTechnicianLockStatus(Ref ref) {
  final repository = ref.watch(jobRepositoryProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null) {
    return Stream.value(false);
  }

  return repository.watchTechnicianLockStatus(userId);
}

// Watch all user's jobs
@riverpod
Stream<List<Job>> watchMyJobsRealtime(Ref ref) {
  final repository = ref.watch(jobRepositoryProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  final userType = ref.watch(authRepositoryProvider).userType;

  if (userId == null) {
    return Stream.value([]);
  }

  final isTechnician = userType == 'technician';
  return repository.watchMyJobs(userId, isTechnician: isTechnician);
}

@riverpod
Stream<List<Job>> watchNearbyJobsStream(
  Ref ref, {
  required double lat,
  required double lng,
  String? serviceId,
}) {
  // Delegate to repository's Realtime implementation (Reactive Refetch pattern)
  // This listens to Supabase changes and refetches via RPC for accurate filtering
  return ref
      .watch(jobRepositoryProvider)
      .watchNearbyJobs(lat: lat, lng: lng, serviceId: serviceId);
}
