import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kadmat/src/core/services/location/location_service.dart';
import 'package:kadmat/src/features/jobs/domain/job.dart';
import 'package:kadmat/src/features/jobs/presentation/job_controller.dart';
import 'package:kadmat/src/features/technician/data/technician_repository.dart';
import 'package:kadmat/src/features/technician/domain/technician_status.dart';
import 'dart:math' as math;

/// Provider for technician's current location
final technicianLocationProvider = StateProvider<Position?>((ref) {
  // Initialize from location service
  final locationAsync = ref.watch(locationStreamProvider);
  return locationAsync.valueOrNull;
});

/// Provider for technician online status
final technicianOnlineStatusProvider =
    StateNotifierProvider<TechnicianOnlineNotifier, TechnicianStatus>((ref) {
      return TechnicianOnlineNotifier(ref);
    });

class TechnicianOnlineNotifier extends StateNotifier<TechnicianStatus> {
  final Ref _ref;

  TechnicianOnlineNotifier(this._ref) : super(TechnicianStatus.online);

  Future<void> setStatus(TechnicianStatus status) async {
    state = status;

    // Update in database
    try {
      final repository = _ref.read(technicianRepositoryProvider);
      await repository.toggleStatus(status.isAvailable);
    } catch (e) {
      // Revert on error
      state = status == TechnicianStatus.online
          ? TechnicianStatus.offline
          : TechnicianStatus.online;
      rethrow;
    }
  }

  Future<void> toggle() async {
    final newStatus = state == TechnicianStatus.online
        ? TechnicianStatus.offline
        : TechnicianStatus.online;
    await setStatus(newStatus);
  }
}

/// Provider for nearby jobs with calculated distance
final nearbyJobsWithDistanceProvider =
    Provider<AsyncValue<List<JobWithDistance>>>((ref) {
      final location = ref.watch(technicianLocationProvider);

      if (location == null) {
        return const AsyncValue.loading();
      }

      final jobsAsync = ref.watch(
        watchNearbyJobsStreamProvider(
          lat: location.latitude,
          lng: location.longitude,
        ),
      );

      return jobsAsync.whenData((jobs) {
        return jobs.map((job) {
          final distance = _calculateDistance(
            location.latitude,
            location.longitude,
            job.lat,
            job.lng,
          );
          return JobWithDistance(job: job, distanceKm: distance);
        }).toList()..sort(
          (a, b) => a.distanceKm.compareTo(b.distanceKm),
        ); // Sort by distance
      });
    });

/// Helper class to combine Job with calculated distance
class JobWithDistance {
  final Job job;
  final double distanceKm;

  JobWithDistance({required this.job, required this.distanceKm});

  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} م';
    }
    return '${distanceKm.toStringAsFixed(1)} كم';
  }
}

/// Calculate distance between two points using Haversine formula
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371; // Earth radius in km

  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);

  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180;
