import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../jobs/presentation/job_controller.dart';
import '../../../jobs/domain/job.dart';

class TechnicianDashboardScreen extends ConsumerStatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  ConsumerState<TechnicianDashboardScreen> createState() =>
      _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState
    extends ConsumerState<TechnicianDashboardScreen> {
  bool _isOnline = true;

  void _refreshJobs() {
    final userProfile = ref.read(authRepositoryProvider).userProfile;
    final serviceId = userProfile?['service_id'] as String?;

    ref.invalidate(
      watchNearbyJobsStreamProvider(
        lat: 24.7136,
        lng: 46.6753,
        serviceId: serviceId,
      ),
    );
    ref.invalidate(myJobsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(authRepositoryProvider).userProfile;
    final userName = userProfile?['full_name'] ?? 'الفني';
    final serviceId = userProfile?['service_id'] as String?;

    // Watch for real-time nearby jobs using the stream
    // Using hardcoded Riyadh location for MVP
    final nearbyJobsStream = ref.watch(
      watchNearbyJobsStreamProvider(
        lat: 24.7136,
        lng: 46.6753,
        serviceId: serviceId,
      ),
    );

    // Listen for new jobs to show notification
    // Listen for new jobs to show notification
    ref.listen(
      watchNearbyJobsStreamProvider(
        lat: 24.7136,
        lng: 46.6753,
        serviceId: serviceId,
      ),
      (previous, next) {
        if (next is AsyncData && next.value != null) {
          final newJobs = next.value!;
          final oldJobs = previous?.value ?? [];

          // If we have more jobs than before, show notification
          if (newJobs.length > oldJobs.length) {
            // Only show if it's not the initial load (previous is not null or loading)
            if (previous is AsyncData) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8.w),
                      const Text('🔔 يوجد طلب جديد بالقرب منك!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(16.w),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      },
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        centerTitle: true,
        actions: [
          Switch(
            value: _isOnline,
            onChanged: (value) => setState(() => _isOnline = value),
            activeColor: Colors.green,
          ),
          SizedBox(width: 16.w),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshJobs();
          // Small delay to allow the stream to reconnect
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Ensure scroll even if content is short
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting with real name
              Text(
                'مرحباً، $userName 👋',
                style: TextStyle(
                  fontSize: 24.fz,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ).animate().fadeIn().slideX(),
              SizedBox(height: 8.h),
              Text(
                _isOnline ? 'أنت متصل الآن وتستقبل الطلبات' : 'أنت غير متصل',
                style: TextStyle(
                  fontSize: 14.fz,
                  color: _isOnline ? Colors.green : Colors.grey,
                ),
              ).animate().fadeIn().slideX(delay: 100.ms),
              SizedBox(height: 24.h),

              // Stats Grid - Use real data from myJobs
              _buildStatsSection(),

              SizedBox(height: 24.h),

              // New Requests Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلبات جديدة قريبة',
                    style: TextStyle(
                      fontSize: 18.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to requests tab
                    },
                    child: const Text('عرض الكل'),
                  ),
                ],
              ).animate().fadeIn(delay: 300.ms),
              SizedBox(height: 12.h),

              // Real-time jobs list
              nearbyJobsStream.when(
                data: (jobs) {
                  if (jobs.isEmpty) {
                    return _buildEmptyJobsCard();
                  }
                  return Column(
                    children: jobs
                        .take(3)
                        .map(
                          (job) => Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: _buildJobCard(job),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => _buildJobsShimmer(),
                error: (err, _) => _buildErrorCard(err.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final myJobsAsync = ref.watch(myJobsProvider);

    return myJobsAsync.when(
      data: (jobs) {
        final todayJobs = jobs
            .where(
              (j) =>
                  j.completedAt != null &&
                  j.completedAt!.day == DateTime.now().day,
            )
            .toList();

        final todayEarnings = todayJobs.fold<double>(
          0,
          (sum, job) => sum + (job.technicianPrice ?? job.initialPrice ?? 0),
        );

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'أرباح اليوم',
                '${todayEarnings.toStringAsFixed(0)} ر.س',
                Icons.account_balance_wallet,
                Colors.green,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildStatCard(
                'الطلبات المكتملة',
                '${todayJobs.length}',
                Icons.check_circle_outline,
                Colors.blue,
              ),
            ),
          ],
        ).animate().fadeIn().slideY(begin: 0.2, delay: 200.ms);
      },
      loading: () => _buildStatsShimmer(),
      error: (_, __) => _buildStatsShimmer(),
    );
  }

  Widget _buildStatsShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 100.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Container(
              height: 100.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Column(
        children: List.generate(
          2,
          (_) => Container(
            height: 120.h,
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyJobsCard() {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48.s, color: Colors.grey),
          SizedBox(height: 16.h),
          Text(
            'لا توجد طلبات جديدة حالياً',
            style: TextStyle(fontSize: 16.fz, color: Colors.grey),
          ),
          SizedBox(height: 8.h),
          Text(
            'ابقَ متصلاً لاستقبال الطلبات',
            style: TextStyle(fontSize: 12.fz, color: Colors.grey[600]),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, delay: 400.ms);
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 24.s),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'خطأ في جلب الطلبات: $error',
              style: TextStyle(fontSize: 14.fz, color: Colors.red),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red),
            onPressed: () => _refreshJobs(),
          ),
        ],
      ),
    );
  }

  // Track jobs currently being accepted to prevent double-clicks
  final Set<String> _processingJobs = {};

  Widget _buildJobCard(Job job) {
    final isProcessing = _processingJobs.contains(job.id);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            blurRadius: 15.r,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: Theme.of(context).primaryColor,
                child: Icon(Icons.person, color: Colors.white, size: 24.s),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.customer?['full_name'] ?? 'عميل',
                      style: TextStyle(
                        fontSize: 16.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      job.addressText ?? 'موقع غير محدد',
                      style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  job.status == 'pending' ? 'جديد' : 'قيد التنفيذ',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Service info
          Row(
            children: [
              Icon(Icons.work_outline, size: 16.s, color: Colors.grey),
              SizedBox(width: 4.w),
              Text(
                job.service?['name'] ?? 'خدمة',
                style: TextStyle(fontSize: 12.fz, color: Colors.grey),
              ),
              const Spacer(),
              Text(
                '${job.initialPrice?.toStringAsFixed(0) ?? '0'} ر.س',
                style: TextStyle(
                  fontSize: 14.fz,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          debugPrint(
                            '🔵 STEP 1: Button pressed for job ${job.id}',
                          );
                          setState(() {
                            _processingJobs.add(job.id);
                          });

                          try {
                            debugPrint('🔵 STEP 2: Calling acceptJob...');
                            final success = await ref
                                .read(jobControllerProvider.notifier)
                                .acceptJob(job.id);

                            debugPrint(
                              '🔵 STEP 3: acceptJob returned: $success',
                            );

                            if (success && mounted) {
                              debugPrint(
                                '🔵 STEP 4: Success! Invalidating providers...',
                              );
                              _refreshJobs();
                              debugPrint('🔵 STEP 5: Providers invalidated');

                              if (mounted) {
                                debugPrint(
                                  '🔵 STEP 6: Showing success snackbar',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      '✅ تم قبول الطلب! انتقل إلى "طلباتي" لبدء العمل',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 3),
                                    action: SnackBarAction(
                                      label: 'ذهاب',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        if (context.mounted) {
                                          context.push(
                                            '/technician/job/${job.id}',
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }
                            } else if (mounted) {
                              debugPrint(
                                '🔴 STEP 4: Failure! Reading error state...',
                              );
                              final errorState = ref.read(
                                jobControllerProvider,
                              );
                              debugPrint('🔴 Error: ${errorState.error}');

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '❌ فشل قبول الطلب: ${errorState.error ?? "خطأ غير معروف"}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e, stack) {
                            debugPrint('🔴 EXCEPTION in acceptance button: $e');
                            debugPrint('🔴 Stack trace: $stack');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ حدث خطأ: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            debugPrint(
                              '🔵 STEP FINAL: Cleaning up processing state',
                            );
                            if (mounted) {
                              setState(() {
                                _processingJobs.remove(job.id);
                              });
                            }
                          }
                        },
                  icon: isProcessing
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(isProcessing ? 'جاري القبول...' : 'قبول'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.green.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.map),
                  label: const Text('الموقع'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, delay: 400.ms);
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24.s),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.fz,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(fontSize: 12.fz, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
