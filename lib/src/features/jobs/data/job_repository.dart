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

  Future<Job> acceptJob(String jobId) async {
    try {
      final response = await _client.post(Endpoints.acceptJob(jobId));
      return Job.fromJson(response.data['job']);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        throw Exception('عذراً، تم قبول الطلب من فني آخر');
      }
      throw Exception('فشل قبول الطلب');
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

  Future<Job> confirmPrice(String jobId, bool accepted, {double? counterOffer}) async {
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
      await _client.post(
        Endpoints.cancelJob(jobId),
        data: {'reason': reason},
      );
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
    return Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .map((data) {
          final jobs = data.map((e) => Job.fromJson(e)).toList();
          return jobs;
        });
  }

  Stream<List<Job>> watchMyActiveJobs(String userId) {
    return Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          return data
              .map((e) => Job.fromJson(e))
              .where((j) => 
                  (j.customerId == userId || j.technicianId == userId) &&
                  !['completed', 'cancelled'].contains(j.status))
              .toList();
        });
  }
}

@Riverpod(keepAlive: true)
JobRepository jobRepository(JobRepositoryRef ref) {
  final client = ref.watch(apiClientProvider);
  return JobRepository(client);
}
