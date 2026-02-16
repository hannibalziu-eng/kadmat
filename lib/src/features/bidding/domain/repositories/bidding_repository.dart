import 'package:dartz/dartz.dart';
import 'package:kadmat/src/core/errors/failures.dart';
import 'package:kadmat/src/features/bidding/domain/entities/bid_entity.dart';
import 'package:kadmat/src/features/bidding/domain/entities/dispute_entity.dart';
import 'package:kadmat/src/features/bidding/domain/params/create_dispute_params.dart';
import 'package:kadmat/src/features/bidding/domain/params/create_job_params.dart';
import 'package:kadmat/src/features/bidding/domain/params/submit_bid_params.dart';
import 'package:kadmat/src/features/jobs/domain/job.dart';

enum CancellationReason {
  foundAnotherTechnician,
  changedMind,
  tooExpensive,
  other,
}

abstract class BiddingRepository {
  // Watch job real-time updates
  Stream<Job> watchJob(String jobId);

  // Customer actions
  Future<Either<Failure, Job>> createJob(CreateJobParams params);
  Future<Either<Failure, Job>> acceptBid(String jobId, String bidId);
  Future<Either<Failure, void>> extendTimer(String jobId);
  Future<Either<Failure, void>> cancelJob(
    String jobId,
    CancellationReason reason,
  );

  // Technician actions
  Future<Either<Failure, List<Job>>> getNearbyJobs(
    double lat,
    double lng,
    double radiusKm,
  );
  Future<Either<Failure, BidEntity>> submitBid(SubmitBidParams params);
  Future<Either<Failure, void>> acceptWaitlistOffer(String waitlistId);

  // Payment
  Future<Either<Failure, void>> confirmCashPayment(
    String jobId,
    String confirmationCode,
  );

  // Disputes
  Future<Either<Failure, DisputeEntity>> createDispute(
    CreateDisputeParams params,
  );
}
