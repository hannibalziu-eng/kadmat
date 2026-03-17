import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

import '../../../../core/design/kadmat_tokens.dart';

class TechnicianAuthScaffold extends StatelessWidget {
  const TechnicianAuthScaffold({
    super.key,
    required this.child,
    required this.topActionLabel,
    required this.onTopAction,
  });

  final Widget child;
  final String topActionLabel;
  final VoidCallback onTopAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121824), Color(0xFF1B2433), Color(0xFFF5F7FA)],
            stops: [0, 0.34, 0.34],
          ),
        ),
        child: Stack(
          children: [
            const _TechnicianAuthBackdrop(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 640.w),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 28.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TechnicianAuthTopRow(
                          topActionLabel: topActionLabel,
                          onTopAction: onTopAction,
                        ),
                        SizedBox(height: 18.h),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TechnicianAuthHero extends StatelessWidget {
  const TechnicianAuthHero({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFA53A);

    return Container(
      padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 20.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34.r),
        color: const Color(0xFF121A28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28.r,
            offset: Offset(0, 18.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 26.s),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: const [
              _TechnicianAuthPill(label: 'تشغيل أوضح'),
              _TechnicianAuthPill(label: 'قرارات أقل'),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28.fz,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13.2.fz,
              height: 1.62,
            ),
          ),
        ],
      ),
    );
  }
}

class TechnicianAuthSurface extends StatelessWidget {
  const TechnicianAuthSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 26.r,
            offset: Offset(0, 14.h),
          ),
        ],
      ),
      child: child,
    );
  }
}

class TechnicianAuthInfoCard extends StatelessWidget {
  const TechnicianAuthInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.tint,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color? tint;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final background = tint ?? const Color(0xFFFFF8EA);
    final foreground = iconColor ?? const Color(0xFFE08A18);

    return TechnicianAuthSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: foreground, size: 22.s),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: KadmatColors.lightTextPrimary,
                    fontSize: 15.fz,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  description,
                  style: TextStyle(
                    color: KadmatColors.lightTextSecondary,
                    fontSize: 12.5.fz,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianAuthBackdrop extends StatelessWidget {
  const _TechnicianAuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90.h,
            right: -50.w,
            child: _TechnicianGlowOrb(
              size: 220.w,
              color: KadmatColors.brandPrimary.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            top: 120.h,
            left: -70.w,
            child: _TechnicianGlowOrb(
              size: 180.w,
              color: const Color(0xFFFFA53A).withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianAuthTopRow extends StatelessWidget {
  const _TechnicianAuthTopRow({
    required this.topActionLabel,
    required this.onTopAction,
  });

  final String topActionLabel;
  final VoidCallback onTopAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            'مساحة الفني',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onTopAction,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          ),
          child: Text(
            topActionLabel,
            style: TextStyle(fontSize: 13.fz, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _TechnicianAuthPill extends StatelessWidget {
  const _TechnicianAuthPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 11.8.fz,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TechnicianGlowOrb extends StatelessWidget {
  const _TechnicianGlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0, 1],
        ),
      ),
    );
  }
}
