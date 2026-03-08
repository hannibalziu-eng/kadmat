import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';
import '../../../technician/presentation/widgets/technician_flow_widgets.dart';

class TechnicianCompleteWorkScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianCompleteWorkScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianCompleteWorkScreen> createState() =>
      _TechnicianCompleteWorkScreenState();
}

class _TechnicianCompleteWorkScreenState
    extends ConsumerState<TechnicianCompleteWorkScreen> {
  Job? _job;
  bool _isLoading = false;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  List<String> _prePhotos = [];
  List<String> _afterPhotos = [];

  @override
  void initState() {
    super.initState();
    _fetchJobData();
  }

  Future<void> _fetchJobData() async {
    setState(() => _isLoading = true);
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      final photos = await ref
          .read(jobRepositoryProvider)
          .getJobPhotos(widget.jobId);

      if (mounted) {
        setState(() {
          _job = job;
          _prePhotos = photos['pre'] ?? [];
          _afterPhotos = photos['post'] ?? [];

          if (job != null) {
            // Default to technician price or initial price
            _priceController.text =
                (job.technicianPrice ?? job.initialPrice ?? 0).toStringAsFixed(
                  0,
                );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      KadmatToast.showError(
        context,
        title: 'خطأ',
        message: 'فشل تحميل البيانات',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitCompletion() async {
    if (_afterPhotos.isEmpty) {
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'يجب رفع صور بعد الخدمة',
      );
      return;
    }

    final finalPrice = double.tryParse(_priceController.text);
    if (finalPrice == null || finalPrice <= 0) {
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'يرجى إدخال سعر صحيح',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .requestJobCompletion(
            widget.jobId,
            finalPrice: finalPrice,
            notes: _notesController.text,
            afterPhotos: _afterPhotos,
          );

      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'تمت العملية',
          message: 'تم إرسال طلب الإنهاء بنجاح',
        );
        // Navigate to dashboard or summary
        context.go(AppRoutes.technicianHome);
      }
    } catch (e) {
      if (!mounted) return;
      KadmatToast.showError(
        context,
        title: 'خطأ',
        message: ErrorHandler.getMessage(e),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('إنهاء الخدمة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading && _job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TechnicianFlowHero(
                        icon: Icons.fact_check_rounded,
                        eyebrow: 'إغلاق المهمة',
                        title: 'أرسل طلب الإنهاء بشكل واضح',
                        subtitle:
                            'راجع الصور، أكمل وصف التنفيذ، ثم أرسل النتيجة النهائية للعميل حتى يؤكد اكتمال الخدمة.',
                        bottom: Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: [
                            TechnicianFlowPill(
                              icon: Icons.photo_camera_back_outlined,
                              label: '${_afterPhotos.length} صور بعد الخدمة',
                            ),
                            TechnicianFlowPill(
                              icon: Icons.attach_money_outlined,
                              label:
                                  '${_priceController.text.isEmpty ? '0' : _priceController.text} ر.س',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      const TechnicianFlowSurface(
                        child: TechnicianFlowNextStepCard(
                          icon: Icons.assignment_turned_in_outlined,
                          title:
                              'الخطوة التالية: أرسل النتيجة النهائية مرة واحدة',
                          description:
                              'أرفق صور ما بعد الخدمة، اكتب وصفًا مختصرًا فقط إذا لزم، ثم تأكد أن السعر النهائي صحيح قبل الإرسال للعميل.',
                        ),
                      ),
                      SizedBox(height: 16.h),
                      TechnicianFlowSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('صور ما قبل الخدمة'),
                            SizedBox(height: 12.h),
                            _buildPhotoList(_prePhotos, isReadOnly: true),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      TechnicianFlowSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('صور ما بعد الخدمة'),
                            SizedBox(height: 8.h),
                            Text(
                              'أضف الصور النهائية التي تشرح النتيجة بوضوح للعميل.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12.5.fz,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            _buildPhotoList(_afterPhotos, isReadOnly: false),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      TechnicianFlowSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('تفاصيل العمل'),
                            SizedBox(height: 8.h),
                            Text(
                              'اختياري. اكتب ما تم إنجازه فقط إذا كان سيضيف وضوحًا للعميل.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12.5.fz,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            TextField(
                              controller: _notesController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'اكتب وصفاً للعمل الذي تم إنجازه...',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      TechnicianFlowSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('السعر النهائي'),
                            SizedBox(height: 8.h),
                            Text(
                              'هذا هو السعر الذي سيراجعه العميل في خطوة الإنهاء.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12.5.fz,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            TextField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 24.fz,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                suffixText: 'ر.س',
                                suffixStyle: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16.fz,
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitCompletion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  'إرسال طلب الإنهاء للعميل',
                                  style: TextStyle(
                                    fontSize: 18.fz,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18.fz,
        fontWeight: FontWeight.bold,
        color: KadmatColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildPhotoList(List<String> photos, {required bool isReadOnly}) {
    if (photos.isEmpty && isReadOnly) {
      return Text('لا توجد صور', style: TextStyle(color: Colors.grey[600]));
    }

    return SizedBox(
      height: 100.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + (isReadOnly ? 0 : 1),
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          if (!isReadOnly && index == photos.length) {
            return GestureDetector(
              onTap: () async {
                // Navigate to post photos screen to add more
                await context.push(
                  AppRoutes.buildTechnicianPostPhotosPath(widget.jobId),
                );
                _fetchJobData(); // Refresh photos after return
              },
              child: Container(
                width: 100.w,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: KadmatColors.lightBorder),
                ),
                child: Icon(Icons.add_a_photo, color: Colors.grey[500]),
              ),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Image.network(
              photos[index],
              width: 100.w,
              height: 100.h,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 100.w,
                height: 100.h,
                color: Colors.grey[800],
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }
}
