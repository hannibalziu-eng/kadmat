import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import '../app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// خطوات إرشادية اختيارية لتوجيه المستخدم
  final List<String>? steps;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppTheme.primaryColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64.fz,
                color: isDark ? Colors.grey[400] : AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.fz,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 8.h),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.fz,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
            ],
            // خطوات إرشادية للمستخدم
            if (steps != null && steps!.isNotEmpty) ...[
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 18.s,
                          color: isDark ? Colors.amber : AppTheme.primaryColor,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'كيف تبدأ؟',
                          style: TextStyle(
                            fontSize: 14.fz,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    ...steps!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24.w,
                              height: 24.w,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12.fz,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 2.h),
                                child: Text(
                                  step,
                                  style: TextStyle(
                                    fontSize: 13.fz,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey[700],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 32.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 16.fz,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
