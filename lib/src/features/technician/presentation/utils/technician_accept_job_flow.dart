import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/router_modular.dart';
import '../../../../core/utils/logger_service.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../jobs/data/job_repository.dart';
import '../../../jobs/presentation/job_controller.dart';
import '../providers/technician_providers.dart';

class TechnicianAcceptJobFlow {
  const TechnicianAcceptJobFlow._();

  static Future<bool> run({
    required BuildContext context,
    required WidgetRef ref,
    required String jobId,
  }) async {
    final startedAt = DateTime.now();
    try {
      final acceptedJob = await ref
          .read(jobControllerProvider.notifier)
          .acceptJob(jobId);
      _logAcceptTelemetry(
        outcome: 'accepted',
        jobId: jobId,
        waitSeconds: DateTime.now().difference(acceptedJob.createdAt).inSeconds,
        flowLatencyMs: DateTime.now().difference(startedAt).inMilliseconds,
      );
      _invalidateAfterAccept(ref);
      _navigateToBidding(ref, jobId);
      return true;
    } catch (error) {
      final recovered = await _tryIdempotentRecovery(ref: ref, jobId: jobId);
      if (recovered) {
        final recoveredJob = await ref
            .read(jobRepositoryProvider)
            .getJob(jobId);
        final recoveredWaitSeconds = recoveredJob == null
            ? null
            : DateTime.now().difference(recoveredJob.createdAt).inSeconds;
        _logAcceptTelemetry(
          outcome: 'idempotent_recovery',
          jobId: jobId,
          waitSeconds: recoveredWaitSeconds,
          flowLatencyMs: DateTime.now().difference(startedAt).inMilliseconds,
        );
        _invalidateAfterAccept(ref);
        _navigateToBidding(ref, jobId);
        return true;
      }

      _logAcceptTelemetry(
        outcome: 'failed',
        jobId: jobId,
        flowLatencyMs: DateTime.now().difference(startedAt).inMilliseconds,
        errorType: error.runtimeType.toString(),
      );
      if (!context.mounted) return false;
      _showErrorToast(context: context, error: error);
      return false;
    }
  }

  static void _invalidateAfterAccept(WidgetRef ref) {
    ref.invalidate(myJobsProvider);

    final currentLocation = ref.read(technicianLocationProvider);
    final rawServiceId = ref
        .read(authRepositoryProvider)
        .userProfile?['service_id'];
    final serviceId = rawServiceId?.toString();

    if (currentLocation != null) {
      ref.invalidate(
        watchNearbyJobsStreamProvider(
          lat: currentLocation.latitude,
          lng: currentLocation.longitude,
          serviceId: serviceId,
        ),
      );
      return;
    }

    ref.invalidate(watchNearbyJobsStreamProvider);
  }

  static void _navigateToBidding(WidgetRef ref, String jobId) {
    LoggerService.i('dispatch.telemetry navigate_to_bidding job_id=$jobId');
    ref
        .read(goRouterProvider)
        .push(AppRoutes.buildTechnicianBiddingPath(jobId));
  }

  static void _logAcceptTelemetry({
    required String outcome,
    required String jobId,
    int? waitSeconds,
    int? flowLatencyMs,
    String? errorType,
  }) {
    LoggerService.i(
      'dispatch.telemetry accept_job '
      'outcome=$outcome '
      'job_id=$jobId '
      'wait_seconds=${waitSeconds ?? -1} '
      'flow_latency_ms=${flowLatencyMs ?? -1} '
      'error_type=${errorType ?? 'none'}',
    );
  }

  static Future<bool> _tryIdempotentRecovery({
    required WidgetRef ref,
    required String jobId,
  }) async {
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    if (currentUser == null || currentUser.isEmpty) return false;

    try {
      final freshJob = await ref.read(jobRepositoryProvider).getJob(jobId);
      return freshJob != null && freshJob.technicianId == currentUser;
    } catch (_) {
      return false;
    }
  }

  static void _showErrorToast({
    required BuildContext context,
    required Object error,
  }) {
    if (error is JobAlreadyAcceptedException) {
      KadmatToast.showError(
        context,
        title: 'تم قبول الطلب',
        message: error.message,
      );
      return;
    }

    if (error is TechnicianLockedException) {
      KadmatToast.showWarning(
        context,
        title: 'طلب قيد التنفيذ',
        message: error.message,
      );
      return;
    }

    if (error is InvalidStatusException) {
      KadmatToast.showError(
        context,
        title: 'حالة غير صحيحة',
        message: error.message,
      );
      return;
    }

    if (error is NetworkException) {
      KadmatToast.showError(
        context,
        title: 'خطأ في الاتصال',
        message: error.message,
      );
      return;
    }

    if (error is JobNotFoundException) {
      KadmatToast.showError(
        context,
        title: 'الطلب غير موجود',
        message: error.message,
      );
      return;
    }

    if (error is OfflineRequestQueuedException) {
      KadmatToast.showInfo(
        context,
        title: 'تم حفظ الطلب',
        message: error.message,
      );
      return;
    }

    KadmatToast.showError(
      context,
      title: 'فشل قبول الطلب',
      message: 'حدث خطأ أثناء قبول الطلب. يرجى المحاولة مرة أخرى.',
    );
  }
}
