import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import '../../../core/utils/error_handler.dart';
import '../../domain/admin_models.dart';
import '../controllers/admin_controller.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platformStatsAsync = ref.watch(adminPlatformStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم الإدارية'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform Stats Cards
            platformStatsAsync.when(
              data: (stats) => _buildStatsGrid(stats),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  _buildErrorWidget(ErrorHandler.getMessage(error)),
            ),
            const SizedBox(height: 24),

            // Charts Section
            const Text(
              'التحليلات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildChartsSection(ref),

            const SizedBox(height: 24),

            // Recent Activity
            const Text(
              'الأنشطة الأخيرة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecentActivitySection(ref),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(PlatformStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 16.w,
      mainAxisSpacing: 16.h,
      children: [
        _buildStatCard(
          title: 'إجمالي المستخدمين',
          value: stats.totalUsers.toString(),
          icon: Icons.people,
          color: Colors.blue,
        ),
        _buildStatCard(
          title: 'إجمالي المهام',
          value: stats.totalJobs.toString(),
          icon: Icons.assignment,
          color: Colors.green,
        ),
        _buildStatCard(
          title: 'المهام المكتملة',
          value: stats.completedJobs.toString(),
          icon: Icons.check_circle,
          color: Colors.orange,
        ),
        _buildStatCard(
          title: 'الفنيين النشطين',
          value: stats.activeTechnicians.toString(),
          icon: Icons.engineering,
          color: Colors.purple,
        ),
        _buildStatCard(
          title: 'إجمالي الإيرادات',
          value: '${stats.totalRevenue.toStringAsFixed(2)} د.ل',
          icon: Icons.monetization_on,
          color: Colors.teal,
        ),
        _buildStatCard(
          title: 'نسبة الإنجاز',
          value: '${stats.completionRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(icon, color: color, size: 24.s),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20.fz,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(fontSize: 14.fz, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(WidgetRef ref) {
    final jobStatsAsync = ref.watch(adminJobStatsByServiceProvider);
    final techPerformanceAsync = ref.watch(adminTechnicianPerformanceProvider);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'توزيع المهام حسب الخدمة',
              style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            jobStatsAsync.when(
              data: (stats) => _buildJobStatsChart(stats),
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => _buildErrorWidget(error.toString()),
            ),
            const SizedBox(height: 24),
            Text(
              'أداء الفنيين',
              style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            techPerformanceAsync.when(
              data: (performance) => _buildTechPerformanceChart(performance),
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => _buildErrorWidget(error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobStatsChart(List<JobStatByService> stats) {
    if (stats.isEmpty) {
      return const Text('لا توجد بيانات');
    }

    return Column(
      children: stats.take(5).map((stat) {
        final percentage = stats.firstWhere((s) => s.count > 0).count > 0
            ? (stat.count / stats.firstWhere((s) => s.count > 0).count * 100)
            : 0;

        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(stat.serviceId)),
              Expanded(
                flex: 3,
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              SizedBox(width: 8.w),
              Text('${stat.count}'),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTechPerformanceChart(List<TechnicianPerformance> performance) {
    if (performance.isEmpty) {
      return const Text('لا توجد بيانات');
    }

    return Column(
      children: performance.take(5).map((tech) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: ListTile(
            title: Text('فني #${tech.technicianId.substring(0, 8)}'),
            subtitle: Text('${tech.jobCount} مهام'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16.s),
                Text(tech.avgRating.toStringAsFixed(1)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentActivitySection(WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsProvider);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإشعارات',
              style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            notificationsAsync.when(
              data: (notifications) => _buildNotificationsList(notifications),
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => _buildErrorWidget(error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList(List<AdminNotification> notifications) {
    if (notifications.isEmpty) {
      return const Text('لا توجد إشعارات');
    }

    return Column(
      children: notifications.take(5).map((notification) {
        return Card(
          child: ListTile(
            leading: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: _getNotificationColor(
                  notification.type,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                _getNotificationIcon(notification.type),
                color: _getNotificationColor(notification.type),
              ),
            ),
            title: Text(notification.title),
            subtitle: Text(notification.body),
            trailing: Text(
              _formatDate(notification.timestamp),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'success':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays} أيام';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ساعات';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} دقائق';
    } else {
      return 'الآن';
    }
  }

  Widget _buildErrorWidget(String errorMessage) {
    return Card(
      color: Colors.red.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Icon(Icons.error, color: Colors.red, size: 24.s),
            SizedBox(height: 8.h),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
