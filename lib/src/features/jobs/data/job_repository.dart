import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/services/photo_upload_service.dart';
import '../../../core/services/offline/work_queue_service.dart';
import '../../../core/realtime/supabase_realtime_service.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/utils/error_messages.dart';

import '../domain/job.dart';
import '../domain/job_visibility_policy.dart';
import '../domain/job_status.dart';

import '../domain/i_job_repository.dart';

part 'job_repository.g.dart';

class JobRepository implements IJobRepository {
  final Dio _client;
  final PhotoUploadService _photoService;
  final WorkQueueService _workQueue;
  final SupabaseRealtimeService _realtimeService;
  static const Set<String> _activeLockStatuses = {
    JobStatus.onTheWay,
    JobStatus.arrived,
    JobStatus.inProgress,
    JobStatus.pendingConfirm,
  };
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[1-5][0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-'
    r'[0-9a-fA-F]{12}$',
  );

  JobRepository(
    this._client,
    this._photoService,
    this._workQueue,
    this._realtimeService,
  );

  String _friendlyJobError(dynamic error, {required String fallback}) {
    if (error is DioException) {
      final apiError = ApiError.fromDioException(error);
      final message = ErrorMessages.fromApiCode(
        apiError.code,
        fallback: apiError.message,
      );
      return message == ErrorMessages.unknownError ? fallback : message;
    }

    final message = ErrorMessages.fromException(error);
    return message == ErrorMessages.unknownError ? fallback : message;
  }

  /// Fetch nearby jobs using Supabase RPC for scalable server-side filtering

  @override
  Future<List<Job>> getNearbyJobsRpc({
    required double lat,
    required double lng,
    int radiusMeters = 10000,
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

      // Filter by serviceId only when it has a valid UUID shape.
      // Some legacy technician profiles can store non-UUID values, and
      // strict filtering in that case hides all requests unexpectedly.
      final normalizedServiceId = serviceId?.trim();
      if (normalizedServiceId != null && normalizedServiceId.isNotEmpty) {
        if (_uuidRegex.hasMatch(normalizedServiceId)) {
          jobs = jobs
              .where((job) => job.serviceId == normalizedServiceId)
              .toList();
        } else {
          debugPrint(
            '⚠️ Skipping service filter. Invalid technician service_id format: $normalizedServiceId',
          );
        }
      }

      // Defensive client-side filtering with centralized policy.
      jobs = JobVisibilityPolicy.filterForTechnicianQueue(jobs);

      if (kDebugMode) {
        debugPrint(
          '📦 Nearby jobs after filter: ${jobs.length} (serviceId=${serviceId ?? 'any'})',
        );
      }

      return jobs;
    } catch (e) {
      debugPrint('❌ Error fetching nearby jobs via RPC: $e');
      // If RPC fails (e.g. function not found during dev), fall back to empty list or throw
      rethrow;
    }
  }

  @override
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
      final apiError = ApiError.fromData(response.data, statusCode: statusCode);
      final errorMessage = apiError.message;
      final errorCode = apiError.code ?? 'UNKNOWN_ERROR';

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

      if (responseData != null) {
        final apiError = ApiError.fromData(
          responseData,
          statusCode: statusCode,
        );
        errorMessage = apiError.message;
        errorCode = apiError.code ?? errorCode;
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
        message: _friendlyJobError(e, fallback: 'فشل إنشاء الطلب'),
        statusCode: 0,
        errorCode: 'UNKNOWN_ERROR',
        originalException: e,
      );
    }
  }

  /// Get a single job by ID with full details

  @override
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

  @override
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

  @override
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

  @override
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
      final apiError = ApiError.fromData(body);
      final code = apiError.code ?? 'UNKNOWN_ERROR';
      final message = apiError.message;
      final currentStatus =
          apiError.detailAsString('currentStatus') ??
          (body['error']?['currentStatus'] as String?);

      switch (code) {
        case 'JOB_ALREADY_ACCEPTED':
          throw JobAlreadyAcceptedException(message);
        case 'INVALID_STATUS_TRANSITION':
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
        final apiError = ApiError.fromDioException(e);
        final errorCode = apiError.code;
        if (errorCode == 'INVALID_STATUS_TRANSITION') {
          final currentStatus = apiError.detailAsString('currentStatus');
          throw InvalidStatusException(
            ErrorMessages.invalidJobStatus,
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
      throw Exception(
        _friendlyJobError(e, fallback: ErrorMessages.jobAcceptFailed),
      );
    }
  }

  @override
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
      throw Exception(_friendlyJobError(e, fallback: 'فشل تحديد السعر'));
    }
  }

  @override
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
                'status': 'on_the_way',
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

  @override
  Future<Job> updateTechnicianProgress(
    String jobId, {
    required String progress,
  }) async {
    final normalized = progress.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('يجب تحديد مرحلة التقدم');
    }

    try {
      final response = await _client.post(
        Endpoints.technicianProgress(jobId),
        data: {'progress': normalized},
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final apiError = ApiError.fromData(
          body,
          statusCode: response.statusCode,
        );
        final message = ErrorMessages.fromApiCode(
          apiError.code,
          fallback: apiError.message,
        );
        throw Exception(message);
      }

      return Job.fromJson(body['data']);
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      final message = ErrorMessages.fromApiCode(
        apiError.code,
        fallback: apiError.message,
      );
      throw Exception(message);
    }
  }

  @override
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
        final apiError = ApiError.fromData(
          body,
          statusCode: response.statusCode,
        );
        throw Exception(
          ErrorMessages.fromApiCode(
            apiError.code,
            fallback: apiError.message.isNotEmpty
                ? apiError.message
                : 'فشل إرسال طلب الإكمال',
          ),
        );
      }
      return Job.fromJson(body['data']);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(_friendlyJobError(e, fallback: 'فشل إرسال طلب الإكمال'));
    }
  }

  @override
  Future<Job> confirmJobCompletion(
    String jobId, {
    String? paymentMethod,
  }) async {
    try {
      final response = await _client.post(
        '/jobs/$jobId/confirm-completion',
        data: paymentMethod != null ? {'payment_method': paymentMethod} : null,
      ); // New endpoint logic

      final body = response.data;
      if (body == null || body['success'] != true) {
        final apiError = ApiError.fromData(
          body,
          statusCode: response.statusCode,
        );
        throw Exception(
          ErrorMessages.fromApiCode(
            apiError.code,
            fallback: apiError.message.isNotEmpty
                ? apiError.message
                : 'فشل تأكيد الإكمال',
          ),
        );
      }
      return Job.fromJson(body['data']);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(_friendlyJobError(e, fallback: 'فشل تأكيد الإكمال'));
    }
  }

  @override
  Future<Job> rateJob(String jobId, int rating, {String? review}) async {
    try {
      final response = await _client.post(
        Endpoints.rateJob(jobId),
        data: {'rating': rating, 'review': review},
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        final apiError = ApiError.fromData(
          body,
          statusCode: response.statusCode,
        );
        throw Exception(
          ErrorMessages.fromApiCode(
            apiError.code,
            fallback: apiError.message.isNotEmpty
                ? apiError.message
                : 'فشل إرسال التقييم',
          ),
        );
      }
      return Job.fromJson(body['data']);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(_friendlyJobError(e, fallback: 'فشل إرسال التقييم'));
    }
  }

  @override
  Future<void> cancelJob(String jobId, {String? reason}) async {
    try {
      final response = await _client.post(
        Endpoints.cancelJob(jobId),
        data: {'reason': reason},
      );

      final body = response.data;
      if (body is Map && body['success'] == false) {
        final apiError = ApiError.fromData(
          body,
          statusCode: response.statusCode,
        );
        final code = apiError.code ?? 'UNKNOWN_ERROR';

        if (code == 'INVALID_STATUS_TRANSITION') {
          throw InvalidStatusException(
            apiError.message.isNotEmpty
                ? apiError.message
                : ErrorMessages.invalidJobStatus,
            currentStatus: apiError.detailAsString('currentStatus'),
          );
        }

        if (code == 'JOB_NOT_FOUND') {
          throw JobNotFoundException(
            apiError.message.isNotEmpty
                ? apiError.message
                : 'لم يتم العثور على الطلب',
          );
        }

        throw Exception(
          apiError.message.isNotEmpty ? apiError.message : 'فشل إلغاء الطلب',
        );
      }
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);

      if (e.response?.statusCode == 400 &&
          apiError.code == 'INVALID_STATUS_TRANSITION') {
        throw InvalidStatusException(
          apiError.message.isNotEmpty
              ? apiError.message
              : ErrorMessages.invalidJobStatus,
          currentStatus: apiError.detailAsString('currentStatus'),
        );
      }

      if (e.response?.statusCode == 404 || apiError.code == 'JOB_NOT_FOUND') {
        throw JobNotFoundException(
          apiError.message.isNotEmpty
              ? apiError.message
              : 'لم يتم العثور على الطلب',
        );
      }

      throw Exception(
        apiError.message.isNotEmpty ? apiError.message : 'فشل إلغاء الطلب',
      );
    } catch (e) {
      if (e is InvalidStatusException || e is JobNotFoundException) {
        rethrow;
      }
      throw Exception('فشل إلغاء الطلب');
    }
  }

  Future<Job?> getJob(String jobId) async {
    try {
      final response = await _client.get('${Endpoints.jobs}/$jobId');
      final body = response.data;
      if (response.statusCode == 200 && body != null && body is Map) {
        final jobData = body['data'] ?? body['job'];
        if (jobData is Map<String, dynamic>) {
          return Job.fromJson(jobData);
        }
        if (jobData is Map) {
          return Job.fromJson(Map<String, dynamic>.from(jobData));
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting job: $e');
      return null;
    }
  }

  @override
  Stream<Job> watchJob(String jobId) {
    return Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .asyncMap((data) async {
          if (data.isEmpty) {
            throw Exception(ErrorMessages.jobNotFound);
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

  @override
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

  /// Submit an offer for a job (Technician)
  Future<void> submitOffer(String jobId, double price) async {
    try {
      final response = await _client.post(
        Endpoints.submitOffer(jobId),
        data: {'price': price},
      );

      final body = response.data;
      if (body is Map && body['success'] == false) {
        final apiError = ApiError.fromData(
          body,
          statusCode: response.statusCode,
        );
        throw Exception(
          apiError.message.isNotEmpty
              ? apiError.message
              : 'تعذر إرسال العرض حالياً',
        );
      }
    } on DioException catch (e) {
      final apiError = ApiError.fromDioException(e);
      final errorCode = apiError.code;
      final message = apiError.message.isNotEmpty
          ? apiError.message
          : 'تعذر إرسال العرض حالياً';

      if (e.response?.statusCode == 404 || errorCode == 'JOB_NOT_FOUND') {
        throw JobNotFoundException(message);
      }

      if (e.response?.statusCode == 409 ||
          errorCode == 'INVALID_STATUS_TRANSITION') {
        throw InvalidStatusException(
          message,
          currentStatus: apiError.detailAsString('currentStatus'),
        );
      }

      if (errorCode == 'JOB_ALREADY_ACCEPTED' ||
          message.contains('accepted by another technician')) {
        throw JobAlreadyAcceptedException(message);
      }

      throw Exception(message);
    } catch (e) {
      if (e is InvalidStatusException ||
          e is JobAlreadyAcceptedException ||
          e is JobNotFoundException) {
        rethrow;
      }
      throw Exception('فشل تقديم العرض');
    }
  }

  /// Accept an offer (Customer)
  Future<Job> acceptOffer(String jobId, String offerId) async {
    final normalizedOfferId = offerId.trim();
    if (normalizedOfferId.isEmpty) {
      throw Exception('معرّف العرض مفقود. حدّث الصفحة وحاول مرة أخرى');
    }

    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidRegex.hasMatch(normalizedOfferId)) {
      throw Exception('معرّف العرض غير صالح. حدّث الصفحة وحاول مرة أخرى');
    }

    try {
      final response = await _client.post(
        Endpoints.acceptOffer(jobId),
        data: {'offerId': normalizedOfferId},
      );

      final body = response.data;
      if (body['success'] == true) {
        return Job.fromJson(body['data']);
      }
      final apiError = ApiError.fromData(body, statusCode: response.statusCode);
      final message = ErrorMessages.fromApiCode(
        apiError.code,
        fallback: apiError.message,
      );
      throw InvalidStatusException(
        message,
        currentStatus: apiError.detailAsString('currentStatus'),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkException(ErrorMessages.connectionTimeout);
      }

      final apiError = ApiError.fromDioException(e);
      final message = ErrorMessages.fromApiCode(
        apiError.code,
        fallback: apiError.message,
      );
      const terminalOrAcceptedStatuses = <String>{
        'accepted',
        'price_pending',
        'on_the_way',
        'arrived',
        'in_progress',
        'pending_confirm',
        'completed',
        'rated',
      };

      if (e.response?.statusCode == 404 ||
          apiError.code == 'JOB_NOT_FOUND' ||
          apiError.code == 'NOT_FOUND') {
        throw JobNotFoundException(message);
      }

      if (e.response?.statusCode == 409 ||
          apiError.code == 'INVALID_STATUS_TRANSITION' ||
          apiError.code == 'CONFLICT') {
        final currentStatus = apiError.detailAsString('currentStatus');

        // Race-safe behavior:
        // if backend reports a transition conflict but job has already advanced,
        // treat acceptance as succeeded and return latest job snapshot.
        if (currentStatus != null &&
            terminalOrAcceptedStatuses.contains(
              currentStatus.toLowerCase().trim(),
            )) {
          try {
            final latest = await getJobById(jobId);
            if (latest != null) return latest;
          } catch (_) {
            // Fall through to explicit InvalidStatusException below.
          }
        }

        throw InvalidStatusException(message, currentStatus: currentStatus);
      }

      // Additional race-safe handling:
      // backend can return 500/ACCEPT_FAILED while assignment actually succeeded
      // (e.g. post-assignment side effect failure or transient DB issue).
      final isPotentialServerRace =
          e.response?.statusCode == 500 ||
          apiError.code == 'SERVER_ERROR' ||
          apiError.code == 'ACCEPT_FAILED';
      if (isPotentialServerRace) {
        try {
          final latest = await getJobById(jobId);
          final normalizedLatestStatus = latest?.status.toLowerCase().trim();
          final technicianId = latest?.technicianId;
          final hasAssignedTechnician =
              technicianId != null && technicianId.isNotEmpty;
          if (latest != null &&
              hasAssignedTechnician &&
              normalizedLatestStatus != null &&
              terminalOrAcceptedStatuses.contains(normalizedLatestStatus)) {
            return latest;
          }
        } catch (_) {
          // Keep original backend error message below.
        }
      }

      throw Exception(message.isNotEmpty ? message : 'فشل قبول العرض');
    } catch (e) {
      if (e is JobNotFoundException ||
          e is InvalidStatusException ||
          e is NetworkException) {
        rethrow;
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('تعذر قبول العرض حالياً');
    }
  }

  /// Watch offers for a specific job (Customer)
  Stream<List<Map<String, dynamic>>> watchJobOffers(String jobId) {
    return Supabase.instance.client
        .from('job_offers')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('price', ascending: true) // Best price first
        .asyncMap((offers) async {
          final pendingActiveOffers = offers.where((offer) {
            final status = offer['status']?.toString();
            final isActive = offer['is_active'] == true;
            return status == 'pending' && isActive;
          }).toList();

          final technicianIds = pendingActiveOffers
              .map((offer) => offer['technician_id']?.toString().trim() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
          final techniciansById = await _loadOfferTechnicians(technicianIds);
          final enrichedOffers = <Map<String, dynamic>>[];

          for (final offer in pendingActiveOffers) {
            try {
              final technicianId =
                  offer['technician_id']?.toString().trim() ?? '';
              final tech = techniciansById[technicianId];

              enrichedOffers.add({
                ...offer,
                'technician': tech ?? const <String, dynamic>{},
              });
            } catch (e) {
              debugPrint('⚠️ Failed to enrich offer ${offer['id']}: $e');
              // Keep basic offer visible even if technician enrich fails.
              enrichedOffers.add({...offer, 'technician': const {}});
            }
          }
          return enrichedOffers;
        });
  }

  Future<Map<String, Map<String, dynamic>>> _loadOfferTechnicians(
    List<String> technicianIds,
  ) async {
    if (technicianIds.isEmpty) {
      return const {};
    }

    final technicians = await _fetchOfferTechnicians(technicianIds);
    final completedJobsByTechnician = await _fetchCompletedJobsByTechnician(
      technicianIds,
    );
    final mapped = <String, Map<String, dynamic>>{};

    for (final row in technicians) {
      final technicianId = row['id']?.toString().trim() ?? '';
      if (technicianId.isEmpty) {
        continue;
      }

      mapped[technicianId] = {
        ...row,
        'specialization': _extractServiceName(row['service']),
        'location': _displayLocation(row['address'], row['location']),
        'completed_jobs': completedJobsByTechnician[technicianId] ?? 0,
      };
    }

    return mapped;
  }

  Future<List<Map<String, dynamic>>> _fetchOfferTechnicians(
    List<String> technicianIds,
  ) async {
    try {
      final rows = await Supabase.instance.client
          .from('users')
          .select(
            'id, full_name, rating, profile_image_url, title, address, location, service:service_id(name_ar)',
          )
          .inFilter('id', technicianIds)
          .eq('user_type', 'technician');

      return (rows as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (error) {
      debugPrint('⚠️ Rich technician offer lookup failed: $error');
      final fallbackRows = await Supabase.instance.client
          .from('users')
          .select('id, full_name, rating, profile_image_url, title, address')
          .inFilter('id', technicianIds)
          .eq('user_type', 'technician');

      return (fallbackRows as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
  }

  Future<Map<String, int>> _fetchCompletedJobsByTechnician(
    List<String> technicianIds,
  ) async {
    try {
      final rows = await Supabase.instance.client
          .from('jobs')
          .select('technician_id')
          .inFilter('technician_id', technicianIds)
          .filter('status', 'in', '("completed","rated")');

      final counts = <String, int>{};
      for (final row in (rows as List).whereType<Map>()) {
        final technicianId = row['technician_id']?.toString().trim() ?? '';
        if (technicianId.isEmpty) {
          continue;
        }
        counts.update(technicianId, (value) => value + 1, ifAbsent: () => 1);
      }
      return counts;
    } catch (error) {
      debugPrint('⚠️ Completed jobs enrichment failed: $error');
      return const {};
    }
  }

  String _extractServiceName(Object? rawService) {
    if (rawService is Map) {
      final serviceName = rawService['name_ar']?.toString().trim();
      if (serviceName != null && serviceName.isNotEmpty) {
        return serviceName;
      }
    }

    if (rawService is List && rawService.isNotEmpty) {
      final first = rawService.first;
      if (first is Map) {
        final serviceName = first['name_ar']?.toString().trim();
        if (serviceName != null && serviceName.isNotEmpty) {
          return serviceName;
        }
      }
    }

    return 'فني خدمات عامة';
  }

  String? _displayLocation(Object? address, Object? location) {
    final addressText = address?.toString().trim();
    if (addressText != null && addressText.isNotEmpty) {
      return addressText;
    }

    final locationText = location?.toString().trim();
    if (locationText == null || locationText.isEmpty) {
      return null;
    }

    final normalized = locationText.toUpperCase();
    if (normalized.contains('POINT(') || normalized.contains('SRID=')) {
      return null;
    }

    return locationText;
  }

  @override
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

  @override
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

  @override
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

  @override
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

      // Lock when the technician has an active assigned job.
      final jobs = await Supabase.instance.client
          .from('jobs')
          .select('id, status')
          .eq('technician_id', userId)
          .filter(
            'status',
            'in',
            '("on_the_way","arrived","in_progress","pending_confirm")',
          )
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
          .filter(
            'status',
            'in',
            '("on_the_way","arrived","in_progress","pending_confirm")',
          )
          .limit(1);

      if (jobs.isEmpty) return null;
      return jobs.first['id'] as String;
    } catch (e) {
      debugPrint('⚠️ Failed to get locked job ID: $e');
      return null;
    }
  }

  /// Watch technician lock status in real-time

  @override
  Stream<bool> watchTechnicianLockStatus(String userId) {
    return Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('technician_id', userId)
        .map((data) {
          // Lock stream follows active in-service statuses.
          final hasLockedJob = data.any(
            (job) => _activeLockStatuses.contains(
              JobStatus.normalize((job['status'] ?? '').toString()),
            ),
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
    late StreamController<List<Job>> controller;
    StreamSubscription<List<Job>>? realtimeJobsSubscription;
    StreamSubscription<void>? changeSubscription;
    Timer? pollingTimer;

    var isRefreshing = false;
    var lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);

    Future<void> refreshJobs({bool force = false}) async {
      if (controller.isClosed || isRefreshing) return;
      if (!force &&
          DateTime.now().difference(lastRefresh) < const Duration(seconds: 2)) {
        return;
      }

      isRefreshing = true;
      try {
        final jobs = await getMyJobs();
        if (!controller.isClosed) {
          controller.add(jobs);
        }
        lastRefresh = DateTime.now();
      } catch (e) {
        debugPrint('⚠️ watchMyJobs refresh failed: $e');
      } finally {
        isRefreshing = false;
      }
    }

    controller = StreamController<List<Job>>(
      onListen: () async {
        // Initial snapshot from HTTP avoids hard dependency on realtime handshake.
        await refreshJobs(force: true);

        // Fast path: realtime my-jobs stream. If it times out, polling still works.
        realtimeJobsSubscription = _realtimeService
            .streamMyJobs(userId, isTechnician: isTechnician)
            .listen(
              (jobs) {
                if (!controller.isClosed) {
                  controller.add(jobs);
                }
                lastRefresh = DateTime.now();
              },
              onError: (Object error, StackTrace stackTrace) {
                debugPrint(
                  '⚠️ watchMyJobs realtime stream failed, fallback to polling: $error',
                );
              },
            );

        // Change notifications trigger immediate refetch when available.
        changeSubscription = _realtimeService.streamJobTableChanges().listen(
          (_) => refreshJobs(),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('⚠️ watchMyJobs change-stream error: $error');
          },
        );

        // Hard fallback path to keep dashboard fresh even when realtime is unstable.
        pollingTimer = Timer.periodic(
          const Duration(seconds: 10),
          (_) => refreshJobs(),
        );
      },
      onCancel: () async {
        await realtimeJobsSubscription?.cancel();
        await changeSubscription?.cancel();
        pollingTimer?.cancel();
      },
    );

    return controller.stream;
  }

  // Stream nearby jobs using the RealtimeService
  // Stream nearby jobs using Reactive Refetch pattern
  // Listens for DB changes -> Triggers RPC -> Yields fresh data
  Stream<List<Job>> watchNearbyJobs({
    required double lat,
    required double lng,
    double radius = 10000,
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

    // 2. Setup trigger stream driven by realtime events + periodic polling
    final triggerController = StreamController<void>();
    StreamSubscription<void>? realtimeSubscription;
    Timer? pollingTimer;

    void triggerRefetch() {
      if (!triggerController.isClosed) {
        triggerController.add(null);
      }
    }

    realtimeSubscription = _realtimeService.streamJobTableChanges().listen(
      (_) => triggerRefetch(),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('⚠️ Realtime change stream error: $error');
      },
    );

    pollingTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => triggerRefetch(),
    );

    // 3. Consume triggers and refetch with throttling
    DateTime lastFetchTime = DateTime.now();

    try {
      await for (final _ in triggerController.stream) {
        // Throttle: Max 1 fetch every 2 seconds to prevent flooding
        if (DateTime.now().difference(lastFetchTime) <
            const Duration(seconds: 2)) {
          continue;
        }

        lastFetchTime = DateTime.now();
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
    } finally {
      await realtimeSubscription.cancel();
      pollingTimer.cancel();
      await triggerController.close();
    }
  }
}

@Riverpod(keepAlive: true)
JobRepository jobRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  final photoService = PhotoUploadService(Supabase.instance.client);
  final workQueue = ref.watch(workQueueServiceProvider);
  // Create SupabaseRealtimeService instance (could be providerified later but acceptable here)
  final realtimeService = SupabaseRealtimeService(Supabase.instance.client);

  return JobRepository(client, photoService, workQueue, realtimeService);
}
