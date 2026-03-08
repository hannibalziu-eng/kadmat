import 'job.dart';
import 'job_status.dart';

class JobCommunicationPolicy {
  JobCommunicationPolicy._();

  static const Set<String> _eligibleStatuses = {
    JobStatus.accepted,
    JobStatus.pricePending,
    JobStatus.onTheWay,
    JobStatus.arrived,
    JobStatus.inProgress,
    JobStatus.pendingConfirm,
    JobStatus.completed,
    JobStatus.rated,
  };

  static bool canUseJobCommunication(Job? job) {
    if (job == null) return false;
    return canUseJobCommunicationSnapshot(
      status: job.status,
      acceptedBidId: job.acceptedBidId,
    );
  }

  static bool canUseJobCommunicationSnapshot({
    required String status,
    String? acceptedBidId,
  }) {
    final normalizedStatus = JobStatus.normalize(status);
    if (normalizedStatus == JobStatus.pending ||
        normalizedStatus == JobStatus.searching ||
        normalizedStatus == JobStatus.noTechnicianFound ||
        normalizedStatus == JobStatus.cancelled) {
      return false;
    }

    if (_eligibleStatuses.contains(normalizedStatus)) {
      return true;
    }

    return acceptedBidId != null && acceptedBidId.trim().isNotEmpty;
  }

  static const String unavailableMessage = 'يتاح التواصل فقط بعد قبول العرض';
}
