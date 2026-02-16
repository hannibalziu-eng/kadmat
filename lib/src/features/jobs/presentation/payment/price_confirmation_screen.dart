// lib/src/features/jobs/presentation/payment/price_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';

/// Work Completion Screen for Technician
/// Shows after-service photos, final price (read-only), work duration
/// and sends completion request to customer for payment confirmation
class PriceConfirmationScreen extends ConsumerStatefulWidget {
  final String jobId;

  const PriceConfirmationScreen({super.key, required this.jobId});

  @override
  ConsumerState<PriceConfirmationScreen> createState() =>
      _PriceConfirmationScreenState();
}

class _PriceConfirmationScreenState
    extends ConsumerState<PriceConfirmationScreen> {
  final TextEditingController _workNotesController = TextEditingController();

  Job? _job;
  List<String> _afterPhotos = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Commission rate (15%)
  static const double _commissionRate = 0.15;

  @override
  void initState() {
    super.initState();
    _fetchJobDetails();
  }

  @override
  void dispose() {
    _workNotesController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobDetails() async {
    debugPrint(
      '🔍 [PriceConfirmation] Fetching job details for: ${widget.jobId}',
    );

    try {
      final repository = ref.read(jobRepositoryProvider);

      // 1. Fetch job details
      final result = await repository.getJobWithPhotos(widget.jobId);

      // 2. CRITICAL FIX: Fetch post-service photos from job_photos table
      // The photos are saved to job_photos table with photo_type='post'
      // NOT to the job.afterPhotos field which is different
      final photosMap = await repository.getJobPhotos(widget.jobId);
      final postPhotos = photosMap['post'] ?? <String>[];

      debugPrint(
        '📸 [PriceConfirmation] Post-service photos found: ${postPhotos.length}',
      );

      if (mounted) {
        setState(() {
          _job = result.job;
          _afterPhotos = postPhotos;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [PriceConfirmation] Error fetching job: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        KadmatToast.showError(
          context,
          title: 'خطأ',
          message: 'فشل تحميل البيانات',
        );
      }
    }
  }

  // Get the agreed price (from price_pending stage)
  double get _finalPrice {
    return _job?.technicianPrice ?? _job?.initialPrice ?? 0;
  }

  double get _commission {
    return _finalPrice * _commissionRate;
  }

  double get _technicianEarnings {
    return _finalPrice - _commission;
  }

  // Calculate work duration
  String get _workDuration {
    if (_job?.acceptedAt == null) return 'غير محدد';

    final start = _job!.acceptedAt!;
    final end = DateTime.now();
    final duration = end.difference(start);

    if (duration.inHours > 0) {
      return '${duration.inHours} ساعة و ${duration.inMinutes % 60} دقيقة';
    } else {
      return '${duration.inMinutes} دقيقة';
    }
  }

  Future<void> _submitCompletion() async {
    debugPrint('🚀 [PriceConfirmation] Submitting completion...');
    debugPrint(
      '📸 [PriceConfirmation] After photos count: ${_afterPhotos.length}',
    );

    if (_afterPhotos.isEmpty) {
      debugPrint(
        '❌ [PriceConfirmation] No after-photos found - blocking submission',
      );
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'يجب رفع صور بعد الخدمة أولاً',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(jobRepositoryProvider)
          .requestJobCompletion(
            widget.jobId,
            finalPrice: _finalPrice,
            notes: _workNotesController.text,
            paymentMethod: 'cash', // Default, can be enhanced later
          );

      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'تم الإرسال',
          message: 'تم إرسال طلب تأكيد الدفع للعميل',
        );
        // Navigate to completed/waiting screen
        context.go(AppRoutes.buildTechnicianCompletedPath(widget.jobId));
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'خطأ',
          message: 'فشل إرسال طلب الإنهاء: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(title: const Text('إنهاء الخدمة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_job == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(title: const Text('إنهاء الخدمة')),
        body: const Center(child: Text('لم يتم العثور على الطلب')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('إنهاء الخدمة'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success Header
            _buildSuccessHeader(),
            SizedBox(height: 20.h),

            // After-Service Photos Section
            _buildAfterPhotosSection(),
            SizedBox(height: 20.h),

            // Work Duration Section
            _buildWorkDurationSection(),
            SizedBox(height: 20.h),

            // Pricing Section (Read-Only)
            _buildPricingSection(),
            SizedBox(height: 20.h),

            // Work Notes Section
            _buildWorkNotesSection(),
            SizedBox(height: 24.h),

            // Submit Button
            _buildSubmitButton(),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.2),
            Colors.teal.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 48.s),
          SizedBox(height: 12.h),
          Text(
            'أنهيت العمل! ✨',
            style: TextStyle(
              fontSize: 22.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'راجع التفاصيل وأرسل طلب تأكيد الدفع للعميل',
            style: TextStyle(fontSize: 14.fz, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAfterPhotosSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library, color: Colors.blue, size: 20.s),
              SizedBox(width: 8.w),
              Text(
                'صور بعد الخدمة',
                style: TextStyle(
                  fontSize: 16.fz,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Spacer(),
              Text(
                '${_afterPhotos.length} صور',
                style: TextStyle(fontSize: 14.fz, color: Colors.white60),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (_afterPhotos.isEmpty)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20.s),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'لم يتم رفع صور بعد الخدمة',
                      style: TextStyle(color: Colors.orange, fontSize: 14.fz),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 100.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _afterPhotos.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.network(
                      _afterPhotos[index],
                      width: 100.h,
                      height: 100.h,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100.h,
                        height: 100.h,
                        color: Colors.grey[800],
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkDurationSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timer, color: Colors.blue, size: 24.s),
          ),
          SizedBox(width: 16.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مدة العمل',
                style: TextStyle(fontSize: 14.fz, color: Colors.white60),
              ),
              Text(
                _workDuration,
                style: TextStyle(
                  fontSize: 18.fz,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل السعر',
            style: TextStyle(
              fontSize: 16.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16.h),

          // Total Price (Read-Only - Highlighted)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'السعر المتفق عليه',
                  style: TextStyle(fontSize: 14.fz, color: Colors.white60),
                ),
                SizedBox(height: 8.h),
                Text(
                  '${_finalPrice.toStringAsFixed(0)} ريال',
                  style: TextStyle(
                    fontSize: 32.fz,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Commission & Net Profit
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'عمولة المنصة (15%)',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '- ${_commission.toStringAsFixed(0)} ريال',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
                Divider(color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'صافي أرباحك',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${_technicianEarnings.toStringAsFixed(0)} ريال',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                        fontSize: 18.fz,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkNotesSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملاحظات العمل',
            style: TextStyle(
              fontSize: 16.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'صف ما تم إنجازه للعميل (اختياري)',
            style: TextStyle(fontSize: 12.fz, color: Colors.white60),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _workNotesController,
            maxLines: 3,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  'مثال: تم إصلاح المفتاح الكهربائي واستبدال الأسلاك التالفة...',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitCompletion,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 20.s),
                  SizedBox(width: 8.w),
                  Text(
                    'إرسال طلب تأكيد الدفع للعميل',
                    style: TextStyle(
                      fontSize: 16.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
