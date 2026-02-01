// lib/src/core/widgets/loading_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import '../app_theme.dart';

/// Reusable loading overlay widget
/// Shows a full-screen loading indicator with optional message
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    this.message,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                    if (message != null) ...[
                      SizedBox(height: 16.h),
                      Text(
                        message!,
                        style: TextStyle(
                          fontSize: 14.fz,
                          color: AppTheme.textPrimaryDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Simple loading indicator for inline use
class InlineLoader extends StatelessWidget {
  final String? message;
  final double size;

  const InlineLoader({super.key, this.message, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
        ),
        if (message != null) ...[
          SizedBox(width: 12.w),
          Text(
            message!,
            style: TextStyle(
              fontSize: 14.fz,
              color: AppTheme.textSecondaryDark,
            ),
          ),
        ],
      ],
    );
  }
}

/// Loading button state
class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String text;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.text,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppTheme.primaryColor,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      child: isLoading ? const InlineLoader(message: null) : Text(text),
    );
  }
}
