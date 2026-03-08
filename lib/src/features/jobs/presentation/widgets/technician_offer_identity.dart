import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/utils/technician_summary.dart';

class TechnicianOfferIdentity extends StatelessWidget {
  final TechnicianSummary technician;

  const TechnicianOfferIdentity({super.key, required this.technician});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          technician.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15.fz,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          technician.primaryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.fz,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (technician.secondaryTitle != null) ...[
          SizedBox(height: 2.h),
          Text(
            technician.secondaryTitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.fz, color: Colors.white54),
          ),
        ],
        SizedBox(height: 8.h),
        Wrap(
          spacing: 6.w,
          runSpacing: 6.h,
          children: [
            _MetricChip(
              icon: Icons.star,
              color: Colors.amber,
              text: technician.rating.toStringAsFixed(1),
            ),
            if (technician.completedJobs > 0)
              _MetricChip(
                icon: Icons.task_alt,
                color: Colors.greenAccent,
                text: '${technician.completedJobs} مكتملة',
              ),
            if (technician.location != null)
              _MetricChip(
                icon: Icons.location_on_outlined,
                color: AppTheme.primaryColor,
                text: technician.location!,
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _MetricChip({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.s, color: color),
          SizedBox(width: 4.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 100.w),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5.fz,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
