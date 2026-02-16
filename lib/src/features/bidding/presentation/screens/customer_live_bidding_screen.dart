import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:kadmat/src/core/app_theme.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/core/navigation/job_flow_redirects.dart';
import 'package:kadmat/src/core/widgets/kadmat_toast.dart';
import 'package:kadmat/src/core/exceptions/app_exceptions.dart';
import 'package:kadmat/src/features/bidding/domain/entities/bid_entity.dart';
import 'package:kadmat/src/features/bidding/presentation/providers/bidding_providers.dart';
import 'package:kadmat/src/features/bidding/presentation/widgets/bid_card.dart';
import 'package:kadmat/src/features/bidding/presentation/widgets/wave_indicator.dart';
import 'package:kadmat/src/features/jobs/data/job_repository.dart';
import 'package:kadmat/src/features/jobs/domain/job.dart';

class CustomerLiveBiddingScreen extends ConsumerStatefulWidget {
  final String jobId;
  const CustomerLiveBiddingScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerLiveBiddingScreen> createState() =>
      _CustomerLiveBiddingScreenState();
}

class _CustomerLiveBiddingScreenState
    extends ConsumerState<CustomerLiveBiddingScreen> {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  bool _isValidUuid(String value) => _uuidRegex.hasMatch(value.trim());

  @override
  Widget build(BuildContext context) {
    final jobStream = ref.watch(jobStreamProvider(widget.jobId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('العروض الحالية'),
        centerTitle: true,
      ),
      body: jobStream.when(
        data: (job) {
          if (job == null) {
            return const Center(child: Text('الطلب غير موجود'));
          }

          // If job moved beyond searching, redirect to the right customer stage.
          final route = customerRouteForJobStatus(
            status: job.status,
            jobId: widget.jobId,
          );
          if (route != null) {
            // Use Microtask to avoid build errors
            Future.microtask(() {
              if (!context.mounted) return;
              context.go(route);
            });
          }

          final bids = job.bids ?? [];

          // Calculate bid rankings
          final cheapestBid = bids.isNotEmpty
              ? bids.reduce((a, b) => a.amount < b.amount ? a : b)
              : null;
          final fastestBid = bids.isNotEmpty
              ? bids.reduce(
                  (a, b) =>
                      (a.estimatedDurationMinutes ?? 999999) <
                          (b.estimatedDurationMinutes ?? 999999)
                      ? a
                      : b,
                )
              : null;
          final highestRatedBid = bids.isNotEmpty
              ? bids.reduce((a, b) => a.rating > b.rating ? a : b)
              : null;

          return Column(
            children: [
              // Wave Animation & Job Status
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: WaveIndicator(
                  currentWave: job.currentWave,
                  isSearching:
                      job.status == 'searching' || job.status == 'pending',
                ),
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  'جاري البحث عن فنيين...',
                  style: TextStyle(color: Colors.white70, fontSize: 14.fz),
                ),
              ),

              SizedBox(height: 10.h),

              Expanded(
                child: bids.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.hourglass_empty,
                              size: 50.s,
                              color: Colors.white24,
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              'لا توجد عروض حتى الآن',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16.fz,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: bids.length,
                        itemBuilder: (context, index) {
                          final bid = bids[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: BidCard(
                              bid: bid,
                              isCheapest: bid.id == cheapestBid?.id,
                              isFastest: bid.id == fastestBid?.id,
                              isHighestRated: bid.id == highestRatedBid?.id,
                              onAccept: () => _acceptBid(bid),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        error: (err, st) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _acceptBid(BidEntity bid) async {
    final bidId = bid.id.trim();
    if (!_isValidUuid(bidId)) {
      if (!mounted) return;
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'معرّف العرض غير صالح، حدّث الشاشة وحاول مجددًا',
      );
      return;
    }

    try {
      final updatedJob = await ref
          .read(jobRepositoryProvider)
          .acceptOffer(widget.jobId, bidId);
      if (!mounted) return;
      KadmatToast.showSuccess(
        context,
        title: 'مبروك',
        message: 'تم قبول العرض بنجاح',
      );
      final route = customerRouteForJobStatus(
        status: updatedJob.status,
        jobId: widget.jobId,
      );
      context.go(route ?? AppRoutes.buildCustomerInProgressPath(widget.jobId));
    } on InvalidStatusException catch (e) {
      if (!mounted) return;
      KadmatToast.showWarning(
        context,
        title: 'العرض لم يعد متاحًا',
        message: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      try {
        final latest = await ref
            .read(jobRepositoryProvider)
            .getJobById(widget.jobId);
        if (!mounted) return;
        if (latest != null &&
            latest.technicianId != null &&
            latest.technicianId!.isNotEmpty) {
          final route = customerRouteForJobStatus(
            status: latest.status,
            jobId: widget.jobId,
          );
          context.go(
            route ?? AppRoutes.buildCustomerInProgressPath(widget.jobId),
          );
          return;
        }
      } catch (_) {}

      if (!mounted) return;
      KadmatToast.showError(context, title: 'خطأ', message: 'تعذر قبول العرض');
    }
  }
}

// Provider for Job Stream
final jobStreamProvider = StreamProvider.family<Job?, String>((ref, jobId) {
  return ref.watch(biddingRepositoryProvider).watchJob(jobId);
});
