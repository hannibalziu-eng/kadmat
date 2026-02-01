import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final Duration? duration;
  final bool enabled;

  const AnimatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.duration = const Duration(milliseconds: 200),
    this.enabled = true,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? _onTapDown : null,
      onTapUp: widget.enabled ? _onTapUp : null,
      onTapCancel: widget.enabled ? _onTapCancel : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width ?? double.infinity,
              height: widget.height ?? 48,
              decoration: BoxDecoration(
                color: widget.enabled
                    ? (widget.backgroundColor ?? Theme.of(context).primaryColor)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: widget.textColor ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
    );
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed();
  }

  void _onTapCancel() {
    _controller.reverse();
  }
}

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration? duration;
  final double? borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final bool enableHover;
  final bool enableScale;

  const AnimatedCard({
    super.key,
    required this.child,
    this.duration,
    this.borderRadius,
    this.color,
    this.onTap,
    this.enableHover = true,
    this.enableScale = true,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: widget.color ?? Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
      ),
    ).animate().slideY(
      begin: 50,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
    );
  }
}

class FadeInWrapper extends StatelessWidget {
  final Widget child;
  final Duration? duration;
  final Duration? delay;
  final SlideDirection? slideDirection;

  const FadeInWrapper({
    super.key,
    required this.child,
    this.duration,
    this.delay,
    this.slideDirection,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fadeIn(
          duration: duration ?? const Duration(milliseconds: 500),
          delay: delay ?? Duration.zero,
        )
        .then()
        .slideY(
          begin: slideDirection == SlideDirection.up
              ? 30
              : (slideDirection == SlideDirection.down ? -30 : 0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
        );
  }
}

enum SlideDirection { up, down, none }
