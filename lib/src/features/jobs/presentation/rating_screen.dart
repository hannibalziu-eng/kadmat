import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/kadmat_toast.dart';
import '../data/job_repository.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final String jobId;

  const RatingScreen({super.key, required this.jobId});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _rating = 0;
  final _reviewController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تقييم الخدمة'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            SizedBox(height: 20.h),

            // Success Icon
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green, size: 60.s),
            ),
            SizedBox(height: 24.h),

            Text(
              'تم إكمال الخدمة بنجاح! 🎉',
              style: TextStyle(
                fontSize: 22.fz,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'كيف كانت تجربتك؟',
              style: TextStyle(fontSize: 16.fz, color: Colors.white60),
            ),
            SizedBox(height: 40.h),

            // Star Rating
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: AppTheme.glassDecoration(radius: 20.r),
              child: Column(
                children: [
                  Text(
                    'قيّم الفني',
                    style: TextStyle(fontSize: 16.fz, color: Colors.white70),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = starIndex),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Icon(
                            starIndex <= _rating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 48.s,
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _getRatingText(),
                    style: TextStyle(
                      fontSize: 14.fz,
                      color: _rating > 0 ? Colors.amber : Colors.white38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Review Text
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: AppTheme.glassDecoration(radius: 16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اكتب تجربتك (اختياري)',
                    style: TextStyle(fontSize: 14.fz, color: Colors.white70),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'ساعدنا في تحسين الخدمة...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
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

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rating > 0 && !_isLoading ? _submitRating : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        'إرسال التقييم',
                        style: TextStyle(
                          fontSize: 18.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 16.h),

            // Skip Button
            TextButton(
              onPressed: () => context.go('/'),
              child: Text(
                'تخطي',
                style: TextStyle(fontSize: 14.fz, color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText() {
    switch (_rating) {
      case 1:
        return 'سيء 😞';
      case 2:
        return 'مقبول 😐';
      case 3:
        return 'جيد 🙂';
      case 4:
        return 'ممتاز 😊';
      case 5:
        return 'رائع! 🌟';
      default:
        return 'اضغط على النجوم';
    }
  }

  Future<void> _submitRating() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .rateJob(
            widget.jobId,
            _rating,
            review: _reviewController.text.isNotEmpty
                ? _reviewController.text
                : null,
          );
      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'شكراً لتقييمك!',
          message: '💙 تم إرسال التقييم بنجاح',
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(context, title: 'خطأ', message: '$e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
