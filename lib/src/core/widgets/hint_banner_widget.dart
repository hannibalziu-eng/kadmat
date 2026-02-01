import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import '../app_theme.dart';

/// بانر تلميحات سياقية يظهر نصائح للمستخدم
class HintBanner extends StatefulWidget {
  final IconData icon;
  final String text;
  final bool dismissible;
  final Color? backgroundColor;
  final Color? iconColor;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  const HintBanner({
    super.key,
    this.icon = Icons.lightbulb_outline,
    required this.text,
    this.dismissible = true,
    this.backgroundColor,
    this.iconColor,
    this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<HintBanner> createState() => _HintBannerState();
}

class _HintBannerState extends State<HintBanner>
    with SingleTickerProviderStateMixin {
  bool _isDismissed = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() => _isDismissed = true);
        widget.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final bgColor =
        widget.backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1);
    final icColor = widget.iconColor ?? AppTheme.primaryColor;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: icColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, color: icColor, size: 24.s),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.text,
                    style: TextStyle(
                      fontSize: 14.fz,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                  if (widget.actionLabel != null &&
                      widget.onAction != null) ...[
                    SizedBox(height: 8.h),
                    TextButton(
                      onPressed: widget.onAction,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        widget.actionLabel!,
                        style: TextStyle(
                          fontSize: 14.fz,
                          fontWeight: FontWeight.bold,
                          color: icColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.dismissible)
              GestureDetector(
                onTap: _dismiss,
                child: Icon(Icons.close, color: Colors.white54, size: 20.s),
              ),
          ],
        ),
      ),
    );
  }
}

/// بانر تلميح للخطوة التالية
class NextStepHint extends StatelessWidget {
  final String stepNumber;
  final String stepTitle;
  final String description;
  final VoidCallback? onAction;

  const NextStepHint({
    super.key,
    required this.stepNumber,
    required this.stepTitle,
    required this.description,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.2),
            Colors.purple.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Step Number Circle
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(
                  fontSize: 20.fz,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الخطوة التالية',
                  style: TextStyle(fontSize: 12.fz, color: Colors.white60),
                ),
                SizedBox(height: 4.h),
                Text(
                  stepTitle,
                  style: TextStyle(
                    fontSize: 16.fz,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(fontSize: 13.fz, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (onAction != null)
            IconButton(
              onPressed: onAction,
              icon: Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.primaryColor,
                size: 20.s,
              ),
            ),
        ],
      ),
    );
  }
}
