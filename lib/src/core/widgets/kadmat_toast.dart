import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

enum ToastType { success, warning, info, error }

enum ToastPosition { top, bottom }

class KadmatToast {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    ToastType type = ToastType.info,
    ToastPosition position = ToastPosition.top,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        title: title,
        message: message,
        type: type,
        position: position,
        duration: duration,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }

  static void showSuccess(
    BuildContext context, {
    required String title,
    String? message,
  }) {
    show(
      context,
      title: title,
      message: message ?? '',
      type: ToastType.success,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String title,
    String? message,
  }) {
    show(
      context,
      title: title,
      message: message ?? '',
      type: ToastType.warning,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String title,
    String? message,
  }) {
    show(context, title: title, message: message ?? '', type: ToastType.info);
  }

  static void showError(
    BuildContext context, {
    required String title,
    String? message,
  }) {
    show(context, title: title, message: message ?? '', type: ToastType.error);
  }
}

class _ToastWidget extends StatefulWidget {
  final String title;
  final String message;
  final ToastType type;
  final ToastPosition position;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.title,
    required this.message,
    required this.type,
    required this.position,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    final startOffset = widget.position == ToastPosition.top
        ? const Offset(0, -1.0)
        : const Offset(0, 1.0);

    _slideAnimation = Tween<Offset>(begin: startOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.elasticOut,
            reverseCurve: Curves.easeInBack,
          ),
        );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    // Using dark glassmorphism style as base, but tinting slightly based on type
    return const Color(0xFF1E1E1E).withValues(alpha: 0.95);
  }

  Color _getIconColor() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF4CAF50); // Green
      case ToastType.warning:
        return const Color(0xFFFFB74D); // Orange
      case ToastType.error:
        return const Color(0xFFEF5350); // Red
      case ToastType.info:
        return Colors.blueAccent;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.warning:
        return Icons.warning_amber_rounded;
      case ToastType.error:
        return Icons.error_outline_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safe area calculation to avoid notch/home bar
    final double topPadding = MediaQuery.of(context).padding.top + 16.h;
    final double bottomPadding = MediaQuery.of(context).padding.bottom + 16.h;

    return Positioned(
      top: widget.position == ToastPosition.top ? topPadding : null,
      bottom: widget.position == ToastPosition.bottom ? bottomPadding : null,
      left: 16.w,
      right: 16.w,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Dismissible(
              key: UniqueKey(),
              direction: widget.position == ToastPosition.top
                  ? DismissDirection.up
                  : DismissDirection.down,
              onDismissed: (_) => widget.onDismiss(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon Container
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: _getIconColor().withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIcon(),
                        color: _getIconColor(),
                        size: 24.s,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    // Text Content
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.fz,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal', // Assuming app font
                              height: 1.2,
                            ),
                          ),
                          if (widget.message.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              widget.message,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.fz,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Close Button
                    /*
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white54, size: 18.s),
                      onPressed: () {
                         _controller.reverse().then((_) => widget.onDismiss());
                      },
                    ),
                    */
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
