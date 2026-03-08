import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';

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
      backgroundColor: AppTheme.backgroundDark,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('صور ما قبل الخدمة'),
                  SizedBox(height: 12.h),
                  _buildPhotoList(_prePhotos, isReadOnly: true),

                  SizedBox(height: 24.h),

                  _buildSectionTitle('صور ما بعد الخدمة'),
                  SizedBox(height: 8.h),
                  Text(
                    'يمكنك إضافة المزيد من الصور هنا',
                    style: TextStyle(color: Colors.grey, fontSize: 12.fz),
                  ),
                  SizedBox(height: 12.h),
                  _buildPhotoList(_afterPhotos, isReadOnly: false),

                  SizedBox(height: 32.h),

                  _buildSectionTitle('تفاصيل العمل'),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'اكتب وصفاً للعمل الذي تم إنجازه...',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  _buildSectionTitle('السعر النهائي'),
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
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  SizedBox(height: 48.h),

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
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'تأكيد وإرسال للعميل',
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18.fz,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildPhotoList(List<String> photos, {required bool isReadOnly}) {
    if (photos.isEmpty && isReadOnly) {
      return Text('لا توجد صور', style: TextStyle(color: Colors.grey));
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
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(Icons.add_a_photo, color: Colors.white54),
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
