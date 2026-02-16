import 'dart:math' as math;

import '../../../jobs/domain/job.dart';
import '../../../jobs/domain/job_status.dart';

enum TechnicianDispatchSortMode { newest, closest, oldestWaiting }

class TechnicianGeoPoint {
  final double lat;
  final double lng;

  const TechnicianGeoPoint({required this.lat, required this.lng});
}

class TechnicianDispatchQueue {
  static const Duration _pendingMaxAge = Duration(hours: 24);
  static const Duration _noTechnicianMaxAge = Duration(hours: 2);
  static const Duration _urgentThreshold = Duration(minutes: 15);

  static bool isUrgentJob(Job job, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final age = current.difference(job.createdAt);
    final normalized = JobStatus.normalize(job.status);
    if (normalized == JobStatus.noTechnicianFound) {
      return true;
    }
    return age >= _urgentThreshold;
  }

  static bool isExpiredQueueJob(Job job, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final age = current.difference(job.createdAt);
    final normalized = JobStatus.normalize(job.status);

    if ((normalized == JobStatus.pending ||
            normalized == JobStatus.searching) &&
        age > _pendingMaxAge) {
      return true;
    }
    if (normalized == JobStatus.noTechnicianFound &&
        age > _noTechnicianMaxAge) {
      return true;
    }
    return false;
  }

  static List<Job> prepareJobs({
    required List<Job> jobs,
    required TechnicianDispatchSortMode sortMode,
    required bool urgentOnly,
    TechnicianGeoPoint? technicianLocation,
    DateTime? now,
  }) {
    var queue = jobs.where((job) => !isExpiredQueueJob(job, now: now)).toList();
    if (urgentOnly) {
      queue = queue.where((job) => isUrgentJob(job, now: now)).toList();
    }

    queue.sort((a, b) {
      switch (sortMode) {
        case TechnicianDispatchSortMode.newest:
          return b.createdAt.compareTo(a.createdAt);
        case TechnicianDispatchSortMode.oldestWaiting:
          return a.createdAt.compareTo(b.createdAt);
        case TechnicianDispatchSortMode.closest:
          if (technicianLocation == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          final aDistance = distanceToJobMeters(
            job: a,
            technicianLocation: technicianLocation,
          );
          final bDistance = distanceToJobMeters(
            job: b,
            technicianLocation: technicianLocation,
          );
          return aDistance.compareTo(bDistance);
      }
    });

    return queue;
  }

  static Job? pickPriorityJob({
    required List<Job> jobs,
    TechnicianGeoPoint? technicianLocation,
    DateTime? now,
  }) {
    if (jobs.isEmpty) return null;
    final ranked = [...jobs]
      ..sort(
        (a, b) =>
            priorityScore(
              b,
              technicianLocation: technicianLocation,
              now: now,
            ).compareTo(
              priorityScore(
                a,
                technicianLocation: technicianLocation,
                now: now,
              ),
            ),
      );
    return ranked.first;
  }

  static double priorityScore(
    Job job, {
    TechnicianGeoPoint? technicianLocation,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final ageMinutes = current
        .difference(job.createdAt)
        .inMinutes
        .clamp(0, 180)
        .toDouble();
    final urgentBoost = isUrgentJob(job, now: current) ? 45.0 : 0.0;
    final normalized = JobStatus.normalize(job.status);
    final noTechnicianBoost = normalized == JobStatus.noTechnicianFound
        ? 30.0
        : 0.0;

    double distanceBoost = 0.0;
    if (technicianLocation != null) {
      final distanceKm =
          distanceToJobMeters(
            job: job,
            technicianLocation: technicianLocation,
          ) /
          1000;
      distanceBoost = (20 - distanceKm).clamp(0, 20).toDouble();
    }

    return (ageMinutes * 1.2) + urgentBoost + noTechnicianBoost + distanceBoost;
  }

  static double distanceToJobMeters({
    required Job job,
    required TechnicianGeoPoint technicianLocation,
  }) {
    return distanceBetweenPointsMeters(
      from: technicianLocation,
      to: TechnicianGeoPoint(lat: job.lat, lng: job.lng),
    );
  }

  static double distanceBetweenPointsMeters({
    required TechnicianGeoPoint from,
    required TechnicianGeoPoint to,
  }) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(to.lat - from.lat);
    final dLng = _degToRad(to.lng - from.lng);
    final lat1 = _degToRad(from.lat);
    final lat2 = _degToRad(to.lat);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static String waitingLabel(DateTime createdAt, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final diff = current.difference(createdAt);
    if (diff.inMinutes < 1) return 'أقل من دقيقة';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
