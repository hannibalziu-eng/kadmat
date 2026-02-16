import 'job.dart';
import 'job_status.dart';

/// Central policy for technician "new requests" visibility.
/// Keeping this logic in one place avoids filter drift across layers.
class JobVisibilityPolicy {
  static const Duration pendingAndSearchingMaxAge = Duration(hours: 24);
  static const Duration noTechnicianFoundMaxAge = Duration(hours: 2);

  static bool isVisibleForTechnicianQueue(Job job, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final normalized = JobStatus.normalize(job.status);

    final visibleStatuses = <String>{
      JobStatus.pending,
      JobStatus.searching,
      JobStatus.noTechnicianFound,
    };

    if (!visibleStatuses.contains(normalized)) return false;

    final isUnassigned = job.technicianId == null || job.technicianId!.isEmpty;
    if (!isUnassigned) return false;

    final age = currentTime.difference(job.createdAt);
    if (normalized == JobStatus.noTechnicianFound) {
      return age <= noTechnicianFoundMaxAge;
    }

    return age <= pendingAndSearchingMaxAge;
  }

  static List<Job> filterForTechnicianQueue(
    Iterable<Job> jobs, {
    DateTime? now,
  }) {
    final visible =
        jobs.where((job) => isVisibleForTechnicianQueue(job, now: now)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return dedupeMostRecentByCustomerAndService(visible);
  }

  /// Keep only the newest open request per (customer, service) pair.
  /// This prevents legacy duplicate requests from flooding technician queues.
  static List<Job> dedupeMostRecentByCustomerAndService(List<Job> jobs) {
    final latestByKey = <String, Job>{};
    for (final job in jobs) {
      final key = '${job.customerId}|${job.serviceId}';
      final existing = latestByKey[key];
      if (existing == null || job.createdAt.isAfter(existing.createdAt)) {
        latestByKey[key] = job;
      }
    }

    final deduped = latestByKey.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deduped;
  }
}
