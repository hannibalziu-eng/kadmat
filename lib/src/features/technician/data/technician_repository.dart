import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      if (e is DioException) {
        debugPrint(
          '⚠️ [TechnicianRepository.updateLocation] API failed (${e.response?.statusCode}): ${e.message}',
        );

        // Fallback: Direct DB update when API endpoint is unavailable/rate-limited.
        try {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            await Supabase.instance.client
                .from('users')
                .update({
                  'location': 'SRID=4326;POINT($longitude $latitude)',
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', userId);
            debugPrint(
              '✅ [TechnicianRepository.updateLocation] Fallback direct DB update succeeded',
            );
            return;
          }
        } catch (dbError) {
          debugPrint(
            '❌ [TechnicianRepository.updateLocation] Fallback failed: $dbError',
          );
        }
      }

      debugPrint('❌ [TechnicianRepository.updateLocation] Failed: $e');
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

  Future<void> deletePortfolioWork(String id) async {
    try {
      await _client.delete('${Endpoints.addPortfolioWork}/$id');
    } catch (e) {
      throw Exception('فشل حذف العمل');
    }
  }

  Future<TechnicianProfile> getTechnicianProfile(String technicianId) async {
    if (technicianId.trim().isEmpty) {
      throw Exception('معرّف الفني غير صالح');
    }

    try {
      final response = await _client.get('/technician/$technicianId');
      final body = response.data;
      final payload = body is Map<String, dynamic>
          ? (body['data'] is Map<String, dynamic>
                ? body['data'] as Map<String, dynamic>
                : body)
          : null;

      if (payload != null) {
        return TechnicianProfile.fromJson(payload);
      }
      throw Exception('استجابة غير متوقعة من الخادم');
    } catch (e) {
      debugPrint(
        '⚠️ [getTechnicianProfile] API fallback for $technicianId: $e',
      );
      try {
        // Safe fallback directly from Supabase to avoid hard failure.
        final supabase = Supabase.instance.client;

        final user = await supabase
            .from('users')
            .select(
              'id, full_name, profile_image_url, rating, created_at, title, bio, address, location, service:service_id(name_ar)',
            )
            .eq('id', technicianId)
            .eq('user_type', 'technician')
            .maybeSingle();

        if (user == null) {
          throw Exception('الفني غير موجود');
        }

        List<Map<String, dynamic>> portfolio = const [];
        try {
          final rows = await supabase
              .from('technician_portfolio')
              .select('id, image_url, title, description, project_date')
              .eq('technician_id', technicianId)
              .order('project_date', ascending: false);

          portfolio = (rows as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        } catch (portfolioError) {
          debugPrint(
            '⚠️ [getTechnicianProfile] Portfolio fallback failed: $portfolioError',
          );
        }

        List<Map<String, dynamic>> reviews = const [];
        try {
          final rows = await supabase
              .from('reviews')
              .select(
                'id, rating, comment, created_at, reviewer:users!reviewer_id(full_name, profile_image_url)',
              )
              .eq('reviewee_id', technicianId)
              .order('created_at', ascending: false)
              .limit(20);

          reviews = (rows as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        } catch (reviewsError) {
          debugPrint(
            '⚠️ [getTechnicianProfile] Reviews fallback failed: $reviewsError',
          );
        }

        int completedJobs = 0;
        try {
          final rows = await supabase
              .from('jobs')
              .select('id')
              .eq('technician_id', technicianId)
              .filter('status', 'in', '("completed","rated")');

          completedJobs = (rows as List).length;
        } catch (statsError) {
          debugPrint(
            '⚠️ [getTechnicianProfile] Stats fallback failed: $statsError',
          );
        }

        final serviceRaw = user['service'];
        String specialization = 'فني خدمات عامة';
        if (serviceRaw is Map) {
          final name = serviceRaw['name_ar']?.toString().trim();
          if (name != null && name.isNotEmpty) {
            specialization = name;
          }
        } else if (serviceRaw is List && serviceRaw.isNotEmpty) {
          final first = serviceRaw.first;
          if (first is Map) {
            final name = first['name_ar']?.toString().trim();
            if (name != null && name.isNotEmpty) {
              specialization = name;
            }
          }
        }

        final mapped = {
          ...user,
          'location': user['address'] ?? user['location'],
          'specialization': specialization,
          'stats': {
            'completedJobs': completedJobs,
            'rating': (user['rating'] as num?)?.toDouble() ?? 5.0,
            'totalReviews': reviews.length,
          },
          'portfolio': portfolio,
          'reviews': reviews,
        };
        return TechnicianProfile.fromJson(Map<String, dynamic>.from(mapped));
      } catch (_) {
        throw Exception('فشل تحميل الملف الشخصي للفني');
      }
    }
  }
}

@riverpod
TechnicianRepository technicianRepository(Ref ref) {
  return TechnicianRepository(ref.watch(apiClientProvider));
}
