import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      data: (jobs) {
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
                await ref
                    .read(jobControllerProvider.notifier)
                    .acceptJob(job.id);
                // Refresh lists
                ref.invalidate(nearbyJobsProvider);
                ref.invalidate(myJobsProvider);
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
    final myJobsAsync = ref.watch(myJobsProvider);

    return myJobsAsync.when(
      data: (jobs) {
        final inProgressJobs = jobs
            .where((j) => j.status == 'accepted' || j.status == 'in_progress')
            .toList();

        if (inProgressJobs.isEmpty) {
          return Center(child: Text('لا توجد طلبات قيد التنفيذ'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: inProgressJobs.length,
          itemBuilder: (context, index) {
            final job = inProgressJobs[index];
            return _buildRequestCard(
              job: job,
              serviceName: job.service?['name'] ?? 'خدمة',
              customerName: job.customer?['full_name'] ?? 'عميل',
              location: job.addressText ?? 'موقع غير محدد',
              time: job.createdAt.toString(),
              icon: Icons.work_history,
              iconColor: Colors.cyan,
              iconBgColor: Colors.cyan.shade50,
              statusText: 'قيد التنفيذ',
              statusColor: Colors.blue,
              showActions: false,
              showCompleteButton: true,
              onComplete: () async {
                await ref
                    .read(jobControllerProvider.notifier)
                    .completeJob(job.id);
                ref.invalidate(myJobsProvider);
              },
            ).animate().fadeIn().slideX();
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('خطأ: $err')),
    );
  }

  Widget _buildCompletedTab() {
    final myJobsAsync = ref.watch(myJobsProvider);

    return myJobsAsync.when(
      data: (jobs) {
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
    bool showRating = false,
    double rating = 0.0,
    VoidCallback? onAccept,
    VoidCallback? onReject,
    VoidCallback? onComplete,
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
          if (showRating) ...[
            SizedBox(height: 12.h),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          if (!showActions && !showCompleteButton)
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
