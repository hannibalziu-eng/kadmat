import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;

import '../../jobs/domain/job.dart';
import '../../jobs/domain/job_communication_policy.dart';
import '../../jobs/data/job_repository.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/error_handler.dart';

class TechnicianPriceInputScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String? serviceName;

  const TechnicianPriceInputScreen({
    super.key,
    required this.orderId,
    this.serviceName,
  });

  @override
  ConsumerState<TechnicianPriceInputScreen> createState() =>
      _TechnicianPriceInputScreenState();
}

class _TechnicianPriceInputScreenState
    extends ConsumerState<TechnicianPriceInputScreen> {
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Job? _job;
  List<String> _photos = []; // صور العميل
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadJobData();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // 1. جلب بيانات الطلب مع الصور
  Future<void> _loadJobData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // جلب الـ Job مع صور العميل
      final result = await ref
          .read(jobRepositoryProvider)
          .getJobWithPhotos(widget.orderId);

      if (mounted) {
        setState(() {
          _job = result.job;
          _photos = result.customerPhotos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorHandler.getMessage(e);
        });
      }
    }
  }

  // 2. إرسال السعر
  Future<void> _submitPrice() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال سعر صحيح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // إرسال السعر للـ backend
      await ref
          .read(jobRepositoryProvider)
          .setPrice(
            widget.orderId,
            price,
            notes: _notesController.text.isNotEmpty
                ? _notesController.text
                : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال العرض للعميل بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        // انتظار قصير ثم الانتقال لشاشة انتظار موافقة العميل
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go(AppRoutes.buildTechnicianWaitingPath(widget.orderId));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getMessage(e)),
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

  // دوال مساعدة
  Future<void> _callCustomer(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('لا يمكن إجراء الاتصال')));
      }
    }
  }

  Future<void> _openLocation(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16.w),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // الصورة مع التكبير
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => Container(
                    padding: EdgeInsets.all(32.w),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            // زر الإغلاق
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 24.s),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null || _job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطأ')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48.s, color: Colors.red),
              SizedBox(height: 16.h),
              Text(
                _errorMessage ?? 'لم يتم العثور على الطلب',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: _loadJobData,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('تحديد السعر'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                [
                      _buildCustomerPhotosSection(),
                      SizedBox(height: 16.h),
                      _buildCustomerInfoCard(),
                      SizedBox(height: 16.h),
                      _buildJobDetailsCard(),
                      SizedBox(height: 24.h),
                      const Divider(),
                      SizedBox(height: 16.h),
                      _buildPriceInputSection(),
                      SizedBox(height: 16.h),
                      _buildNotesSection(),
                      SizedBox(height: 32.h),
                      _buildSubmitButton(),
                      SizedBox(height: 24.h),
                    ]
                    .animate(interval: 50.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, duration: 400.ms),
          ),
        ),
      ),
    );
  }

  // قسم صور العميل
  Widget _buildCustomerPhotosSection() {
    if (_photos.isEmpty) {
      // Placeholder صغير عند عدم وجود صور
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Container(
          height: 80.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 32.s,
                color: Colors.grey[400],
              ),
              SizedBox(width: 12.w),
              Text(
                'لا توجد صور مرفقة من العميل',
                style: TextStyle(color: Colors.grey[600], fontSize: 14.fz),
              ),
            ],
          ),
        ),
      );
    }

    // عرض الصور في شريط أفقي
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h, right: 4.w),
          child: Row(
            children: [
              Icon(Icons.photo_library, size: 20.s, color: Colors.grey[700]),
              SizedBox(width: 8.w),
              Text(
                'صور من العميل (${_photos.length})',
                style: TextStyle(
                  fontSize: 14.fz,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length,
            separatorBuilder: (context, index) => SizedBox(width: 12.w),
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
            itemBuilder: (context, index) {
              final url = _photos[index];
              return GestureDetector(
                onTap: () => _showFullScreenImage(url),
                child: Hero(
                  tag: 'photo_$index',
                  child: Container(
                    width: 120.h, // مربع
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey[400],
                                size: 32.s,
                              ),
                            ),
                          ),
                          // Overlay
                          Positioned(
                            bottom: 6.h,
                            right: 6.w,
                            child: Container(
                              padding: EdgeInsets.all(4.w),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 14.s,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  // معلومات العميل
  Widget _buildCustomerInfoCard() {
    final customer = _job?.customer;
    final name = customer?['full_name'] ?? 'عميل غير معروف';
    final phone = customer?['phone_number'] as String?;
    final avatarUrl = customer?['avatar_url'] as String?;
    final rating = (customer?['rating'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            // صورة العميل أو الحرف الأول
            CircleAvatar(
              radius: 28.r,
              backgroundColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.1),
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.fz,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.fz,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  if (rating > 0)
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16.s),
                        SizedBox(width: 4.w),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14.fz,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // زر الاتصال
            if (phone != null && phone.isNotEmpty)
              Material(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                child: InkWell(
                  onTap: JobCommunicationPolicy.canUseJobCommunication(_job)
                      ? () => _callCustomer(phone)
                      : null,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone, color: Colors.green, size: 20.s),
                        SizedBox(width: 6.w),
                        Text(
                          'اتصال',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.fz,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SizedBox(width: 8.w),
            // زر المراسلة
            Material(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
              child: InkWell(
                onTap: JobCommunicationPolicy.canUseJobCommunication(_job)
                    ? () {
                        context.push(
                          AppRoutes.buildJobChatPath(widget.orderId),
                          extra: {
                            'otherUserName':
                                _job?.customer?['full_name'] ?? 'العميل',
                            'otherUserImage':
                                _job?.customer?['profile_image_url'],
                            'otherUserPhone': phone,
                          },
                        );
                      }
                    : null,
                borderRadius: BorderRadius.circular(12.r),
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat, color: Colors.blue, size: 20.s),
                      SizedBox(width: 6.w),
                      Text(
                        'مراسلة',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 14.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تفاصيل الطلب
  Widget _buildJobDetailsCard() {
    final date = _job?.createdAt != null
        ? intl.DateFormat('yyyy/MM/dd - HH:mm').format(_job!.createdAt)
        : '-';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _buildDetailRow(
              icon: Icons.work_outline,
              label: 'الخدمة',
              value: widget.serviceName ?? _job?.service?['name'] ?? 'خدمة',
              isHeader: true,
            ),
            Divider(height: 24.h),
            _buildDetailRow(
              icon: Icons.location_on_outlined,
              label: 'الموقع',
              value: _job?.addressText ?? 'غير محدد',
              isLink: true,
              onTap: () => _openLocation(_job?.lat, _job?.lng),
            ),
            if (_job?.description != null && _job!.description!.isNotEmpty) ...[
              Divider(height: 24.h),
              _buildDetailRow(
                icon: Icons.description_outlined,
                label: 'الوصف',
                value: _job!.description!,
              ),
            ],
            Divider(height: 24.h),
            _buildDetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'التاريخ',
              value: date,
            ),
            if (_job?.initialPrice != null) ...[
              Divider(height: 24.h),
              _buildDetailRow(
                icon: Icons.attach_money,
                label: 'السعر المبدئي',
                value: '${_job!.initialPrice!.toStringAsFixed(0)} ر.س',
                valueColor: Theme.of(context).primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLink = false,
    bool isHeader = false,
    VoidCallback? onTap,
    Color? valueColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: isHeader
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                icon,
                size: 20.s,
                color: isHeader
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12.fz),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isHeader ? 16.fz : 14.fz,
                      fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
                      color:
                          valueColor ?? (isLink ? Colors.blue : Colors.black87),
                      decoration: isLink ? TextDecoration.underline : null,
                    ),
                  ),
                ],
              ),
            ),
            if (isLink)
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.open_in_new, size: 16.s, color: Colors.blue),
              ),
          ],
        ),
      ),
    );
  }

  // حقل السعر
  Widget _buildPriceInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.price_change, size: 20.s, color: Colors.grey[700]),
            SizedBox(width: 8.w),
            Text(
              'سعر الخدمة المقترح',
              style: TextStyle(
                fontSize: 16.fz,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        TextFormField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 36.fz,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
          decoration: InputDecoration(
            hintText: 'أدخل السعر',
            hintStyle: TextStyle(
              fontSize: 36.fz,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
            suffixText: 'ر.س',
            suffixStyle: TextStyle(
              fontSize: 18.fz,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: 20.h,
              horizontal: 16.w,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال السعر';
            }
            final num = double.tryParse(value);
            if (num == null) {
              return 'رقم غير صحيح';
            }
            if (num <= 0) {
              return 'السعر يجب أن يكون أكبر من 0';
            }
            return null;
          },
          onChanged: (val) => setState(() {}),
        ),
      ],
    );
  }

  // الملاحظات
  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.note_alt_outlined, size: 20.s, color: Colors.grey[700]),
            SizedBox(width: 8.w),
            Text(
              'ملاحظات (اختياري)',
              style: TextStyle(
                fontSize: 14.fz,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'أضف أي تفاصيل إضافية حول السعر أو الخدمة...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14.fz),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.all(14.w),
          ),
        ),
      ],
    );
  }

  // زر الإرسال
  Widget _buildSubmitButton() {
    final priceText = _priceController.text;
    final price = double.tryParse(priceText);
    final isValid = price != null && price > 0;

    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton(
        onPressed: (isValid && !_isSubmitting) ? _submitPrice : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: isValid ? 4 : 0,
        ),
        child: _isSubmitting
            ? SizedBox(
                height: 24.s,
                width: 24.s,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 22.s),
                  SizedBox(width: 10.w),
                  Text(
                    'إرسال العرض للعميل',
                    style: TextStyle(
                      fontSize: 18.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
