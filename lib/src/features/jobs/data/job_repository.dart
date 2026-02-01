import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/services/photo_upload_service.dart';
import '../../../core/services/offline/work_queue_service.dart';
import '../../../core/realtime/supabase_realtime_service.dart';
import '../../../core/exceptions/app_exceptions.dart';

import '../domain/job.dart';

part 'job_repository.g.dart';

class JobRepository {
  final Dio _client;
  final PhotoUploadService _photoService;
  final WorkQueueService _workQueue;
  final SupabaseRealtimeService _realtimeService;

  JobRepository(
    this._client,
    this._photoService,
    this._workQueue,
    this._realtimeService,
  );

  /// Fetch nearby jobs using Supabase RPC for scalable server-side filtering
  Future<List<Job>> getNearbyJobsRpc({
    required double lat,
    required double lng,
    int radiusMeters = 5000,
    int limit = 50,
    String? serviceId,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_nearby_jobs',
        params: {
          'technician_lat': lat,
          'technician_lng': lng,
          'radius_meters': radiusMeters,
          'limit_count': limit,
        },
      );

      debugPrint(
        '🕵️ RPC [get_nearby_jobs] Called with: lat=$lat, lng=$lng, r=$radiusMeters',
      );
      final List<dynamic> data = response as List<dynamic>;
      debugPrint('🕵️ RPC [get_nearby_jobs] Result Count: ${data.length}');
      if (data.isNotEmpty) {
        debugPrint('🕵️ First Job: ${data.first.toString()}');
      } else {
        debugPrint('🕵️ No jobs found via RPC. Check Backend/Location/Radius.');
      }

      var jobs = data.map((e) => Job.fromJson(e)).toList();

      // LOG ALL JOB SERVICE IDs
      for (var j in jobs) {
        debugPrint(
          '📋 Found Job: ${j.id} | ServiceID: ${j.serviceId} | Status: ${j.status}',
        );
      }

      // Filter by serviceId if provided
      if (serviceId != null) {
        debugPrint('🔍 Filtering by Service ID: $serviceId');
        // TEMPORARILY DISABLED FILTER to verify data visibility
        /* 
        jobs = jobs.where((job) {
             final jobServiceId = job.serviceId ?? job.service?['id'];
             return jobServiceId == serviceId;
        }).toList();
        */
        debugPrint(
          '⚠️ FILTER DISABLED CHECK: Would have filtered to: ${jobs.where((job) => (job.serviceId ?? job.service?['id']) == serviceId).length}',
        );
      }

      return jobs;
    } catch (e) {
      debugPrint('❌ Error fetching nearby jobs via RPC: $e');
      // If RPC fails (e.g. function not found during dev), fall back to empty list or throw
      rethrow;
    }
  }

  Future<Job?> createJob({
    required String serviceId,
    required double lat,
    required double lng,
    required String addressText,
    required double initialPrice,
    String? description,
    List<String>? images,
  }) async {
    debugPrint('🚀 [createJob] Starting job creation...');
    debugPrint('📍 [createJob] Location: lat=$lat, lng=$lng');
    debugPrint('🔧 [createJob] ServiceId: $serviceId');

    try {
      final response = await _client.post(
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
        debugPrint('✅ [createJob] Job created successfully');
        return Job.fromJson(response.data['data']);
      }

      // Instead of returning null, throw a detailed exception
      final statusCode = response.statusCode;
      final errorMessage =
          response.data['message'] ?? 'استجابة غير متوقعة من الخادم';
      final errorCode = response.data['code'] ?? 'UNKNOWN_ERROR';

      debugPrint(
        '⚠️ [createJob] Unexpected response: statusCode=$statusCode, code=$errorCode, message=$errorMessage',
      );
      debugPrint('⚠️ [createJob] Full response: ${response.data}');

      throw JobCreationException(
        message: errorMessage,
        statusCode: statusCode ?? 500,
        errorCode: errorCode,
        responseData: response.data,
      );
    } on DioException catch (e) {
      debugPrint(
        '🚨 [createJob] Dio error: ${e.response?.statusCode} - ${e.message}',
      );

      // Extract detailed error info from response
      final statusCode = e.response?.statusCode ?? 0;
      final responseData = e.response?.data;
      String errorMessage = 'فشل إنشاء الطلب';
      String errorCode = 'NETWORK_ERROR';

      if (responseData != null && responseData is Map) {
        errorMessage = responseData['message'] ?? errorMessage;
        errorCode = responseData['code'] ?? errorCode;
      } else {
        errorMessage = e.message ?? errorMessage;
      }

      debugPrint(
        '🚨 [createJob] Error details: code=$errorCode, message=$errorMessage',
      );

      throw JobCreationException(
        message: errorMessage,
        statusCode: statusCode,
        errorCode: errorCode,
        responseData: responseData,
        originalException: e,
      );
    } catch (e) {
      debugPrint('🚨 [createJob] General error: $e');
      if (e is JobCreationException) rethrow;
      throw JobCreationException(
        message: e.toString(),
        statusCode: 0,
        errorCode: 'UNKNOWN_ERROR',
        originalException: e,
      );
    }
  }

  /// Get a single job by ID with full details
  Future<Job?> getJobById(String jobId) async {
    try {
      final response = await _client.get('/jobs/$jobId');

      final body = response.data;
      if (body == null || body['success'] != true || body['data'] == null) {
        return null;
      }
      return Job.fromJson(body['data']);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return null;
      }
      // Fallback to Supabase with job_images included
      try {
        final data = await Supabase.instance.client
            .from('jobs')
            .select(
              '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*), job_images(id, image_url, media_type)',
            )
            .eq('id', jobId)
            .maybeSingle();

        if (data == null) return null;
        return Job.fromJson(data);
      } catch (_) {
        return null;
      }
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

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        return data.map((e) => Job.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 429) {
        // Fallback: Fetch pending jobs directly from Supabase
        try {
          final data = await Supabase.instance.client
              .from('jobs')
              .select(
                '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*)',
              )
              .eq('status', 'pending')
              .isFilter('technician_id', null)
              .order('created_at', ascending: false);
          return (data as List).map((e) => Job.fromJson(e)).toList();
        } catch (_) {}
      }

      debugPrint('❌ Failed to fetch nearby jobs: $e');
      // Return empty list on error for now to avoid crashing UI
      return [];
    }
  }

  Future<List<Job>> getMyJobs() async {
    try {
      final response = await _client.get(Endpoints.myJobs);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List data = response.data['data'];
        return data.map((e) => Job.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 429) {
        // Fallback: Fetch my jobs directly from Supabase
        try {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            final data = await Supabase.instance.client
                .from('jobs')
                .select(
                  '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*)',
                )
                .or('customer_id.eq.$userId,technician_id.eq.$userId')
                .order('created_at', ascending: false);
            return (data as List).map((e) => Job.fromJson(e)).toList();
          }
        } catch (_) {}
      }

      debugPrint('❌ Failed to fetch my jobs: $e');
      // Rethrow to allow UI to show error / retry
      throw Exception('فشل جلب طلباتي');
    }
  }

  Future<Job> acceptJob(String jobId) async {
    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.first == ConnectivityResult.none) {
      throw NetworkException('لا يوجد اتصال بالإنترنت');
    }

    // Check technician lock BEFORE calling API
    final isLocked = await isTechnicianLocked();
    if (isLocked) {
      throw TechnicianLockedException(
        'لديك طلب قيد التنفيذ. يجب إكماله قبل قبول طلبات جديدة',
      );
    }

    try {
      final response = await _client.post(Endpoints.acceptJob(jobId));

      final body = response.data;
      if (body == null) {
        throw Exception('استجابة غير متوقعة من الخادم');
      }

      if (body['success'] == true) {
        return Job.fromJson(body['data']);
      }

      // Handle specific error codes from backend
      final error = body['error'];
      final code = error?['code'] ?? 'UNKNOWN_ERROR';
      final message = error?['message'] ?? 'فشل قبول الطلب';

      switch (code) {
        case 'JOB_ALREADY_ACCEPTED':
          throw JobAlreadyAcceptedException(message);
        case 'INVALID_STATUS_TRANSITION':
          final currentStatus = error?['currentStatus'] as String?;
          throw InvalidStatusException(message, currentStatus: currentStatus);
        case 'JOB_NOT_FOUND':
          throw JobNotFoundException(message);
        case 'ACCEPT_FAILED':
          throw JobAlreadyAcceptedException(
            message.isNotEmpty
                ? message
                : 'فشل قبول الطلب. قد يكون تم قبوله من فني آخر',
          );
        default:
          throw Exception(message);
      }
    } on DioException catch (e) {
      // Handle Network Errors: Queue Request
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.error is SocketException) {
        await _workQueue.queueRequest(
          endpoint: Endpoints.acceptJob(jobId),
          method: 'POST',
          payload: {},
        );
        throw OfflineRequestQueuedException(
          'لا يوجد اتصال. تم حفظ طلبك وسيتم إرساله تلقائياً عند عودة الإنترنت.',
        );
      }

      // Handle HTTP status codes
      if (e.response?.statusCode == 409) {
        throw JobAlreadyAcceptedException('تم قبول الطلب من فني آخر');
      }
      if (e.response?.statusCode == 400) {
        final errorCode = e.response?.data['error']?['code'];
        if (errorCode == 'INVALID_STATUS_TRANSITION') {
          final currentStatus = e.response?.data['error']?['currentStatus'];
          throw InvalidStatusException(
            'حالة الطلب غير صحيحة',
            currentStatus: currentStatus,
          );
        }
      }
      if (e.response?.statusCode == 404) {
        throw JobNotFoundException('لم يتم العثور على الطلب');
      }

      rethrow;
    } catch (e) {
      // Re-throw specific exceptions as-is
      if (e is JobAlreadyAcceptedException ||
          e is InvalidStatusException ||
          e is TechnicianLockedException ||
          e is NetworkException ||
          e is JobNotFoundException ||
          e is OfflineRequestQueuedException) {
        rethrow;
      }
      // Convert to generic exception
      throw Exception('فشل قبول الطلب: ${e.toString()}');
    }
  }

  Future<Job> setPrice(
    String jobId,
    double price, {
    String? notes,
    String? paymentMethod,
  }) async {
    try {
      final response = await _client.post(
        Endpoints.setPrice(jobId),
        data: {'price': price, 'notes': notes, 'paymentMethod': paymentMethod},
      );
      return Job.fromJson(response.data['data']);
    } catch (e) {
      if (e is DioException) {
        // Handle Dio errors specifically if needed
      }
      throw Exception('فشل تحديد السعر: ${e.toString()}');
    }
  }

  Future<Job> confirmPrice(String jobId) async {
    try {
      final response = await _client.post(Endpoints.confirmPrice(jobId));

      final body = response.data;
      if (body == null || body['success'] != true) {
        throw Exception(body?['error']?['message'] ?? 'فشل تأكيد السعر');
      }
      return Job.fromJson(body['data']);
    } catch (e) {
      if (e is DioException && e.response?.statusCode != 404) {
        // Fallback: Update directly in Supabase
        try {
          // Get current technician price first to set as final price
          final jobData = await Supabase.instance.client
              .from('jobs')
              .select('technician_price')
              .eq('id', jobId)
              .single();

          final techPrice = jobData['technician_price'];

          final data = await Supabase.instance.client
              .from('jobs')
              .update({
                'status': 'customer_agreed',
                'price_confirmed_at': DateTime.now().toIso8601String(),
                'final_price': techPrice,
              })
              .eq('id', jobId)
              .select(
                '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*)',
              )
              .single();
          return Job.fromJson(data);
        } catch (dbError) {
          throw Exception('فشل تأكيد السعر: $dbError');
        }
      }
      if (e is Exception) rethrow;
      throw Exception('فشل تأكيد السعر');
    }
  }

  Future<Job> requestJobCompletion(
    String jobId, {
    double? finalPrice,
    String? paymentMethod,
    String? notes,
    List<String>? afterPhotos,
  }) async {
    try {
      final response = await _client.post(
        '/jobs/$jobId/request-completion',
        data: {
          'final_price': finalPrice,
          'payment_method': paymentMethod,
          'notes': notes,
          'after_photos': afterPhotos,
        },
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        throw Exception(body?['error']?['message'] ?? 'فشل إرسال طلب الإكمال');
      }
      return Job.fromJson(body['data']);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('فشل إرسال طلب الإكمال');
    }
  }

  Future<Job> confirmJobCompletion(String jobId) async {
    try {
      final response = await _client.post(
        '/jobs/$jobId/confirm-completion',
      ); // New endpoint logic

      final body = response.data;
      if (body == null || body['success'] != true) {
        throw Exception(body?['error']?['message'] ?? 'فشل تأكيد الإكمال');
      }
      return Job.fromJson(body['data']);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('فشل تأكيد الإكمال');
    }
  }

  Future<Job> rateJob(String jobId, int rating, {String? review}) async {
    try {
      final response = await _client.post(
        Endpoints.rateJob(jobId),
        data: {'rating': rating, 'review': review},
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        throw Exception(body?['error']?['message'] ?? 'فشل إرسال التقييم');
      }
      return Job.fromJson(body['data']);
    } catch (e) {
      if (e is Exception) rethrow;
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
      debugPrint('Error getting job: $e');
      return null;
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
              rethrow;
            }
          }
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

  // ========== PHOTO UPLOAD METHODS ==========

  /// Upload pre-service photos for a job
  /// Returns list of photo URLs
  Future<List<String>> uploadPreServicePhotos(
    String jobId,
    List<XFile> photos,
    String description,
  ) async {
    try {
      debugPrint(
        '📤 Uploading ${photos.length} pre-service photos for job $jobId',
      );

      // Upload photos to Supabase Storage
      final photoUrls = await _photoService.uploadMultiplePhotos(
        photos,
        'jobs/$jobId/pre',
        onProgress: (current, total) {
          debugPrint('📊 Upload progress: $current/$total');
        },
      );

      // Save photo records to database
      final photoRecords = photoUrls
          .map(
            (url) => {
              'job_id': jobId,
              'photo_url': url,
              'photo_type': 'pre',
              'description': description,
            },
          )
          .toList();

      await Supabase.instance.client.from('job_photos').insert(photoRecords);

      debugPrint('✅ Pre-service photos uploaded successfully');
      return photoUrls;
    } catch (e) {
      debugPrint('❌ Failed to upload pre-service photos: $e');
      throw Exception('فشل رفع صور ما قبل الخدمة');
    }
  }

  // uploadPreServicePhotosFromXFile removed as it is now redundant.
  // Use uploadPreServicePhotos instead.

  /// Upload post-service photos for a job
  /// Returns list of photo URLs
  Future<List<String>> uploadPostServicePhotos(
    String jobId,
    List<XFile> photos,
    String notes,
  ) async {
    try {
      debugPrint(
        '📤 Uploading ${photos.length} post-service photos for job $jobId',
      );

      // Upload photos to Supabase Storage
      final photoUrls = await _photoService.uploadMultiplePhotos(
        photos,
        'jobs/$jobId/post',
        onProgress: (current, total) {
          debugPrint('📊 Upload progress: $current/$total');
        },
      );

      // Save photo records to database
      final photoRecords = photoUrls
          .map(
            (url) => {
              'job_id': jobId,
              'photo_url': url,
              'photo_type': 'post',
              'description': notes,
            },
          )
          .toList();

      await Supabase.instance.client.from('job_photos').insert(photoRecords);

      debugPrint('✅ Post-service photos uploaded successfully');
      return photoUrls;
    } catch (e) {
      debugPrint('❌ Failed to upload post-service photos: $e');
      throw Exception('فشل رفع صور ما بعد الخدمة');
    }
  }

  // uploadPostServicePhotosFromXFile removed as it is now redundant.

  /// Get all photos for a job
  Future<Map<String, List<String>>> getJobPhotos(String jobId) async {
    try {
      debugPrint('📷 Fetching photos for job: $jobId');

      final data = await Supabase.instance.client
          .from('job_photos')
          .select('photo_url, photo_type')
          .eq('job_id', jobId);

      debugPrint('📷 Raw photo data: $data');

      final prePhotos = <String>[];
      final postPhotos = <String>[];

      for (final record in data) {
        final url = record['photo_url'] as String?;
        final type = record['photo_type'] as String?;

        if (url == null || url.isEmpty) {
          debugPrint('⚠️ Skipping photo with empty URL');
          continue;
        }

        debugPrint('📷 Photo URL: $url (type: $type)');

        if (type == 'pre') {
          prePhotos.add(url);
        } else if (type == 'post') {
          postPhotos.add(url);
        }
      }

      debugPrint(
        '✅ Found ${prePhotos.length} pre-photos and ${postPhotos.length} post-photos',
      );
      return {'pre': prePhotos, 'post': postPhotos};
    } catch (e) {
      debugPrint('❌ Failed to get job photos: $e');
      return {'pre': [], 'post': []};
    }
  }

  // ========== TECHNICIAN LOCKING METHODS ==========

  /// Check if the current technician is locked (has a job in progress)
  Future<bool> isTechnicianLocked() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;

      // Check if technician has any job in 'in_progress' or 'accepted' status
      // 'price_pending' does NOT lock the technician anymore
      final jobs = await Supabase.instance.client
          .from('jobs')
          .select('id, status')
          .eq('technician_id', userId)
          .filter('status', 'in', '("in_progress")')
          .limit(1);

      final isLocked = jobs.isNotEmpty;
      debugPrint('🔒 Technician lock status: $isLocked');
      return isLocked;
    } catch (e) {
      debugPrint('⚠️ Failed to check technician lock status: $e');
      return false;
    }
  }

  /// Get the job ID that is locking the technician (if any)
  Future<String?> getLockedJobId() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;

      final jobs = await Supabase.instance.client
          .from('jobs')
          .select('id')
          .eq('technician_id', userId)
          .filter('status', 'in', '("in_progress")')
          .limit(1);

      if (jobs.isEmpty) return null;
      return jobs.first['id'] as String;
    } catch (e) {
      debugPrint('⚠️ Failed to get locked job ID: $e');
      return null;
    }
  }

  /// Watch technician lock status in real-time
  Stream<bool> watchTechnicianLockStatus(String userId) {
    return Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('technician_id', userId)
        .map((data) {
          // Check if any job is in 'in_progress' or 'accepted' status
          // 'price_pending' does NOT lock the technician
          final hasLockedJob = data.any(
            (job) => ['in_progress'].contains(job['status']),
          );
          return hasLockedJob;
        });
  }

  // ========== PAYMENT CONFIRMATION METHODS ==========

  /// Confirm payment and complete the job
  Future<Job> confirmPayment(String jobId, {String? paymentMethod}) async {
    try {
      final response = await _client.post(
        '/jobs/$jobId/confirm-payment',
        data: {'payment_method': paymentMethod},
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        throw Exception(body?['error']?['message'] ?? 'فشل تأكيد الدفع');
      }

      debugPrint('✅ Payment confirmed for job $jobId');
      return Job.fromJson(body['data']);
    } catch (e) {
      if (e is DioException) {
        // Fallback: Update job status directly in Supabase
        try {
          final data = await Supabase.instance.client
              .from('jobs')
              .update({
                'status': 'completed',
                'completed_at': DateTime.now().toIso8601String(),
              })
              .eq('id', jobId)
              .select(
                '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*)',
              )
              .single();

          debugPrint('✅ Payment confirmed via fallback');
          return Job.fromJson(data);
        } catch (dbError) {
          debugPrint('❌ Fallback payment confirmation failed: $dbError');
          rethrow;
        }
      }
      if (e is Exception) rethrow;
      throw Exception('فشل تأكيد الدفع');
    }
  }

  /// Get job with all photos included - returns a record with Job and customer photos
  Future<({Job? job, List<String> customerPhotos})> getJobWithPhotos(
    String jobId,
  ) async {
    try {
      // Get job details with job_images included (from Supabase)
      final data = await Supabase.instance.client
          .from('jobs')
          .select(
            '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*), job_images(id, image_url, media_type)',
          )
          .eq('id', jobId)
          .maybeSingle();

      if (data == null) {
        return (job: null, customerPhotos: <String>[]);
      }

      final job = Job.fromJson(data);

      // Extract customer photos from job_images
      final List<String> customerPhotos = [];
      final jobImagesData = data['job_images'];
      if (jobImagesData != null && jobImagesData is List) {
        for (final img in jobImagesData) {
          final url = img['image_url'] as String?;
          if (url != null && url.isNotEmpty) {
            customerPhotos.add(url);
          }
        }
      }

      debugPrint('📸 Customer photos found: ${customerPhotos.length}');

      return (job: job, customerPhotos: customerPhotos);
    } catch (e) {
      debugPrint('❌ Failed to get job with photos: $e');
      return (job: null, customerPhotos: <String>[]);
    }
  }

  // ========== REAL-TIME STREAM METHODS ==========

  /// Watch all jobs for a user (customer or technician)
  Stream<List<Job>> watchMyJobs(String userId, {bool isTechnician = false}) {
    // Determine column based on user type (handled in service, but we pass flag)
    // Using the centralized service for consistency
    return _realtimeService.streamMyJobs(userId, isTechnician: isTechnician);
  }

  // Stream nearby jobs using the RealtimeService
  // Stream nearby jobs using Reactive Refetch pattern
  // Listens for DB changes -> Triggers RPC -> Yields fresh data
  Stream<List<Job>> watchNearbyJobs({
    required double lat,
    required double lng,
    double radius = 5000,
    String? serviceId,
  }) async* {
    // 1. Initial Fetch
    try {
      final initialJobs = await getNearbyJobsRpc(
        lat: lat,
        lng: lng,
        radiusMeters: radius.toInt(),
        serviceId: serviceId,
      );
      yield initialJobs;
    } catch (e) {
      debugPrint('⚠️ Initial watchNearbyJobs fetch failed: $e');
      yield [];
    }

    // 2. Setup Realtime Subscription via Service
    final changesStream = _realtimeService.streamJobTableChanges();

    // 3. Listen to changes and refetch
    await for (final _ in changesStream) {
      debugPrint('🔔 Realtime update received! Triggering refetch...');
      try {
        final updatedJobs = await getNearbyJobsRpc(
          lat: lat,
          lng: lng,
          radiusMeters: radius.toInt(),
          serviceId: serviceId,
        );
        yield updatedJobs;
      } catch (e) {
        debugPrint('❌ Refetch failed: $e');
      }
    }
  }
}

@Riverpod(keepAlive: true)
JobRepository jobRepository(JobRepositoryRef ref) {
  final client = ref.watch(apiClientProvider);
  final photoService = PhotoUploadService(Supabase.instance.client);
  final workQueue = ref.watch(workQueueServiceProvider);
  // Create SupabaseRealtimeService instance (could be providerified later but acceptable here)
  final realtimeService = SupabaseRealtimeService(Supabase.instance.client);

  return JobRepository(client, photoService, workQueue, realtimeService);
}
