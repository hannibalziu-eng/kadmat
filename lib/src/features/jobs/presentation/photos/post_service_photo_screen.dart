// lib/src/features/jobs/presentation/photos/post_service_photo_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../data/job_repository.dart';

/// Model to hold both XFile and its bytes for cross-platform preview
class PickedPhoto {
  final XFile file;
  final Uint8List bytes;

  PickedPhoto({required this.file, required this.bytes});
}

/// Post-Service Photo Screen
/// Allows technician to capture 1-5 photos after completing work
/// and add completion notes
class PostServicePhotoScreen extends ConsumerStatefulWidget {
  final String jobId;

  const PostServicePhotoScreen({super.key, required this.jobId});

  @override
  ConsumerState<PostServicePhotoScreen> createState() =>
      _PostServicePhotoScreenState();
}

class _PostServicePhotoScreenState
    extends ConsumerState<PostServicePhotoScreen> {
  final List<PickedPhoto> _photos = [];
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  static const int _maxPhotos = 5;
  static const int _minPhotos = 1;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Helper function to build photo preview - Works on both Web and Mobile
  Widget buildPhotoPreview(PickedPhoto photo, {BoxFit fit = BoxFit.cover}) {
    // On all platforms, use Image.memory with bytes for consistency
    return Image.memory(
      photo.bytes,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[800],
          child: Icon(Icons.broken_image, color: Colors.grey[600], size: 40.s),
        );
      },
    );
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _maxPhotos) {
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'الحد الأقصى $_maxPhotos صور',
      );
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _photos.add(PickedPhoto(file: photo, bytes: bytes));
        });
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'خطأ',
          message: 'فشل التقاط الصورة: $e',
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_photos.length >= _maxPhotos) {
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'الحد الأقصى $_maxPhotos صور',
      );
      return;
    }

    try {
      final List<XFile> pickedPhotos = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedPhotos.isNotEmpty) {
        // Limit to remaining slots
        final remaining = _maxPhotos - _photos.length;
        final limitedPhotos = pickedPhotos.take(remaining);

        for (final photo in limitedPhotos) {
          final bytes = await photo.readAsBytes();
          setState(() {
            _photos.add(PickedPhoto(file: photo, bytes: bytes));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'خطأ',
          message: 'فشل اختيار الصور: $e',
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _uploadPhotos() async {
    if (_photos.length < _minPhotos) {
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'يجب إضافة صورة واحدة على الأقل',
      );
      return;
    }

    if (_notesController.text.trim().isEmpty) {
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'يجب إضافة ملاحظات عن العمل المنجز',
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final repository = ref.read(jobRepositoryProvider);

      // Convert PickedPhoto list to XFile list for upload
      final xFiles = _photos.map((p) => p.file).toList();

      await repository.uploadPostServicePhotos(
        widget.jobId,
        xFiles,
        _notesController.text.trim(),
      );

      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'تم بنجاح',
          message: '✅ تم رفع الصور بنجاح',
        );
        // Navigate to Price Confirmation screen
        context.go(
          AppRoutes.buildTechnicianPriceConfirmationPath(widget.jobId),
        );
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'خطأ',
          message: 'فشل رفع الصور: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = _photos.length >= _minPhotos && !_isUploading;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: const Text('صور بعد الخدمة'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            // Instructions
            Container(
              margin: EdgeInsets.all(16.w),
              padding: EdgeInsets.all(16.w),
              decoration: AppTheme.glassDecoration(),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 24.s,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'التقط من 1 إلى 5 صور توضح العمل المنجز بعد إتمام الخدمة',
                      style: TextStyle(
                        fontSize: 14.fz,
                        color: AppTheme.textSecondaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Photo Grid
            Expanded(
              child: _photos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera,
                            size: 80.s,
                            color: AppTheme.textSecondaryDark,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'لم يتم إضافة صور بعد',
                            style: TextStyle(
                              fontSize: 16.fz,
                              color: AppTheme.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.all(16.w),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12.w,
                        mainAxisSpacing: 12.h,
                      ),
                      itemCount: _photos.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            // Photo - Using cross-platform helper
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: buildPhotoPreview(_photos[index]),
                            ),
                            // Delete button
                            Positioned(
                              top: 8.h,
                              right: 8.w,
                              child: GestureDetector(
                                onTap: () => _removePhoto(index),
                                child: Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20.s,
                                  ),
                                ),
                              ),
                            ),
                            // Photo number badge
                            Positioned(
                              bottom: 8.h,
                              left: 8.w,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.fz,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // Notes Field
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.all(16.w),
              decoration: AppTheme.glassDecoration(),
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 14.fz,
                  color: AppTheme.textPrimaryDark,
                ),
                decoration: InputDecoration(
                  hintText: 'اكتب ملاحظات عن العمل المنجز...',
                  hintStyle: TextStyle(color: AppTheme.textSecondaryDark),
                  border: InputBorder.none,
                ),
              ),
            ),

            SizedBox(height: 16.h),

            // Action Buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  // Camera Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickPhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('كاميرا'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        side: const BorderSide(color: AppTheme.primaryColor),
                        foregroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Gallery Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('معرض'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        side: const BorderSide(color: AppTheme.primaryColor),
                        foregroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // Upload Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canUpload ? _uploadPhotos : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: _isUploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            const Text('جاري الرفع...'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload),
                            SizedBox(width: 8.w),
                            const Text('رفع الصور والمتابعة'),
                          ],
                        ),
                ),
              ),
            ),

            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}
