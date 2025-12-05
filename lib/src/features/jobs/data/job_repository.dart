import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../domain/job.dart';

part 'job_repository.g.dart';

class JobRepository {
  final Dio _client;

  JobRepository(this._client);

  Future<Job> createJob({
    required String serviceId,
    required double lat,
    required double lng,
    required String addressText,
    required double initialPrice,
    String? description,
  }) async {
    try {
      final response = await _client.post(
        Endpoints.jobs,
        data: {
          'service_id': serviceId,
          'lat': lat,
          'lng': lng,
          'address_text': addressText,
          'initial_price': initialPrice,
          'description': description,
        },
      );
      return Job.fromJson(response.data['job']);
    } catch (e) {
      throw Exception('فشل إنشاء الطلب');
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
      if (e is DioException) {
        final message = e.response?.data['message'] ?? 'فشل جلب الطلبات القريبة';
        final statusCode = e.response?.statusCode;
        final rawData = e.response?.data;
        throw Exception('$message (Status: $statusCode, Data: $rawData, Error: ${e.message})');
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
      throw Exception('فشل جلب طلباتي');
    }
  }

  Future<void> acceptJob(String jobId) async {
    try {
      await _client.post(Endpoints.acceptJob(jobId));
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        throw Exception('عذراً، تم قبول الطلب من فني آخر');
      }
      throw Exception('فشل قبول الطلب');
    }
  }

  Future<void> completeJob(String jobId) async {
    try {
      await _client.post(Endpoints.completeJob(jobId));
    } catch (e) {
      throw Exception('فشل إكمال الطلب');
    }
  }

  Future<void> cancelJob(String jobId) async {
    try {
      await Supabase.instance.client
          .from('jobs')
          .update({'status': 'cancelled'})
          .eq('id', jobId);
    } catch (e) {
      throw Exception('فشل إلغاء الطلب');
    }
  }
  Stream<Job> watchJob(String jobId) {
    return Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .map((data) => data.isNotEmpty ? Job.fromJson(data.first) : throw Exception('Job not found'));
  }

  Stream<List<Job>> watchNearbyJobs({
    required double lat,
    required double lng,
    double radius = 5000,
  }) {
    // Note: Supabase Realtime doesn't support complex PostGIS filters directly in the stream definition easily without Row Level Security policies filtering the data for us.
    // However, since we fixed the RLS to allow technicians to see pending jobs, we can listen to the 'jobs' table.
    // For a true "nearby" stream, we'd ideally rely on the backend to filter, but Realtime is "dumb" in that it pushes changes matching basic filters.
    // A common workaround is to listen to all pending jobs (if volume is low) and filter client-side, OR rely on RLS to only send us relevant rows.
    // Given the previous RLS fix "Technicians can view pending jobs", we will receive all pending jobs.
    // We will filter them client-side for distance for now to keep it responsive.
    
    return Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .map((data) {
          final jobs = data.map((e) => Job.fromJson(e)).toList();
          // TODO: Add client-side distance filtering here if needed
          return jobs;
        });
  }
}

@Riverpod(keepAlive: true)
JobRepository jobRepository(JobRepositoryRef ref) {
  final client = ref.watch(apiClientProvider);
  return JobRepository(client);
}
