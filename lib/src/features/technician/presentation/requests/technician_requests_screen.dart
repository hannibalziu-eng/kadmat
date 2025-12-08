import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../jobs/presentation/job_controller.dart';
import '../../../jobs/domain/job.dart';

class TechnicianRequestsScreen extends ConsumerStatefulWidget {
  const TechnicianRequestsScreen({super.key});

  @override
  ConsumerState<TechnicianRequestsScreen> createState() =>
      _TechnicianRequestsScreenState();
}

class _TechnicianRequestsScreenState
    extends ConsumerState<TechnicianRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('الطلبات الواردة'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 2.h,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: TextStyle(fontSize: 14.fz, fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontSize: 14.fz),
          tabs: const [
            Tab(text: 'طلبات جديدة'),
            Tab(text: 'قيد التنفيذ'),
            Tab(text: 'مكتملة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewRequestsTab(),
          _buildInProgressTab(),
          _buildCompletedTab(),
        ],
      ),
    );
  }

  Widget _buildNewRequestsTab() {
    // Hardcoded location for MVP (Riyadh)
    final nearbyJobsAsync = ref.watch(
      nearbyJobsProvider(lat: 24.7136, lng: 46.6753),
    );

    return nearbyJobsAsync.when(
       (jobs) {
        if (jobs.isEmpty) {
          return Center(child: Text('لا توجد طلبات جديدة حالياً'));
        }
        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return _buildRequestCard(
              job: job,
              serviceName: job.service?['name'] ?? 'خدمة',
              customerName: job.customer?['full_name'] ?? 'عميل',
              location: job.addressText ?? 'موقع غير محدد',
              time: job.createdAt.toString(), // Format properly in real app
              icon: Icons.work, // Dynamic icon based on service?
              iconColor: Colors.blue,
              iconBgColor: Colors.blue.shade50,
              statusText: 'جديد',
              statusColor: Colors.orange,
              showActions: true,
              onAccept: () async {
                debugPrint('✅ Accepting job: ${job.id}');
                await ref
                    .read(jobControllerProvider.notifier)
                    .acceptJob(job.id);
                // Refresh lists after accept
                if (mounted) {
                  debugPrint('🔄 Invalidating providers after accept');
                  ref.invalidate(nearbyJobsProvider);
                  ref.invalidate(myJobsProvider);
                  // Also refresh current tab
                  setState(() {});
                }
              },
              onReject: () {
                // Implement reject logic (maybe just hide locally or API call)
              },
            ).animate().fadeIn().slideX(delay: (100 * index).ms);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('خطأ: $err')),
    );
  }

  Widget _buildInProgressTab() {
    // Continuously watch myJobs - rebuilds whenever status changes
    final myJobsAsync = ref.watch(myJobsProvider);

    return myJobsAsync.when(
       (jobs) {
        debugPrint(
          '📋 InProgress Tab: Total=${jobs.length}, Statuses=${jobs.map((j) => j.status).toList()}',
        );

        // Include accepted, price_pending, and in_progress
        final inProgressJobs = jobs
            .where((j) =>
                j.status == 'accepted' ||
                j.status == 'price_pending' ||
                j.status == 'in_progress')
            .toList();

        debugPrint('✅ Filtered jobs=${inProgressJobs.length}');

        if (inProgressJobs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80.s, color: Colors.grey),
                  SizedBox(height: 16.h),
                  const Text(
                    'لا توجد طلبات قيد التنفيذ',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh when user pulls down
            ref.invalidate(myJobsProvider);
            await ref.read(myJobsProvider.future);
          },
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: inProgressJobs.length,
            itemBuilder: (context, index) {
              final job = inProgressJobs[index];
              debugPrint('🎨 Building card: ${job.id}, status=${job.status}');

              return _buildRequestCard(
                job: job,
                serviceName: job.service?['name'] ?? 'خدمة',
                customerName: job.customer?['full_name'] ?? 'عميل',
                location: job.addressText ?? 'موقع غير محدد',
                time: job.createdAt.toString(),
                icon: Icons.work_history,
                iconColor: Colors.cyan,
                iconBgColor: Colors.cyan.shade50,
                statusText: _getStatusText(job.status),
                statusColor: _getStatusColor(job.status),
                showActions: false,
                showSetPriceButton: job.status == 'accepted',
                showWaitingPriceApproval:
                    job.status == 'price_pending',
                showCompleteButton: job.status == 'in_progress',
                onSetPrice: () {
                  debugPrint('💰 Navigate to set price: ${job.id}');
                  context.go('/jobs/${job.id}/technician/set-price');
                },
                onComplete: () async {
                  debugPrint('✔️ Completing job: ${job.id}');
                  await ref
                      .read(jobControllerProvider.notifier)
                      .completeJob(job.id);
                  ref.invalidate(myJobsProvider);
                },
              ).animate().fadeIn().slideX();
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) {
        debugPrint('❌ InProgress Error: $err, $stack');
        return Center(child: Text('خطأ: $err'));
      },
    );
  }

  Widget _buildCompletedTab() {
    final myJobsAsync = ref.watch(myJobsProvider);

    return myJobsAsync.when(
       (jobs) {
        final completedJobs = jobs
            .where((j) => j.status == 'completed')
            .toList();

        if (completedJobs.isEmpty) {
          return Center(child: Text('لا توجد طلبات مكتملة'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: completedJobs.length,
          itemBuilder: (context, index) {
            final job = completedJobs[index];
            return _buildRequestCard(
              job: job,
              serviceName: job.service?['name'] ?? 'خدمة',
              customerName: job.customer?['full_name'] ?? 'عميل',
              location: job.addressText ?? 'موقع غير محدد',
              time: job.createdAt.toString(),
              icon: Icons.check_circle_outline,
              iconColor: Colors.green,
              iconBgColor: Colors.green.shade50,
              statusText: 'مكتمل',
              statusColor: Colors.green,
              showActions: false,
              showRating: true,
              rating: 5.0, // TODO: Get real rating
            ).animate().fadeIn().slideX();
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('خطأ: $err')),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'في انتظار تحديد السعر';
      case 'price_pending':
        return 'في انتظار موافقة العميل';
      case 'in_progress':
        return 'قيد التنفيذ';
      default:
        return 'قيد التنفيذ';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.orange;
      case 'price_pending':
        return Colors.amber;
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  Widget _buildRequestCard({
    required Job job,
    required String serviceName,
    required String customerName,
    required String location,
    required String time,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String statusText,
    required Color statusColor,
    bool showActions = false,
    bool showCompleteButton = false,
    bool showSetPriceButton = false,
    bool showWaitingPriceApproval = false,
    bool showRating = false,
    double rating = 0.0,
    VoidCallback? onAccept,
    VoidCallback? onReject,
    VoidCallback? onComplete,
    VoidCallback? onSetPrice,
  }) {
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
          // Header: Icon, Title, Status
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: iconColor, size: 28.s),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: TextStyle(
                        fontSize: 16.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'عميل: $customerName',
                      style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Location
          Row(
            children: [
              Icon(Icons.location_on, size: 16.s, color: Colors.grey),
              SizedBox(width: 4.w),
              Text(
                location,
                style: TextStyle(fontSize: 12.fz, color: Colors.grey),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // Time
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16.s, color: Colors.grey),
              SizedBox(width: 4.w),
              Text(
                time,
                style: TextStyle(fontSize: 12.fz, color: Colors.grey),
              ),
            ],
          ),
          // Rating (for completed)
          if (showRating) ...[SizedBox(height: 12.h),
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 18.s,
                  );
                }),
                SizedBox(width: 8.w),
                Text(
                  '($rating)',
                  style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                ),
              ],
            ),
          ],
          SizedBox(height: 16.h),
          // Actions
          if (showActions)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('قبول'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('رفض'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (showSetPriceButton)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSetPrice,
                icon: const Icon(Icons.attach_money),
                label: const Text('تحديد السعر الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          if (showWaitingPriceApproval)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.amber, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16.w,
                    height: 16.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.amber),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  const Text(
                    'في انتظار موافقة العميل على السعر',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (showCompleteButton)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle),
                label: const Text('إتمام الخدمة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          if (!showActions &&
              !showCompleteButton &&
              !showSetPriceButton &&
              !showWaitingPriceApproval)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: const Text('عرض التفاصيل'),
              ),
            ),
        ],
      ),
    );
  }
}
