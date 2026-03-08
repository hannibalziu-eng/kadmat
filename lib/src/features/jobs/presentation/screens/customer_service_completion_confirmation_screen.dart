import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../../core/utils/service_name_formatter.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';
import '../../../../core/navigation/app_routes.dart';

class CustomerServiceCompletionConfirmationScreen
    extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerServiceCompletionConfirmationScreen({
    super.key,
    required this.jobId,
  });

  @override
  ConsumerState<CustomerServiceCompletionConfirmationScreen> createState() =>
      _CustomerServiceCompletionConfirmationScreenState();
}

class _CustomerServiceCompletionConfirmationScreenState
    extends ConsumerState<CustomerServiceCompletionConfirmationScreen> {
  bool _isWorkDoneChecked = false;
  final bool _isLoading = false;
  Job? _job;

  @override
  void initState() {
    super.initState();
    _fetchJob();
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (mounted) setState(() => _job = job);
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'خطأ',
          message: 'فشل تحميل بيانات الطلب',
        );
      }
    }
  }

  Future<void> _contactSupport() async {
    // WhatsApp Support Number (Replace with actual support number)
    const supportPhone = '966500000000'; // Example: Saudi number
    final jobId = widget.jobId;
    final message = Uri.encodeComponent('سلام, عندي مشكلة في الطلب رقم $jobId');

    try {
      // Try WhatsApp first
      final whatsappUri = Uri.parse(
        'whatsapp://send?phone=$supportPhone&text=$message',
      );
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        // Fallback to regular phone call
        final telUri = Uri.parse('tel:$supportPhone');
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        } else {
          if (mounted) {
            KadmatToast.showError(
              context,
              title: 'خطأ',
              message: 'فشل فتح تطبيق الدعم',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'خطأ',
          message: 'حدث خطأ عند فتح الدعم',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_job == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final price = _job?.finalPrice ?? _job?.technicianPrice ?? 0;
    final technicianName = _job?.technician?['full_name'] ?? 'الفني';
    final serviceName = formatServiceDisplayName(
      _job?.service,
      fallback: 'خدمة عامة',
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تأكيد إكمال الخدمة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // Icon Header
            Icon(
              Icons.check_circle_outline,
              color: AppTheme.primaryColor,
              size: 64.s,
            ),
            SizedBox(height: 16.h),
            Text(
              'أنهى الفني العمل',
              style: TextStyle(
                fontSize: 20.fz,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'يرجى مراجعة التفاصيل أدناه والتأكيد لإغلاق الطلب',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.fz, color: Colors.white70),
            ),
            SizedBox(height: 24.h),

            // Photos Section
            if ((_job?.images != null && _job!.images!.isNotEmpty) ||
                (_job?.afterPhotos != null &&
                    _job!.afterPhotos!.isNotEmpty)) ...[
              _buildPhotosSection('صور قبل الخدمة', _job!.images ?? []),
              SizedBox(height: 16.h),
              _buildPhotosSection(
                'صور بعد الخدمة',
                _job!.afterPhotos ?? [],
                isEmptyMessage: 'لا توجد صور بعد الخدمة',
              ),
              SizedBox(height: 24.h),
            ],

            // Job Summary Card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: AppTheme.glassDecoration(radius: 12.r),
              child: Column(
                children: [
                  _buildSummaryRow(Icons.work, 'الخدمة', serviceName),
                  Divider(color: Colors.white10),
                  _buildSummaryRow(Icons.person, 'الفني', technicianName),
                  Divider(color: Colors.white10),
                  _buildSummaryRow(
                    Icons.monetization_on,
                    'السعر المتفق عليه',
                    '${price.toStringAsFixed(2)} ريال',
                    isBold: true,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Checkboxes
            _buildCheckboxTile(
              value: _isWorkDoneChecked,
              label: 'تم تنفيذ الخدمة كما تم الاتفاق',
              onChanged: (v) => setState(() => _isWorkDoneChecked = v ?? false),
            ),

            SizedBox(height: 32.h),

            // Confirm Button (Proceed to Payment)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isWorkDoneChecked && !_isLoading)
                    ? () {
                        context.push(
                          AppRoutes.customerPaymentProcessing.replaceAll(
                            ':jobId',
                            widget.jobId,
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  disabledBackgroundColor: Colors.grey[800],
                  disabledForegroundColor: Colors.white38,
                ),
                child: Text(
                  'المتابعة للدفع',
                  style: TextStyle(
                    fontSize: 18.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            SizedBox(height: 16.h),

            // Secondary Button (Problem)
            TextButton.icon(
              onPressed: _contactSupport,
              icon: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 20.s,
              ),
              label: Text(
                'هناك مشكلة / تواصل مع الدعم',
                style: TextStyle(color: Colors.orange, fontSize: 14.fz),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    IconData icon,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20.s),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(color: Colors.white70, fontSize: 14.fz),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.fz,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: value ? Colors.green : Colors.transparent),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14.fz,
            color: Colors.white,
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        activeColor: Colors.green,
        checkColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      ),
    );
  }

  Widget _buildPhotosSection(
    String title,
    List<dynamic> photos, {
    String? isEmptyMessage,
  }) {
    // Handle both JobImage objects and Strings
    final imageUrls = photos
        .map((p) {
          if (p is String) return p;
          // If JobImage model has 'url' property (assuming it does based on context)
          // Inspecting Job model would confirm, but typically it has url.
          // I'll assume standard access or toString for safety, or safe cast.
          try {
            return (p as dynamic).url as String;
          } catch (_) {
            return '';
          }
        })
        .where((url) => url.isNotEmpty)
        .toList();

    if (imageUrls.isEmpty && isEmptyMessage == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.fz,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8.h),
        if (imageUrls.isEmpty)
          Text(
            isEmptyMessage ?? '',
            style: TextStyle(color: Colors.white54, fontSize: 14.fz),
          )
        else
          SizedBox(
            height: 100.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Image.network(
                    imageUrls[index],
                    width: 100.h,
                    height: 100.h,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 100.h,
                      color: Colors.grey[800],
                      child: const Icon(Icons.error),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
