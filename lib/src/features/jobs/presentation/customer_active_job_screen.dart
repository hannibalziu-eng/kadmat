import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/kadmat_toast.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/shimmer_skeletons.dart';
import '../data/job_repository.dart';
import '../domain/job.dart';
import '../domain/job_status.dart';

class CustomerActiveJobScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerActiveJobScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerActiveJobScreen> createState() =>
      _CustomerActiveJobScreenState();
}

class _CustomerActiveJobScreenState
    extends ConsumerState<CustomerActiveJobScreen> {
  StreamSubscription? _jobSubscription;
  Job? _job;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final jobRepo = ref.read(jobRepositoryProvider);
    _jobSubscription = jobRepo.watchJob(widget.jobId).listen((job) {
      if (mounted) {
        setState(() => _job = job);
        if (JobStatus.normalize(job.status) == JobStatus.completed &&
            job.customerRating == null) {
          context.push(AppRoutes.buildCustomerRatePath(widget.jobId));
        }
      }
    });
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_job == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(title: const Text('طلبك')),
        body: const DetailSkeleton(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(_job!.service?['name'] ?? 'طلبك'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    final status = JobStatus.normalize(_job!.status);

    switch (status) {
      case JobStatus.pending:
      case JobStatus.searching:
        return _buildSearchingState();
      case JobStatus.noTechnicianFound:
        // If technician was assigned after no_technician_found, show found state
        if (_job!.technicianId != null) {
          return _buildTechnicianFoundState();
        }
        return _buildNoTechnicianFoundState();
      case JobStatus.accepted:
      case JobStatus.pricePending:
        return _buildTechnicianFoundState();
      case JobStatus.inProgress:
        return _buildInProgressState();
      case JobStatus.pendingConfirm:
        return _buildPaymentPendingState();
      case JobStatus.completed:
        return _buildCompletedState();
      case JobStatus.cancelled:
        return _buildCancelledState();
      default:
        // Fallback: if technician is assigned, show found state
        if (_job!.technicianId != null) {
          return _buildTechnicianFoundState();
        }
        return Center(child: Text('حالة غير معروفة: $status'));
    }
  }

  Widget _buildSearchingState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.buildCustomerSearchingPath(widget.jobId));
    });
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100.w,
              height: 100.w,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: 32.h),
            Text(
              'جاري البحث عن فني...',
              style: TextStyle(
                fontSize: 20.fz,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'سيتم إعلامك عند قبول فني للطلب',
              style: TextStyle(fontSize: 14.fz, color: Colors.white60),
            ),
            SizedBox(height: 32.h),
            TextButton.icon(
              onPressed: _cancelJob,
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text(
                'إلغاء الطلب',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianFoundState() {
    final status = JobStatus.normalize(_job!.status);
    final hasLockedOfferPrice =
        status == JobStatus.accepted && _job!.technicianPrice != null;
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: status == JobStatus.pricePending
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              status == JobStatus.pricePending
                  ? Icons.receipt_long
                  : Icons.hourglass_empty,
              color: status == JobStatus.pricePending
                  ? Colors.green
                  : Colors.orange,
              size: 60.s,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            status == JobStatus.pricePending
                ? 'عرض السعر'
                : hasLockedOfferPrice
                ? 'تم تثبيت السعر من العرض ✅'
                : 'تم قبول طلبك! ✨',
            style: TextStyle(
              fontSize: 22.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            status == JobStatus.pricePending
                ? 'الفني قم بتحديد السعر للخدمة - هل تقبل بهذا السعر؟'
                : hasLockedOfferPrice
                ? 'تم قبول عرض الفني بالسعر المتفق عليه، يمكنك متابعة التنفيذ.'
                : 'الفني يقوم بتحديد السعر...',
            style: TextStyle(fontSize: 14.fz, color: Colors.white60),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          if (status == JobStatus.pricePending) ...[
            _buildPriceCard(),
            SizedBox(height: 24.h),
          ],
          _buildTechnicianInfoCard(),
          SizedBox(height: 32.h),
          if (status == JobStatus.accepted && !hasLockedOfferPrice)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.orange),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'يتم حالياً انتظار تحديد السعر من الفني',
                      style: TextStyle(
                        fontSize: 14.fz,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (hasLockedOfferPrice) ...[
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(
                  AppRoutes.buildCustomerInProgressPath(widget.jobId),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('متابعة التنفيذ'),
              ),
            ),
          ],
          if (status == JobStatus.pricePending) ...[_buildPriceActionButtons()],
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: AppTheme.glassDecoration(radius: 20.r),
      child: Column(
        children: [
          Text(
            '${_job!.technicianPrice ?? 0}',
            style: TextStyle(
              fontSize: 56.fz,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          Text(
            'ريال',
            style: TextStyle(fontSize: 18.fz, color: Colors.white60),
          ),
          if (_job!.priceNotes != null && _job!.priceNotes!.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                'ملاحظات: ${_job!.priceNotes!}',
                style: TextStyle(fontSize: 13.fz, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : _rejectPrice,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text(
              'رفض وابحث عن آخر',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _acceptPrice,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 16.w,
                    height: 16.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text(
                    'قبول',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicianInfoCard() {
    if (_job?.technicianId == null) return const SizedBox.shrink();

    final tech = _job!.technician;
    final techName = tech?['full_name'] ?? 'فني محترف';
    final techPhone = tech?['phone'];
    final techRating = (tech?['rating'] as num?)?.toDouble() ?? 5.0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(radius: 16.r),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32.r,
                backgroundColor: AppTheme.primaryColor,
                child: Icon(Icons.person, color: Colors.white, size: 32.s),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الفني المُختص',
                      style: TextStyle(
                        fontSize: 12.fz,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      techName,
                      style: TextStyle(
                        fontSize: 18.fz,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < techRating.toInt()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 14.s,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          techRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12.fz,
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (techPhone != null) ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      debugPrint('📞 Call $techPhone');
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('اتصل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push(
                        AppRoutes.buildJobChatPath(widget.jobId),
                        extra: {
                          'otherUserId': _job!.technicianId,
                          'otherUserName': techName,
                        },
                      );
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('مراسلة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  debugPrint(
                    '👨‍💼 View technician profile: ${_job!.technicianId}',
                  );
                  final technicianId = _job!.technicianId;
                  if (technicianId == null || technicianId.isEmpty) return;
                  _openTechnicianProfile(technicianId);
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('البروفايل'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openTechnicianProfile(String technicianId) {
    final normalizedId = technicianId.trim();
    if (normalizedId.isEmpty || normalizedId == 'null') {
      KadmatToast.showWarning(
        context,
        title: 'تعذر فتح الملف',
        message: 'معرّف الفني غير صالح',
      );
      return;
    }

    try {
      context.push(AppRoutes.buildTechnicianProfilePath(normalizedId));
    } catch (_) {
      KadmatToast.showError(
        context,
        title: 'تعذر فتح الملف',
        message: 'فشل الانتقال إلى ملف الفني. حاول مجددًا.',
      );
    }
  }

  Widget _buildInProgressState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.engineering, color: Colors.blue, size: 60.s),
          ),
          SizedBox(height: 24.h),
          Text(
            'الفني في الطريق! 🚗',
            style: TextStyle(
              fontSize: 22.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'سيصل قريباً لتنفيذ الخدمة',
            style: TextStyle(fontSize: 16.fz, color: Colors.white60),
          ),
          SizedBox(height: 32.h),
          _buildTechnicianInfoCard(),
          SizedBox(height: 24.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20.s),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'السعر المتفق عليه: ${_job!.technicianPrice ?? 0} ريال',
                    style: TextStyle(
                      fontSize: 16.fz,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push(
                  AppRoutes.buildTrackingPath(widget.jobId),
                  extra: {
                    'technicianId': _job!.technicianId,
                    'lat': _job!.lat,
                    'lng': _job!.lng,
                  },
                );
              },
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text(
                'تتبع الفني على الخريطة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32.w),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.done_all, color: Colors.teal, size: 60.s),
            ),
            SizedBox(height: 24.h),
            Text(
              'تم إكمال الخدمة! 🎉',
              style: TextStyle(
                fontSize: 22.fz,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 32.h),
            if (_job!.customerRating == null)
              ElevatedButton(
                onPressed: () =>
                    context.push(AppRoutes.buildCustomerRatePath(widget.jobId)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: EdgeInsets.symmetric(
                    horizontal: 32.w,
                    vertical: 16.h,
                  ),
                ),
                child: const Text(
                  'قيّم الخدمة ⭐',
                  style: TextStyle(color: Colors.black),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < (_job!.customerRating ?? 0)
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 32.s,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 80.s),
            SizedBox(height: 24.h),
            Text(
              'تم إلغاء الطلب',
              style: TextStyle(
                fontSize: 22.fz,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTechnicianFoundState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32.w),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off, color: Colors.orange, size: 60.s),
            ),
            SizedBox(height: 24.h),
            Text(
              'لم نجد فني متاح حالياً 😔',
              style: TextStyle(
                fontSize: 22.fz,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'ما زلنا نبحث...\nسيتم إعلامك فور توفر فني',
              style: TextStyle(fontSize: 14.fz, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: 24.w,
              height: 24.h,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 32.h),
            TextButton.icon(
              onPressed: _cancelJob,
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text(
                'إلغاء الطلب',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentPendingState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payment, color: Colors.purple, size: 60.s),
          ),
          SizedBox(height: 24.h),
          Text(
            'انتظار تأكيد الإكمال 📝',
            style: TextStyle(
              fontSize: 22.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'الفني أنهى العمل - يُرجى التأكيد',
            style: TextStyle(fontSize: 16.fz, color: Colors.white60),
          ),
          SizedBox(height: 32.h),
          _buildTechnicianInfoCard(),
          SizedBox(height: 24.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20.s),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'السعر: ${_job!.technicianPrice ?? _job!.finalPrice ?? 0} ريال',
                    style: TextStyle(
                      fontSize: 16.fz,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.push(
                  AppRoutes.buildCustomerConfirmCompletionPath(widget.jobId),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: const Text(
                'تأكيد إكمال الخدمة ✓',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptPrice() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(jobRepositoryProvider).confirmPrice(widget.jobId);
      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'تم قبول السعر',
          message: '✅ الفني في الطريق إليك!',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectPrice() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('رفض السعر', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل تريد البحث عن فني آخر؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، ابحث عن آخر'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(jobRepositoryProvider)
            .cancelJob(widget.jobId, reason: 'رفض السعر');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('جاري البحث عن فني آخر...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.handle(context, e);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelJob() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('إلغاء الطلب', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من إلغاء الطلب؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await ref.read(jobRepositoryProvider).cancelJob(widget.jobId);
        if (mounted) {
          context.go(AppRoutes.home);
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.handle(context, e);
        }
      }
    }
  }
}
