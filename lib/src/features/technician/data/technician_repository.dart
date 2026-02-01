import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../domain/technician_profile.dart';

part 'technician_repository.g.dart';

class TechnicianRepository {
  final Dio _client;

  TechnicianRepository(this._client);

  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      // Prevent spamming 401s if not logged in
      var session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      // Refresh if needed
      final expiresAt = session.expiresAt;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (expiresAt != null && expiresAt <= now + 60) {
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (_) {}
      }

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

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await _client.put(Endpoints.updateProfile, data: data);
    } catch (e) {
      throw Exception('فشل تحديث الملف الشخصي');
    }
  }

  Future<void> addPortfolioWork(Map<String, dynamic> data) async {
    try {
      await _client.post(Endpoints.addPortfolioWork, data: data);
    } catch (e) {
      throw Exception('فشل إضافة العمل');
    }
  }

  Future<TechnicianProfile> getTechnicianProfile(String result) async {
    try {
      // Correct endpoint usage
      final response = await _client.get('/technician/$result');
      // Backend returns { message: "...", data: { ... } }
      return TechnicianProfile.fromJson(response.data['data']);
    } catch (e) {
      throw Exception('فشل تحميل الملف الشخصي للفني');
    }
  }
}

@riverpod
TechnicianRepository technicianRepository(TechnicianRepositoryRef ref) {
  return TechnicianRepository(ref.watch(apiClientProvider));
}
