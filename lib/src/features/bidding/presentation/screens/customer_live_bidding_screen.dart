import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:kadmat/src/core/design/kadmat_tokens.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/core/navigation/job_flow_redirects.dart';
import 'package:kadmat/src/core/utils/error_handler.dart';
import 'package:kadmat/src/core/widgets/kadmat_toast.dart';
import 'package:kadmat/src/core/widgets/kadmat_components.dart';
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
      backgroundColor: const Color(0xFFF2F6F7),
      appBar: AppBar(title: const Text('العروض الحالية'), centerTitle: true),
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

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
                        children: [
                          _buildHeroCard(
                            title: bids.isEmpty
                                ? 'جارٍ انتظار أول عرض'
                                : 'وصلت عروض جديدة على طلبك',
                            subtitle: bids.isEmpty
                                ? 'اترك الطلب نشطًا وسنضيف العروض هنا فور وصولها. لا تحتاج الآن إلى أي إجراء سوى المتابعة أو الإلغاء إذا لم تعد بحاجة للخدمة.'
                                : 'قارن العروض بهدوء ثم اختر فنيًا واحدًا فقط. ركّز على السعر، التقييم، والمدة بدل التنقل بين شاشات متعددة.',
                          ),
                          SizedBox(height: 16.h),
                          _buildFocusCard(
                            title: 'الخطوة التالية',
                            description: bids.isEmpty
                                ? 'انتظر حتى يظهر أول عرض. ستتحدث هذه الشاشة تلقائيًا دون الحاجة إلى التحديث اليدوي.'
                                : 'راجع البطاقات الظاهرة ثم اقبل العرض الأنسب مباشرة من نفس الشاشة.',
                          ),
                          SizedBox(height: 16.h),
                          Center(
                            child: WaveIndicator(
                              currentWave: job.currentWave,
                              isSearching:
                                  job.status == 'searching' ||
                                  job.status == 'pending',
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            bids.isEmpty
                                ? 'لم يصل أي عرض بعد'
                                : 'عدد العروض الحالية: ${bids.length}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: KadmatColors.lightTextSecondary,
                              fontSize: 12.8.fz,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          if (bids.isEmpty)
                            _buildStateSurface(
                              icon: Icons.hourglass_empty_rounded,
                              title: 'لا توجد عروض حتى الآن',
                              subtitle:
                                  'بمجرد وصول أول عرض سيظهر هنا مع السعر والتقييم والمدة المقترحة.',
                            )
                          else
                            ...bids.map((bid) {
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
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        error: (err, st) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _buildStateSurface(
                icon: Icons.error_outline_rounded,
                title: 'تعذر تحميل العروض الحالية',
                subtitle: ErrorHandler.getMessage(err),
                action: KadmatPrimaryButton(
                  label: 'إعادة المحاولة',
                  icon: Icons.refresh_rounded,
                  onPressed: () =>
                      ref.invalidate(jobStreamProvider(widget.jobId)),
                ),
              ),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildHeroCard({required String title, required String subtitle}) {
    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF17313B), Color(0xFF0D1E25)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              Icons.local_offer_outlined,
              color: Colors.white,
              size: 26.s,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13.fz,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusCard({required String title, required String description}) {
    return _buildStateSurface(
      icon: Icons.track_changes_outlined,
      title: title,
      subtitle: description,
    );
  }

  Widget _buildStateSurface({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: KadmatColors.brandAccent,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: KadmatColors.brandSecondary, size: 22.s),
          ),
          SizedBox(height: 14.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KadmatColors.lightTextPrimary,
              fontSize: 15.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KadmatColors.lightTextSecondary,
              fontSize: 12.6.fz,
              height: 1.55,
            ),
          ),
          if (action != null) ...[SizedBox(height: 16.h), action],
        ],
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
