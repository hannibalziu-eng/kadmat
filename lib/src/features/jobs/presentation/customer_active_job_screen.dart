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
        // Navigate to rating if completed
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
        return _buildAcceptedState();
      case 'price_pending':
        return _buildPriceConfirmation();
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

  Widget _buildAcceptedState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: Colors.green, size: 60.s),
            ),
            SizedBox(height: 24.h),
            Text(
              'تم قبول طلبك! ✨',
              style: TextStyle(
                fontSize: 22.fz,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'الفني يقوم بتحديد السعر...',
              style: TextStyle(fontSize: 16.fz, color: Colors.white60),
            ),
            SizedBox(height: 24.h),
            _buildTechnicianInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceConfirmation() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 60.s),
          SizedBox(height: 24.h),
          Text(
            'عرض السعر',
            style: TextStyle(
              fontSize: 22.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 32.h),

          // Price Card
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: AppTheme.glassDecoration(radius: 20.r),
            child: Column(
              children: [
                Text(
                  '${_job!.technicianPrice ?? 0}',
                  style: TextStyle(
                    fontSize: 48.fz,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  'ريال',
                  style: TextStyle(fontSize: 18.fz, color: Colors.white60),
                ),
                if (_job!.priceNotes != null &&
                    _job!.priceNotes!.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  Text(
                    _job!.priceNotes!,
                    style: TextStyle(fontSize: 14.fz, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Technician Info
          _buildTechnicianInfo(),
          SizedBox(height: 32.h),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _rejectPrice,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                  ),
                  child: const Text('رفض'),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _acceptPrice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('قبول السعر'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            _buildTechnicianInfo(),
            SizedBox(height: 24.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_money, color: Colors.green),
                  SizedBox(width: 8.w),
                  Text(
                    'السعر المتفق عليه: ${_job!.technicianPrice ?? 0} ريال',
                    style: TextStyle(
                      fontSize: 16.fz,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
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

  Widget _buildTechnicianInfo() {
    if (_job?.technicianId == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(radius: 16.r),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: AppTheme.primaryColor,
            child: Icon(Icons.person, color: Colors.white, size: 28.s),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الفني',
                  style: TextStyle(fontSize: 12.fz, color: Colors.white60),
                ),
                Text(
                  'فني محترف', // Would be from backend
                  style: TextStyle(
                    fontSize: 16.fz,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Call technician
            },
            icon: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, color: Colors.white),
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
        // For price rejection, we cancel the current job or use a different endpoint
        // Since confirmPrice no longer takes a boolean, rejecting means cancelling
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
