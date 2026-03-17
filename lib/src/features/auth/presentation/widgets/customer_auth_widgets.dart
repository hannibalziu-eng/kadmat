import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

import '../../../../core/design/kadmat_tokens.dart';

class CustomerAuthScaffold extends StatelessWidget {
  const CustomerAuthScaffold({
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
            colors: [Color(0xFF0E1624), Color(0xFF132238), Color(0xFFF5F7FA)],
            stops: [0, 0.34, 0.34],
          ),
        ),
        child: Stack(
          children: [
            const _CustomerAuthBackdrop(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 620.w),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 28.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CustomerAuthTopRow(
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

class CustomerAuthHero extends StatelessWidget {
  const CustomerAuthHero({
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
    return Container(
      padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 20.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF101A2B), Color(0xFF14263A)],
        ),
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
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(
              color: KadmatColors.brandPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: KadmatColors.brandPrimary.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 24.s),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: const [
              _CustomerAuthPill(label: 'سهل وواضح'),
              _CustomerAuthPill(label: 'بدون خطوات مشتتة'),
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

class CustomerAuthSurface extends StatelessWidget {
  const CustomerAuthSurface({super.key, required this.child});

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

class CustomerAuthInfoCard extends StatelessWidget {
  const CustomerAuthInfoCard({
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
    final background = tint ?? KadmatColors.brandAccent;
    final foreground = iconColor ?? KadmatColors.brandSecondary;

    return CustomerAuthSurface(
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

class _CustomerAuthBackdrop extends StatelessWidget {
  const _CustomerAuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90.h,
            right: -50.w,
            child: _CustomerGlowOrb(
              size: 240.w,
              color: KadmatColors.brandPrimary.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            top: 120.h,
            left: -70.w,
            child: _CustomerGlowOrb(
              size: 170.w,
              color: const Color(0xFF7AD6FF).withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerAuthTopRow extends StatelessWidget {
  const _CustomerAuthTopRow({
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
            'مساحة العميل',
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

class _CustomerAuthPill extends StatelessWidget {
  const _CustomerAuthPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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

class _CustomerGlowOrb extends StatelessWidget {
  const _CustomerGlowOrb({required this.size, required this.color});

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
