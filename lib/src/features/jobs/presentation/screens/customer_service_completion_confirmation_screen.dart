import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/design/kadmat_tokens.dart';
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final price = _job?.finalPrice ?? _job?.technicianPrice ?? 0;
    final technicianName = _job?.technician?['full_name'] ?? 'الفني';
    final serviceName = formatServiceDisplayName(
      _job?.service,
      fallback: 'خدمة عامة',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('تأكيد إكمال الخدمة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(serviceName, price),
                SizedBox(height: 16.h),

                if ((_job?.images != null && _job!.images!.isNotEmpty) ||
                    (_job?.afterPhotos != null &&
                        _job!.afterPhotos!.isNotEmpty)) ...[
                  _buildSurface(
                    child: _buildPhotosSection(
                      'صور قبل الخدمة',
                      _job!.images ?? [],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildSurface(
                    child: _buildPhotosSection(
                      'صور بعد الخدمة',
                      _job!.afterPhotos ?? [],
                      isEmptyMessage: 'لا توجد صور بعد الخدمة',
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                _buildSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'راجع هذه التفاصيل قبل الإغلاق',
                        style: TextStyle(
                          color: KadmatColors.lightTextPrimary,
                          fontSize: 18.fz,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      _buildSummaryRow(
                        Icons.work_outline_rounded,
                        'الخدمة',
                        serviceName,
                      ),
                      Divider(color: KadmatColors.lightBorder, height: 24.h),
                      _buildSummaryRow(
                        Icons.person_outline_rounded,
                        'الفني',
                        technicianName,
                      ),
                      Divider(color: KadmatColors.lightBorder, height: 24.h),
                      _buildSummaryRow(
                        Icons.payments_outlined,
                        'السعر المتفق عليه',
                        '${price.toStringAsFixed(2)} د.ل',
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                _buildSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مراجعة سريعة قبل الدفع',
                        style: TextStyle(
                          color: KadmatColors.lightTextPrimary,
                          fontSize: 18.fz,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _buildChecklistBullet(
                        'تأكد أن الخدمة نُفذت بالكامل كما تم الاتفاق عليها.',
                      ),
                      SizedBox(height: 10.h),
                      _buildChecklistBullet(
                        'راجع الصور قبل/بعد الخدمة إذا كانت متوفرة للتأكد من النتيجة.',
                      ),
                      SizedBox(height: 14.h),
                      _buildCheckboxTile(
                        value: _isWorkDoneChecked,
                        label: 'راجعت الخدمة وأوافق على المتابعة إلى الدفع',
                        onChanged: (v) =>
                            setState(() => _isWorkDoneChecked = v ?? false),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 22.h),
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

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _contactSupport,
                    icon: Icon(
                      Icons.support_agent_rounded,
                      color: Colors.orange.shade700,
                      size: 20.s,
                    ),
                    label: Text(
                      'هناك مشكلة؟ تواصل مع الدعم قبل الإغلاق',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 13.fz,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.orange.shade200),
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(String serviceName, double price) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
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
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 24.s,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'مراجعة ما قبل الإغلاق',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.fz,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'أنهى الفني العمل',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'راجع الصور والملخص بسرعة، ثم انتقل إلى الدفع إذا كانت النتيجة مطابقة لما اتفقتم عليه.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12.8.fz,
              height: 1.55,
            ),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildHeroPill(Icons.work_outline_rounded, serviceName),
              _buildHeroPill(
                Icons.payments_outlined,
                '${price.toStringAsFixed(0)} د.ل',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15.s),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5.fz,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurface({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: child,
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
          Icon(icon, color: KadmatColors.lightTextSecondary, size: 20.s),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: KadmatColors.lightTextSecondary,
              fontSize: 14.fz,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              color: KadmatColors.lightTextPrimary,
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
        color: value
            ? Colors.green.withValues(alpha: 0.08)
            : KadmatColors.brandAccent,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: value ? Colors.green : KadmatColors.lightBorder,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14.fz,
            color: KadmatColors.lightTextPrimary,
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        activeColor: Colors.green,
        checkColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      ),
    );
  }

  Widget _buildChecklistBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          margin: EdgeInsets.only(top: 6.h),
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: KadmatColors.lightTextSecondary,
              fontSize: 12.8.fz,
              height: 1.5,
            ),
          ),
        ),
      ],
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
            color: KadmatColors.lightTextPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        if (imageUrls.isEmpty)
          Text(
            isEmptyMessage ?? '',
            style: TextStyle(
              color: KadmatColors.lightTextSecondary,
              fontSize: 14.fz,
            ),
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
                      color: KadmatColors.brandAccent,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: KadmatColors.lightTextSecondary,
                        size: 20.s,
                      ),
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
