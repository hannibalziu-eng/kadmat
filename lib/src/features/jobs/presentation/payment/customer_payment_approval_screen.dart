// lib/src/features/jobs/presentation/payment/customer_payment_approval_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';
import '../job_controller.dart';

/// Customer Payment Approval Screen
/// Allows customer to review work and approve/reject payment
class CustomerPaymentApprovalScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerPaymentApprovalScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerPaymentApprovalScreen> createState() =>
      _CustomerPaymentApprovalScreenState();
}

class _CustomerPaymentApprovalScreenState
    extends ConsumerState<CustomerPaymentApprovalScreen> {
  Job? _job;
  Map<String, List<String>> _photos = {'pre': [], 'post': []};
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentPhotoIndex = 0;
  bool _showingBeforePhotos = true;

  @override
  void initState() {
    super.initState();
    _fetchJobAndPhotos();
  }

  Future<void> _fetchJobAndPhotos() async {
    try {
      final repository = ref.read(jobRepositoryProvider);

      final job = await repository.getJobById(widget.jobId);
      final photos = await repository.getJobPhotos(widget.jobId);

      if (mounted) {
        setState(() {
          _job = job;
          _photos = photos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approvePayment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الموافقة'),
        content: Text(
          'هل أنت متأكد من الموافقة على دفع ${_job?.finalPrice?.toStringAsFixed(2) ?? '0'} ريال؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('أوافق'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(jobControllerProvider.notifier).completeJob(widget.jobId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تأكيد الدفع بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to rating screen
        context.go(AppRoutes.buildCustomerRatePath(widget.jobId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تأكيد الدفع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _rejectPayment() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('سبب الرفض'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              hintText: 'اكتب سبب رفض الدفع...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('رفض'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(jobRepositoryProvider);
      await repository.cancelJob(widget.jobId, reason: reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض الدفع'),
            backgroundColor: Colors.orange,
          ),
        );

        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل رفض الدفع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(title: const Text('مراجعة الخدمة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_job == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(title: const Text('مراجعة الخدمة')),
        body: const Center(child: Text('لم يتم العثور على الطلب')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: const Text('مراجعة الخدمة'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo Comparison
                  _buildPhotoComparison(),
                  SizedBox(height: 16.h),

                  // Price Comparison
                  _buildPriceComparison(),
                  SizedBox(height: 16.h),

                  // Technician Notes
                  if (_job!.priceNotes != null && _job!.priceNotes!.isNotEmpty)
                    _buildTechnicianNotes(),
                ],
              ),
            ),
          ),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildPhotoComparison() {
    final beforePhotos = _photos['pre'] ?? [];
    final afterPhotos = _photos['post'] ?? [];
    final currentPhotos = _showingBeforePhotos ? beforePhotos : afterPhotos;

    if (beforePhotos.isEmpty && afterPhotos.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24.w),
        decoration: AppTheme.glassDecoration(),
        child: Center(
          child: Text(
            'لا توجد صور متاحة',
            style: TextStyle(
              color: AppTheme.textSecondaryDark,
              fontSize: 14.fz,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: AppTheme.glassDecoration(),
      child: Column(
        children: [
          // Photo Viewer
          if (currentPhotos.isNotEmpty)
            SizedBox(
              height: 300.h,
              child: PageView.builder(
                itemCount: currentPhotos.length,
                onPageChanged: (index) {
                  setState(() => _currentPhotoIndex = index);
                },
                itemBuilder: (context, index) {
                  return CachedNetworkImage(
                    imageUrl: currentPhotos[index],
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.error, color: Colors.red, size: 48),
                    ),
                  );
                },
              ),
            ),

          // Photo Counter
          if (currentPhotos.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(8.w),
              child: Text(
                '${_currentPhotoIndex + 1} / ${currentPhotos.length}',
                style: TextStyle(
                  fontSize: 12.fz,
                  color: AppTheme.textSecondaryDark,
                ),
              ),
            ),

          // Before/After Toggle
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: beforePhotos.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _showingBeforePhotos = true;
                              _currentPhotoIndex = 0;
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showingBeforePhotos
                          ? AppTheme.primaryColor
                          : AppTheme.surfaceDark,
                      foregroundColor: _showingBeforePhotos
                          ? Colors.white
                          : AppTheme.textSecondaryDark,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text('قبل (${beforePhotos.length})'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: afterPhotos.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _showingBeforePhotos = false;
                              _currentPhotoIndex = 0;
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showingBeforePhotos
                          ? AppTheme.primaryColor
                          : AppTheme.surfaceDark,
                      foregroundColor: !_showingBeforePhotos
                          ? Colors.white
                          : AppTheme.textSecondaryDark,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text('بعد (${afterPhotos.length})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceComparison() {
    final initialPrice = _job!.initialPrice ?? 0;
    final finalPrice = _job!.finalPrice ?? _job!.technicianPrice ?? 0;
    final difference = finalPrice - initialPrice;
    final isHigher = difference > 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مقارنة الأسعار',
            style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),

          _buildPriceRow('السعر المبدئي', initialPrice),
          SizedBox(height: 8.h),
          _buildPriceRow('السعر النهائي', finalPrice, isBold: true),

          if (difference != 0) ...[
            SizedBox(height: 8.h),
            Divider(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الفرق',
                  style: TextStyle(
                    fontSize: 14.fz,
                    color: AppTheme.textSecondaryDark,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: isHigher
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${isHigher ? '+' : ''}${difference.toStringAsFixed(2)} ريال',
                    style: TextStyle(
                      fontSize: 14.fz,
                      fontWeight: FontWeight.bold,
                      color: isHigher ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.fz,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} ريال',
          style: TextStyle(
            fontSize: 14.fz,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicianNotes() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note, size: 20.s, color: AppTheme.primaryColor),
              SizedBox(width: 8.w),
              Text(
                'ملاحظات الفني',
                style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            _job!.priceNotes!,
            style: TextStyle(
              fontSize: 14.fz,
              color: AppTheme.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _rejectPayment,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: const Text('لا أوافق'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _approvePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('أوافق على الدفع'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
