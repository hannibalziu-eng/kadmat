import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tracking_repository.g.dart';

class TrackingRepository {
  // Simulate provider movement
  Stream<LatLng> trackProvider(String bookingId) {
    // Starting point (Tripoli, Libya approx)
    double lat = 32.8872;
    double lng = 13.1913;

    return Stream.periodic(const Duration(seconds: 2), (count) {
      // Move slightly
      lat += 0.0001 * (count % 2 == 0 ? 1 : -1);
      lng += 0.0001;
      return LatLng(lat, lng);
    }).take(100);
  }
}

@riverpod
TrackingRepository trackingRepository(TrackingRepositoryRef ref) {
  return TrackingRepository();
}

@riverpod
Stream<LatLng> providerLocation(ProviderLocationRef ref, String bookingId) {
  final repository = ref.watch(trackingRepositoryProvider);
  return repository.trackProvider(bookingId);
}
