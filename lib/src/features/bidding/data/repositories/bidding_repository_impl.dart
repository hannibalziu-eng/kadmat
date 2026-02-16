import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:kadmat/src/core/errors/failures.dart';
import 'package:kadmat/src/core/network/rate_limiter.dart';
import 'package:kadmat/src/features/bidding/domain/entities/bid_entity.dart';
import 'package:kadmat/src/features/bidding/domain/entities/dispute_entity.dart';
import 'package:kadmat/src/features/bidding/domain/params/create_dispute_params.dart';
import 'package:kadmat/src/features/bidding/domain/params/create_job_params.dart';
import 'package:kadmat/src/features/bidding/domain/params/submit_bid_params.dart';
import 'package:kadmat/src/features/bidding/domain/repositories/bidding_repository.dart';
import 'package:kadmat/src/features/jobs/domain/job.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@Injectable(as: BiddingRepository)
class BiddingRepositoryImpl implements BiddingRepository {
  final SupabaseClient _supabase;
  final RateLimiter _rateLimiter;

  BiddingRepositoryImpl(this._supabase, this._rateLimiter);

  @override
  Stream<Job> watchJob(String jobId) {
    return _supabase
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .asyncMap((data) async {
          if (data.isEmpty) throw Exception('Job not found');

          try {
            final fullData = await _supabase
                .from('jobs')
                .select('''
                  *,
                  customer:users!customer_id(*),
                  technician:users!technician_id(*),
                  service:services!service_id(*),
                  bids:job_offers(
                    id,
                    job_id,
                    technician_id,
                    amount:price,
                    status,
                    submitted_at:created_at,
                    technician:users!technician_id(*)
                  ),
                  timer:bidding_timers(*),
                  photos:job_photos(*)
                ''')
                .eq('id', jobId)
                .single();

            // Using Job.fromJson directly as Job is the entity
            return Job.fromJson(fullData);
          } catch (e) {
            // Fallback if relations fail or simple fetch
            return Job.fromJson(data.first);
          }
        });
  }

  @override
  Future<Either<Failure, Job>> createJob(CreateJobParams params) async {
    final userId = _supabase.auth.currentUser!.id;
    final rateLimitKey = 'job_create_$userId';

    if (!_rateLimiter.canProceed(rateLimitKey)) {
      final wait = _rateLimiter.timeUntilAllowed(rateLimitKey);
      return Left(
        RateLimitFailure(
          message: 'يمكنك إنشاء طلب جديد بعد ${wait?.inMinutes} دقيقة',
          retryAfter: wait != null ? DateTime.now().add(wait) : null,
        ),
      );
    }

    try {
      final jobData = {
        'customer_id': userId,
        'service_id': params.serviceId,
        'description': params.description,
        'lat': params.latitude,
        'lng': params.longitude,
        'address_text': params.address,
        'max_budget': params.maxBudget,
        'preferred_time': params.preferredTime?.toIso8601String(),
        'status': 'pending', // Default status
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('jobs')
          .insert(jobData)
          .select(
            '*, customer:users!customer_id(*), service:services!service_id(*)',
          )
          .single();

      return Right(Job.fromJson(response));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Job>> acceptBid(String jobId, String bidId) async {
    final userId = _supabase.auth.currentUser!.id;
    final rateLimitKey = 'bid_accept_$userId';

    if (!_rateLimiter.canProceed(rateLimitKey)) {
      final wait = _rateLimiter.timeUntilAllowed(rateLimitKey);
      return Left(
        RateLimitFailure(
          message: 'يرجى الانتظار قليلاً قبل قبول عرض آخر',
          retryAfter: wait != null ? DateTime.now().add(wait) : null,
        ),
      );
    }

    try {
      // Use RPC for safe atomic operation
      final response = await _supabase.rpc(
        'accept_bid_and_lock_job_safe',
        params: {'p_job_id': jobId, 'p_bid_id': bidId, 'p_customer_id': userId},
      );

      if (response == null ||
          (response is Map && response['success'] != true)) {
        // Check if response contains error info
        final msg = (response is Map && response['message'] != null)
            ? response['message']
            : 'تم اختيار فني آخر أو انتهى الوقت';
        return Left(ConflictFailure(message: msg));
      }

      // The RPC might return the updated job data
      // If not, we fetch it
      final jobData = await _supabase
          .from('jobs')
          .select(
            '*, customer:users!customer_id(*), technician:users!technician_id(*), service:services!service_id(*)',
          )
          .eq('id', jobId)
          .single();

      return Right(Job.fromJson(jobData));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> extendTimer(String jobId) async {
    try {
      await _supabase.rpc(
        'extend_bidding_timer',
        params: {
          'p_job_id': jobId,
          'p_minutes': 5, // Default extension
        },
      );
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelJob(
    String jobId,
    CancellationReason reason,
  ) async {
    try {
      await _supabase
          .from('jobs')
          .update({
            'status': 'cancelled',
            'cancel_reason': reason.name,
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancelled_by': _supabase.auth.currentUser!.id,
          })
          .eq('id', jobId);
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Job>>> getNearbyJobs(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_nearby_jobs',
        params: {
          'technician_lat': lat,
          'technician_lng': lng,
          'radius_meters': (radiusKm * 1000).toInt(),
          'limit_count': 50,
        },
      );

      final data = response as List<dynamic>;
      return Right(data.map((e) => Job.fromJson(e)).toList());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, BidEntity>> submitBid(SubmitBidParams params) async {
    final technicianId = _supabase.auth.currentUser!.id;
    final rateLimitKey = 'bid_submit_$technicianId';

    // Check rate limit
    if (!_rateLimiter.canProceed(rateLimitKey)) {
      final wait = _rateLimiter.timeUntilAllowed(rateLimitKey);
      return Left(
        RateLimitFailure(
          message: 'يمكنك تقديم عرض جديد بعد ${wait?.inMinutes} دقيقة',
          retryAfter: wait != null ? DateTime.now().add(wait) : null,
        ),
      );
    }

    try {
      final jobSnapshot = await _supabase
          .from('jobs')
          .select('status, technician_id')
          .eq('id', params.jobId)
          .maybeSingle();

      if (jobSnapshot == null) {
        return const Left(NotFoundFailure(message: 'الطلب غير موجود'));
      }

      final jobStatus = (jobSnapshot['status'] as String?) ?? '';
      final assignedTechnicianId = jobSnapshot['technician_id']?.toString();
      const openStatuses = <String>{
        'pending',
        'searching',
        'no_technician_found',
      };
      final isOpenForBids =
          openStatuses.contains(jobStatus) && assignedTechnicianId == null;
      if (!isOpenForBids) {
        final statusMessage = switch (jobStatus) {
          'cancelled' => 'تم إلغاء الطلب من العميل',
          'in_progress' => 'الطلب بدأ تنفيذه بالفعل',
          'completed' || 'rated' => 'تم إغلاق هذا الطلب',
          _ => 'هذا الطلب لم يعد متاحاً لتقديم عرض',
        };
        return Left(ConflictFailure(message: statusMessage));
      }

      // Check existing bid by this technician (allow updating pending offer).
      final existingOffers = await _supabase
          .from('job_offers')
          .select('id, status')
          .eq('job_id', params.jobId)
          .eq('technician_id', technicianId)
          .eq('is_active', true)
          .limit(1);

      if (existingOffers.isNotEmpty) {
        final existing = Map<String, dynamic>.from(existingOffers.first);
        final existingStatus = (existing['status'] as String?) ?? 'pending';
        if (existingStatus != 'pending') {
          return const Left(
            ConflictFailure(message: 'العرض السابق لم يعد قابلاً للتعديل'),
          );
        }

        final response = await _supabase
            .from('job_offers')
            .update({
              'price': params.amount,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'])
            .select('''
              id,
              job_id,
              technician_id,
              amount:price,
              status,
              submitted_at:created_at,
              technician:users!technician_id(*)
              ''')
            .single();

        return Right(BidEntity.fromJson(response));
      }

      // Check max bids (10)
      final count = await _supabase
          .from('job_offers')
          .count(CountOption.exact)
          .eq('job_id', params.jobId)
          .eq('is_active', true);

      if (count >= 10) {
        return const Left(
          ConflictFailure(message: 'تم بلوغ الحد الأقصى (10 عروض)'),
        );
      }

      // Submit bid
      final response = await _supabase
          .from('job_offers')
          .insert({
            'job_id': params.jobId,
            'technician_id': technicianId,
            'price': params.amount,
          })
          .select('''
            id,
            job_id,
            technician_id,
            amount:price,
            status,
            submitted_at:created_at,
            technician:users!technician_id(*)
            ''')
          .single();

      return Right(BidEntity.fromJson(response));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> acceptWaitlistOffer(String waitlistId) async {
    final userId = _supabase.auth.currentUser!.id;
    final rateLimitKey = 'waitlist_accept_$userId';

    if (!_rateLimiter.canProceed(rateLimitKey)) {
      final wait = _rateLimiter.timeUntilAllowed(rateLimitKey);
      return Left(
        RateLimitFailure(
          message: 'يرجى الانتظار قليلاً',
          retryAfter: wait != null ? DateTime.now().add(wait) : null,
        ),
      );
    }

    try {
      await _supabase.rpc(
        'accept_waitlist_offer',
        params: {'p_waitlist_id': waitlistId, 'p_technician_id': userId},
      );
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> confirmCashPayment(
    String jobId,
    String confirmationCode,
  ) async {
    try {
      await _supabase.rpc(
        'confirm_cash_payment',
        params: {'p_job_id': jobId, 'p_code': confirmationCode},
      );
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DisputeEntity>> createDispute(
    CreateDisputeParams params,
  ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('disputes')
          .insert({
            'job_id': params.jobId,
            'created_by': userId,
            'issue_type': params.disputeType,
            'description': params.description,
            'photo_urls': params.photoUrls,
            'status': 'open',
          })
          .select()
          .single();

      return Right(
        DisputeEntity(
          id: response['id'],
          jobId: response['job_id'],
          raisedBy: response['created_by'],
          disputeType: response['issue_type'] ?? '',
          description: response['description'] ?? '',
          evidencePhotoUrls: List<String>.from(response['photo_urls'] ?? []),
          status: DisputeStatus.values.firstWhere(
            (e) => e.name == (response['status'] ?? 'open'),
            orElse: () => DisputeStatus.open,
          ),
          createdAt: DateTime.parse(response['created_at']),
          updatedAt:
              DateTime.tryParse(response['updated_at'] ?? '') ??
              DateTime.parse(response['created_at']),
          resolvedAt: response['resolved_at'] != null
              ? DateTime.parse(response['resolved_at'])
              : null,
          resolutionNotes: response['resolution_notes'],
        ),
      );
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
