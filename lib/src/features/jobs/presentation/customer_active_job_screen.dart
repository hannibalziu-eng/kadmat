import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../data/job_repository.dart';
import '../domain/job.dart';

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
        if (job.status == 'completed' && job.customerRating == null) {
          context.push('/rate-job/${widget.jobId}');
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
        body: const Center(child: CircularProgressIndicator()),
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
    final status = _job!.status;

    switch (status) {
      case 'pending':
        return _buildSearchingState();
      case 'accepted':
      case 'price_pending':
        return _buildTechnicianFoundState();
      case 'in_progress':
        return _buildInProgressState();
      case 'completed':
        return _buildCompletedState();
      case 'cancelled':
        return _buildCancelledState();
      default:
        return Center(child: Text('حالة غير معروفة: $status'));
    }
  }

  Widget _buildSearchingState() {
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: _job!.status == 'price_pending'
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _job!.status == 'price_pending'
                  ? Icons.receipt_long
                  : Icons.hourglass_empty,
              color: _job!.status == 'price_pending'
                  ? Colors.green
                  : Colors.orange,
              size: 60.s,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            _job!.status == 'price_pending'
                ? 'عرض السعر'
                : 'تم قبول طلبك! ✨',
            style: TextStyle(
              fontSize: 22.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            _job!.status == 'price_pending'
                ? 'الفني قم بتحديد السعر للخدمة - هل تقبل بهذا السعر؟'
                : 'الفني يقوم بتحديد السعر...',
            style: TextStyle(fontSize: 14.fz, color: Colors.white60),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          if (_job!.status == 'price_pending') ...[_buildPriceCard(), SizedBox(height: 24.h)],
          _buildTechnicianInfoCard(),
          SizedBox(height: 32.h),
          if (_job!.status == 'accepted')
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
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
          if (_job!.status == 'price_pending') ...[_buildPriceActionButtons()],
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
          if (_job!.priceNotes != null && _job!.priceNotes!.isNotEmpty) ...[SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
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

    final tech = _job!.technician as Map<String, dynamic>?;
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
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 32.s,
                ),
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
                          '${techRating.toStringAsFixed(1)}',
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
          if (techPhone != null) ...[SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  debugPrint('Call $techPhone');
                },
                icon: const Icon(Icons.phone),
                label: const Text('اتصل بالفني'),
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
          ],
        ],
      ),
    );
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
              color: Colors.blue.withOpacity(0.2),
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
              color: Colors.green.withOpacity(0.2),
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
                  '/tracking/${widget.jobId}',
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
                color: Colors.teal.withOpacity(0.2),
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
                onPressed: () => context.push('/rate-job/${widget.jobId}'),
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
              onPressed: () => context.go('/'),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptPrice() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(jobRepositoryProvider).confirmPrice(widget.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول السعر! الفني في الطريق.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
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
          context.go('/');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
