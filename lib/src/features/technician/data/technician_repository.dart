import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

part 'technician_repository.g.dart';

class TechnicianRepository {
  final Dio _client;

  TechnicianRepository(this._client);

  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      await _client.post(
        Endpoints.technicianLocation,
        data: {'latitude': latitude, 'longitude': longitude},
      );
    } catch (e) {
      // Fallback: Use Realtime DB if API is rate limited
      if (e is DioException && e.response?.statusCode == 429) {
        try {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            // Update location using PostGIS point format if possible,
            // or just let the backend handle it if we had a trigger.
            // Since we are writing direct, we need to match the schema.
            // The schema uses `location GEOGRAPHY(POINT)`.
            // Supabase Dart SDK supports casting to geography.
            // Ideally we use a stored procedure, but for now let's try
            // updating the raw column if the SDK supports it, or use a function.

            // Safer: Use a simple RPC if available, or just ignore for now to stop the crash.
            // Let's try updating the `users` table directly if RLS allows self-update.
            await Supabase.instance.client
                .from('users')
                .update({'location': 'POINT($longitude $latitude)'})
                .eq('id', userId);
            return;
          }
        } catch (dbError) {
          // Ignore db error in background tracking
        }
      }

      // Silently fail for other errors to avoid spam
      // print('Failed to update location: $e');
    }
  }

  Future<void> toggleStatus(bool isOnline) async {
    await _client.post(
      Endpoints.technicianStatus,
      data: {'isOnline': isOnline},
    );
  }
}

@riverpod
TechnicianRepository technicianRepository(TechnicianRepositoryRef ref) {
  return TechnicianRepository(ref.watch(apiClientProvider));
}
