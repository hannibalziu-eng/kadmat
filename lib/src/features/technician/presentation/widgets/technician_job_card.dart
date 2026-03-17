import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:kadmat/src/features/jobs/domain/job.dart';

class TechnicianJobCard extends StatelessWidget {
  final Job job;
  final double distanceKm;
  final VoidCallback onTap;

  const TechnicianJobCard({
    super.key,
    required this.job,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Service Icon
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13b6ec).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      _getServiceIcon(job.service?['type'] ?? 'other'),
                      color: const Color(0xFF13b6ec),
                      size: 24.s,
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Service Name & Location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.service?['name'] ?? 'خدمة',
                          style: TextStyle(
                            fontSize: 16.fz,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${_formatDistance(distanceKm)} • ${_truncate(job.addressText ?? 'موقع غير محدد', 30)}',
                          style: TextStyle(
                            fontSize: 12.fz,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Wave Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: _getWaveColor(job.currentWave),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'موجة ${job.currentWave}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Description
              if (job.description != null && job.description!.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Text(
                  _truncate(job.description!, 100),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.fz, color: Colors.grey[800]),
                ),
              ],

              SizedBox(height: 12.h),

              // Footer: Budget & Time
              Row(
                children: [
                  if (job.initialPrice != null) ...[
                    Icon(
                      Icons.attach_money,
                      size: 16.s,
                      color: const Color(0xFF13b6ec),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${job.initialPrice!.toStringAsFixed(0)} د.ل',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF13b6ec),
                        fontSize: 14.fz,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _formatTime(job.createdAt),
                    style: TextStyle(fontSize: 12.fz, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getServiceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'carpentry':
        return Icons.carpenter;
      case 'painting':
        return Icons.format_paint;
      case 'ac':
      case 'hvac':
        return Icons.ac_unit;
      default:
        return Icons.home_repair_service;
    }
  }

  Color _getWaveColor(int wave) {
    switch (wave) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return '${diff.inHours} ساعة';
    return '${diff.inDays} يوم';
  }

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)} م';
    }
    return '${km.toStringAsFixed(1)} كم';
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
