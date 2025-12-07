import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../domain/job.dart';

part 'job_repository.g.dart';

class JobRepository {
  final Dio _client;

  JobRepository(this._client);

  Future<Job?> createJob({
    required String serviceId,
    required double lat,
    required double lng,
    required String addressText,
    required double initialPrice,
    String? description,
    List<String>? images,
  }) async {
    try {
      // Use a fresh Dio instance to avoid "Future already completed" errors
      // caused by the global interceptor state in the main apiClient
      final dio = Dio(
        BaseOptions(
          baseUrl: Endpoints.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // Manually add token
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }

      final response = await dio.post(
        '/jobs',
        data: {
          'service_id': serviceId,
          'lat': lat,
          'lng': lng,
          'address_text': addressText,
          'initial_price': initialPrice,
          'description': description,
          'images': images,
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        return Job.fromJson(response.data['job']);
      }
      return null;
    } catch (e) {
      // Fallback: Try direct Supabase Insert if API is rate limited (429)
      if (e is DioException && e.response?.statusCode == 429) {
        try {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId == null) throw Exception('User not logged in');

          // 1. Insert Job
          final jobData = await Supabase.instance.client
              .from('jobs')
              .insert({
                'service_id': serviceId,
                'customer_id': userId,
                'lat': lat,
                'lng': lng,
                'address_text': addressText,
                'initial_price': initialPrice,
                'description': description,
                'status': 'pending', // Default status
              })
              .select(
                '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*)',
              )
              .single();

          final job = Job.fromJson(jobData);

          // 2. Insert Images (if any)
          if (images != null && images.isNotEmpty) {
            final imageInserts = images
                .map(
                  (url) => {
                    'job_id': job.id,
                    'url': url,
                    'media_type': 'image', // explicit type
                  },
                )
                .toList();

            await Supabase.instance.client
                .from('job_images')
                .insert(imageInserts);
          }

          return job;
        } catch (dbError) {
          debugPrint('⚠️ Fallback Job Creation Failed: $dbError');
          // Re-throw the DB error so we know why it failed (RLS, missing table, etc)
          throw Exception('فشل إنشاء الطلب (Offline Mode Failed): $dbError');
        }
      }
      throw Exception('فشل إنشاء الطلب: ${e.response?.data['message'] ?? e.message}');
    }
  }

  Future<List<Job>> getNearbyJobs({
    required double lat,
    required double lng,
    double radius = 5000,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.nearbyJobs,
        queryParameters: {'lat': lat, 'lng': lng, 'radius': radius},
      );

      final List data = response.data['jobs'];
      return data.map((e) => Job.fromJson(e)).toList();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 429) {
        // Fallback: Fetch pending jobs directly
        try {
          final data = await Supabase.instance.client
              .from('jobs')
              .select(
                '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*)',
              )
              .eq('status', 'pending')
              .isFilter('technician_id', null)
              .order('created_at', ascending: false);

          // Simple client-side distance filter could be added here if needed,
          // but for fallback, returning all pending jobs is "good enough" to unblock
          return (data as List).map((e) => Job.fromJson(e)).toList();
        } catch (_) {}
      }

      if (e is DioException) {
        final message =
            e.response?.data['message'] ?? 'فشل جلب الطلبات القريبة';
        throw Exception(message);
      }
      throw Exception('فشل جلب الطلبات القريبة: $e');
    }
  }

  Future<List<Job>> getMyJobs() async {
    try {
      final response = await _client.get(Endpoints.myJobs);
      final List data = response.data['jobs'];
      return data.map((e) => Job.fromJson(e)).toList();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 429) {
        // Fallback: Fetch my jobs directly
        try {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            final data = await Supabase.instance.client
                .from('jobs')
                .select(
                  '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*)',
                )
                .or(
                  'customer_id.eq.$userId,technician_id.eq.$userId',
                ) // Fetch jobs where I am customer OR technician
                .order('created_at', ascending: false);
            return (data as List).map((e) => Job.fromJson(e)).toList();
          }
        } catch (_) {}
      }
      throw Exception('فشل جلب طلباتي');
    }
  }

  Future<Job> acceptJob(String jobId) async {
    try {
      // Use a fresh Dio instance to avoid potential race conditions
      // with the shared interceptor state
      final dio = Dio(
        BaseOptions(
          baseUrl: Endpoints.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // Manually add token
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }

      final response = await dio.post(Endpoints.acceptJob(jobId));
      return Job.fromJson(response.data['job']);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        throw Exception('عذراً، تم قبول الطلب من فني آخر');
      }
      throw Exception('فشل قبول الطلب: $e');
    }
  }

  Future<Job> setPrice(String jobId, double price, {String? notes}) async {
    try {
      final response = await _client.post(
        Endpoints.setPrice(jobId),
        data: {'price': price, 'notes': notes},
      );
      return Job.fromJson(response.data['job']);
    } catch (e) {
      throw Exception('فشل تحديد السعر');
    }
  }

  Future<Job> confirmPrice(
    String jobId,
    bool accepted, {
    double? counterOffer,
  }) async {
    try {
      final response = await _client.post(
        Endpoints.confirmPrice(jobId),
        data: {
          'accepted': accepted,
          if (counterOffer != null) 'counter_offer': counterOffer,
        },
      );
      return Job.fromJson(response.data['job']);
    } catch (e) {
      throw Exception('فشل تأكيد السعر');
    }
  }

  Future<void> completeJob(String jobId) async {
    try {
      await _client.post(Endpoints.completeJob(jobId));
    } catch (e) {
      throw Exception('فشل إكمال الطلب');
    }
  }

  Future<Job> rateJob(String jobId, int rating, {String? review}) async {
    try {
      final response = await _client.post(
        Endpoints.rateJob(jobId),
        data: {'rating': rating, 'review': review},
      );
      return Job.fromJson(response.data['job']);
    } catch (e) {
      throw Exception('فشل إرسال التقييم');
    }
  }

  Future<void> cancelJob(String jobId, {String? reason}) async {
    try {
      await _client.post(Endpoints.cancelJob(jobId), data: {'reason': reason});
    } catch (e) {
      throw Exception('فشل إلغاء الطلب');
    }
  }

  Future<Job?> getJob(String jobId) async {
    try {
      final response = await _client.get('${Endpoints.jobs}/$jobId');
      if (response.statusCode == 200) {
        // If generic get endpoint isn't available, we can fallback to supabase select
        return Job.fromJson(response.data['job']);
      }
      return null;
    } catch (e) {
      try {
        // Fallback to direct Supabase select if API fails
        final data = await Supabase.instance.client
            .from('jobs')
            .select(
              '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*)',
            )
            .eq('id', jobId)
            .single();
        return Job.fromJson(data);
      } catch (dbError) {
        debugPrint('Error getting job: $dbError');
        return null;
      }
    }
  }

  Stream<Job> watchJob(String jobId) {
    return Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .asyncMap((data) async {
          if (data.isEmpty) {
            throw Exception('Job not found');
          }

          try {
            // Fetch full details with relations
            final fullData = await Supabase.instance.client
                .from('jobs')
                .select(
                  '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*)',
                )
                .eq('id', jobId)
                .single();

            return Job.fromJson(fullData);
          } catch (e) {
            debugPrint('⚠️ Error fetching full job details: $e');
            // Fallback to basic data if fetch fails
            try {
              return Job.fromJson(data.first);
            } catch (parseError) {
              debugPrint('⚠️ Error parsing fallback job: $parseError');
              // Return a minimal valid job to prevent crash, or rethrow
              rethrow;
            }
          }
        });
  }

  Stream<List<Job>> watchNearbyJobs({
    required double lat,
    required double lng,
    double radius = 5000,
    String? serviceId,
  }) {
    final builder = Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id']);

    if (serviceId != null) {
      return builder
          .eq('service_id', serviceId)
          .order('created_at', ascending: false)
          .map((data) => _processJobsList(data));
    }

    return builder
        .order('created_at', ascending: false)
        .map((data) => _processJobsList(data));
  }

  List<Job> _processJobsList(List<Map<String, dynamic>> data) {
    debugPrint('📡 watchNearbyJobs: Received ${data.length} raw jobs');
    final twelveHoursAgo = DateTime.now().subtract(const Duration(hours: 12));

    final jobs = <Job>[];
    for (final item in data) {
      try {
        final job = Job.fromJson(item);
        if (['pending', 'searching'].contains(job.status) &&
            job.createdAt.isAfter(twelveHoursAgo)) {
          jobs.add(job);
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing job in watchNearbyJobs: $e');
        debugPrint('   Data: $item');
      }
    }
    debugPrint('✅ watchNearbyJobs: Filtered down to ${jobs.length} jobs');
    return jobs;
  }

  Stream<List<Job>> watchMyActiveJobs(String userId) {
    return Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          return data
              .map((e) => Job.fromJson(e))
              .where(
                (j) =>
                    (j.customerId == userId || j.technicianId == userId) &&
                    !['completed', 'cancelled'].contains(j.status),
              )
              .toList();
        });
  }

  Stream<Map<String, dynamic>> trackTechnician(String technicianId) {
    return Supabase.instance.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', technicianId)
        .map((data) {
          if (data.isEmpty) return {};
          return data.first;
        });
  }
}

@Riverpod(keepAlive: true)
JobRepository jobRepository(JobRepositoryRef ref) {
  final client = ref.watch(apiClientProvider);
  return JobRepository(client);
}
