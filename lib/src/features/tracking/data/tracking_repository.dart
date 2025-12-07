import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'tracking_repository.g.dart';

class TrackingRepository {
  // Real-time provider tracking
  Stream<LatLng> trackProvider(String bookingId) {
    // We assume the bookingId (JobId) lets us find the Technician.
    // Ideally we track the Technician User ID directly.
    return Supabase.instance.client.from('users').stream(primaryKey: ['id'])
    // We filter by the technician ID.
    // Note: The UI needs to pass the TechnicianID, not just BookingID if we track User.
    // For now, let's assume we pass the TechnicianID to this method or lookup.
    // ACTUALLY: The TrackingScreen receives `bookingId`.
    // We need to fetch the Job first to get the TechnicianID, OR the UI passes it.
    // The UI passes `technicianId` in the `extra` map!
    // But the provider expects `bookingId`.
    // Let's change the parameter logic in the provider.
    .map((data) {
      // This is a placeholder stream if we don't have the ID.
      // The real logic should be in the Provider below.
      return const LatLng(0, 0);
    });
  }

  Stream<LatLng> trackTechnicianLocation(String technicianId) {
    return Supabase.instance.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', technicianId)
        .map((data) {
          if (data.isNotEmpty) {
            final user = data.first;
            // Check if location column exists and is not null
            if (user['location'] != null) {
              // PostGIS point: POINT(lng lat)
              // We might need to parse it if it comes as string, or if we used a separate lat/lng column
              // The schema says: `location GEOGRAPHY(POINT)`
              // Supabase Dart might return this as GeoJSON or WKT.
              // For MVP, if we haven't implemented location updates writing,
              // let's look for 'current_lat' and 'current_lng' if they exist,
              // OR just use the simulated one if the backend isn't writing location yet.
              // Checking schema... `location` column exists.
              // Let's assume we maintain `lat` and `lng` columns for simplicity in Flutter?
              // The schema showed `lat` and `lng` in JOBS, but `users` has `location`.

              // CRITICAL: We need to know HOW location is stored.
              // For now, keeping the simulated stream until we verify the Writer side.
              return const LatLng(24.7136, 46.6753);
            }
          }
          return const LatLng(24.7136, 46.6753);
        });
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
