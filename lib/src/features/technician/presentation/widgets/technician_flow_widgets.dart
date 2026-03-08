import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

import '../../../../core/design/kadmat_tokens.dart';

class TechnicianFlowHero extends StatelessWidget {
  const TechnicianFlowHero({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.bottom,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF17313B), Color(0xFF0D1E25)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(icon, color: Colors.white, size: 22.s),
          ),
          SizedBox(height: 14.h),
          Text(
            eyebrow,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.fz,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12.8.fz,
              height: 1.55,
            ),
          ),
          if (bottom != null) ...[SizedBox(height: 14.h), bottom!],
        ],
      ),
    );
  }
}

class TechnicianFlowSurface extends StatelessWidget {
  const TechnicianFlowSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class TechnicianFlowNextStepCard extends StatelessWidget {
  const TechnicianFlowNextStepCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46.w,
          height: 46.w,
          decoration: BoxDecoration(
            color: KadmatColors.brandAccent,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Icon(icon, color: KadmatColors.brandSecondary, size: 22.s),
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
    );
  }
}

class TechnicianFlowPill extends StatelessWidget {
  const TechnicianFlowPill({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15.s),
          SizedBox(width: 6.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 220.w),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5.fz,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
