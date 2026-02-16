import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Position;

import '../../../../core/services/location/location_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../jobs/domain/job.dart';
import '../../../jobs/domain/job_visibility_policy.dart';
import '../../../jobs/presentation/job_controller.dart';

class TechnicianDispatchFeed {
  const TechnicianDispatchFeed({
    required this.location,
    required this.serviceId,
    required this.searchLat,
    required this.searchLng,
    required this.visibleJobs,
  });

  final Position location;
  final String? serviceId;
  final double searchLat;
  final double searchLng;
  final List<Job> visibleJobs;
}

double _normalizeCoordinate(double value) {
  return double.parse(value.toStringAsFixed(4));
}

/// Unified dispatch feed for technician nearby jobs.
/// This centralizes location + service filter + visibility policy so dashboard
/// and requests screens subscribe to the exact same data contract.
final technicianDispatchFeedProvider =
    Provider<AsyncValue<TechnicianDispatchFeed>>((ref) {
      final locationAsync = ref.watch(locationStreamProvider);
      final rawServiceId = ref
          .watch(authRepositoryProvider)
          .userProfile?['service_id'];
      final serviceId = rawServiceId?.toString();

      return locationAsync.when(
        loading: () => const AsyncValue<TechnicianDispatchFeed>.loading(),
        error: (error, stackTrace) =>
            AsyncValue<TechnicianDispatchFeed>.error(error, stackTrace),
        data: (location) {
          final searchLat = _normalizeCoordinate(location.latitude);
          final searchLng = _normalizeCoordinate(location.longitude);
          final jobsAsync = ref.watch(
            watchNearbyJobsStreamProvider(
              lat: searchLat,
              lng: searchLng,
              serviceId: serviceId,
            ),
          );

          return jobsAsync.whenData(
            (jobs) => TechnicianDispatchFeed(
              location: location,
              serviceId: serviceId,
              searchLat: searchLat,
              searchLng: searchLng,
              visibleJobs: JobVisibilityPolicy.filterForTechnicianQueue(jobs),
            ),
          );
        },
      );
    });
