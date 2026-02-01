// lib/src/core/widgets/error_retry_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import '../app_theme.dart';
import '../utils/error_messages.dart';

/// Reusable error widget with retry button
class ErrorRetryWidget extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorRetryWidget({
    super.key,
    this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64.s, color: Colors.red.withValues(alpha: 0.7)),
            SizedBox(height: 16.h),
            Text(
              message ?? ErrorMessages.unknownError,
              style: TextStyle(
                fontSize: 16.fz,
                color: AppTheme.textPrimaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact error message with retry
class CompactErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const CompactErrorRetry({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 24.s),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 14.fz, color: Colors.red),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}
