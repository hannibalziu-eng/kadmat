import '../../features/jobs/domain/job_status.dart';
import 'app_routes.dart';

/// Maps job status to customer flow route.
/// Returns null when no redirection is needed for the current status.
String? customerRouteForJobStatus({
  required String status,
  required String jobId,
}) {
  final normalized = JobStatus.normalize(status);

  switch (normalized) {
    case JobStatus.accepted:
    case JobStatus.pricePending:
      return AppRoutes.buildCustomerTechnicianFoundPath(jobId);
    case JobStatus.onTheWay:
    case JobStatus.arrived:
    case JobStatus.inProgress:
      return AppRoutes.buildCustomerInProgressPath(jobId);
    case JobStatus.pendingConfirm:
      return AppRoutes.buildCustomerConfirmCompletionPath(jobId);
    case JobStatus.completed:
      return AppRoutes.buildCustomerRatePath(jobId);
    case JobStatus.rated:
      return AppRoutes.buildCustomerCompletedPath(jobId);
    default:
      return null;
  }
}

/// Maps job status to technician flow route.
/// Returns null when no redirection is needed for the current status.
String? technicianRouteForJobStatus({
  required String status,
  required String jobId,
}) {
  final normalized = JobStatus.normalize(status);

  switch (normalized) {
    case JobStatus.accepted:
    case JobStatus.pricePending:
      return AppRoutes.buildTechnicianSetPricePath(jobId);
    case JobStatus.onTheWay:
    case JobStatus.arrived:
    case JobStatus.inProgress:
    case JobStatus.pendingConfirm:
    case JobStatus.completed:
    case JobStatus.rated:
      return AppRoutes.buildTechnicianJobDetailPath(jobId);
    default:
      return null;
  }
}
