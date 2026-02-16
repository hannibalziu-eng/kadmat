import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/widgets/shimmer_skeletons.dart';
import '../../../jobs/presentation/job_controller.dart';

/// A comprehensive statistics grid for the Technician Dashboard
/// Displays 6 key metrics:
/// 1. Average Rating
/// 2. Total Completed Jobs
/// 3. Active Jobs
/// 4. Success/Acceptance Rate
/// 5. Total Working Hours (Estimated)
/// 6. Monthly Earnings
class TechnicianStatsGrid extends ConsumerWidget {
  const TechnicianStatsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch real-time jobs data
    final jobsAsync = ref.watch(watchMyJobsRealtimeProvider);

    return jobsAsync.when(
      data: (jobs) {
        // --- Calculate Statistics ---

        // 1. Total Completed
        final completedJobs = jobs
            .where((j) => j.status == 'completed')
            .toList();
        final totalCompletedCount = completedJobs.length;

        // 2. Active Jobs
        final activeJobsCount = jobs
            .where(
              (j) => [
                'accepted',
                'in_progress',
                'on_the_way',
                'arrived',
                'price_pending',
                'pending_confirm',
              ].contains(j.status),
            )
            .length;

        // 3. Average Rating
        // Use techRating if available, otherwise 0
        final ratedJobs = completedJobs
            .where((j) => j.techRating != null)
            .toList();
        double avgRating = 0.0;
        if (ratedJobs.isNotEmpty) {
          final totalRating = ratedJobs.fold(
            0.0,
            (sum, j) => sum + (j.techRating ?? 0),
          );
          avgRating = totalRating / ratedJobs.length;
        }

        // 4. Monthly Earnings
        final now = DateTime.now();
        final thisMonthJobs = completedJobs.where((j) {
          if (j.completedAt == null) return false;
          return j.completedAt!.month == now.month &&
              j.completedAt!.year == now.year;
        }).toList();

        final monthlyEarnings = thisMonthJobs.fold(0.0, (sum, j) {
          // Use finalPrice if available, otherwise technicianPrice
          return sum + (j.finalPrice ?? j.technicianPrice ?? 0);
        });

        // 5. Success Rate (Completed vs Cancelled+Completed)
        // Ignoring pending/active for success rate calculation
        final finishedJobsCount = jobs
            .where((j) => ['completed', 'cancelled'].contains(j.status))
            .length;
        int successRate = 0;
        if (finishedJobsCount > 0) {
          successRate = ((totalCompletedCount / finishedJobsCount) * 100)
              .toInt();
        } else if (totalCompletedCount > 0) {
          successRate = 100; // 100% if no cancellations
        }

        // 6. Total Hours (Estimated)
        // Duration between acceptedAt and completedAt
        // Fallback: 1 hour per job if times missing
        int totalHours = 0;
        for (var job in completedJobs) {
          if (job.acceptedAt != null && job.completedAt != null) {
            final duration = job.completedAt!.difference(job.acceptedAt!);
            totalHours += duration.inHours;
          } else {
            // Default estimate: 1 hour per completed job if data missing
            totalHours += 1;
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            // Responsive Grid Logic
            final isTablet = constraints.maxWidth > 600;
            final crossAxisCount = isTablet ? 3 : 2;
            final childAspectRatio = isTablet ? 1.4 : 1.1;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: childAspectRatio,
              children:
                  [
                        _buildStatCard(
                          context,
                          title: 'التقييم العام',
                          value: avgRating > 0
                              ? avgRating.toStringAsFixed(1)
                              : 'جديد',
                          icon: Icons.star_rounded,
                          color: Colors.orange,
                          gradientColors: [Colors.orange, Colors.deepOrange],
                          prefix: avgRating > 0 ? '' : null,
                          isRating: true,
                        ),
                        _buildStatCard(
                          context,
                          title: 'الطلبات المكتملة',
                          value: '$totalCompletedCount',
                          icon: Icons.assignment_turned_in_rounded,
                          color: Colors.blue,
                          gradientColors: [Colors.blue, Colors.blueAccent],
                        ),
                        _buildStatCard(
                          context,
                          title: 'الطلبات الجارية',
                          value: '$activeJobsCount',
                          icon: Icons.timer_rounded,
                          color: Colors.green,
                          gradientColors: [Colors.green, Colors.teal],
                          isHighlighted: activeJobsCount > 0,
                        ),
                        _buildStatCard(
                          context,
                          title: 'نسبة القبول',
                          value: '$successRate%',
                          icon: Icons.pie_chart_rounded,
                          color: Colors.purple,
                          gradientColors: [Colors.purple, Colors.deepPurple],
                        ),
                        _buildStatCard(
                          context,
                          title: 'ساعات العمل',
                          value: '${totalHours}h',
                          icon: Icons.access_time_filled_rounded,
                          color: Colors.teal,
                          gradientColors: [Colors.teal, Colors.cyan],
                        ),
                        _buildStatCard(
                          context,
                          title: 'أرباح الشهر',
                          value: '${monthlyEarnings.toInt()}',
                          suffix: ' د.ل',
                          icon: Icons.attach_money_rounded,
                          color: const Color(0xFFFFD700), // Gold
                          gradientColors: [
                            const Color(0xFFFFD700),
                            Colors.amber,
                          ],
                          isCurrency: true,
                        ),
                      ]
                      .animate(interval: 50.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0, duration: 400.ms),
            );
          },
        );
      },
      loading: () => _buildShimmerGrid(context),
      error: (e, st) {
        debugPrint('⚠️ TechnicianStatsGrid stream error: $e');
        return _buildStatsFallbackCard(context);
      },
    );
  }

  Widget _buildStatsFallbackCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.sync, color: Colors.orange, size: 22.s),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'جاري مزامنة الإحصائيات، تحقق من اتصال الإنترنت',
              style: TextStyle(
                fontSize: 13.fz,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
    String? suffix,
    String? prefix,
    bool isRating = false,
    bool isHighlighted = false,
    bool isCurrency = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r), // More rounded
        border: isHighlighted
            ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20.r),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          child: Stack(
            children: [
              // Subtle background gradient decoration
              Positioned(
                top: -10,
                right: -10,
                child: Container(
                  width: 60.w,
                  height: 60.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: gradientColors
                          .map((c) => c.withValues(alpha: 0.1))
                          .toList(),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header (Icon with Gradient)
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors
                              .map((c) => c.withValues(alpha: 0.15))
                              .toList(),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(icon, color: color, size: 22.s),
                    ),

                    // Value & Title
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              value,
                              style: TextStyle(
                                fontSize: 24.fz,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                                height: 1,
                              ),
                            ),
                            if (suffix != null) ...[
                              SizedBox(width: 4.w),
                              Text(
                                suffix,
                                style: TextStyle(
                                  fontSize: 12.fz,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            if (isRating) ...[
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.star_rounded,
                                color: Colors.orange,
                                size: 18.s,
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.fz,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      childAspectRatio: 1.1,
      children: List.generate(
        6,
        (index) => const SkeletonBase(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 16,
        ),
      ),
    );
  }
}
