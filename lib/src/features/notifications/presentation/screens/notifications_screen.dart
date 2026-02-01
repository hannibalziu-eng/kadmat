import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
// Using alias for intl to avoid conflicts if needed, though usually standard

import '../../../../core/app_theme.dart';
import '../../../../core/providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'الإشعارات',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.fz,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white70),
              tooltip: 'تحديد الكل كمقروء',
              onPressed: () {
                ref.read(notificationListProvider.notifier).markAllAsRead();
              },
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64.s,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'لا توجد إشعارات حالياً',
                    style: TextStyle(fontSize: 16.fz, color: Colors.white38),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                // Should fetch from API ideally
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return Dismissible(
                    key: Key(notification.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      alignment: AlignmentDirectional.centerStart,
                      padding: EdgeInsetsDirectional.only(start: 20.w),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(notificationListProvider.notifier)
                          .deleteNotification(notification.id);
                    },
                    child: _NotificationItem(notification: notification),
                  );
                },
              ),
            ),
    );
  }
}

class _NotificationItem extends ConsumerWidget {
  final NotificationModel notification;

  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        // Mark as read
        if (!notification.isRead) {
          ref
              .read(notificationListProvider.notifier)
              .markAsRead(notification.id);
        }

        // Navigate if jobId exists
        if (notification.jobId != null) {
          // Determine route based on user type or logic
          // For technician, usually detail or requests
          // Assuming technician context for now or generic job detail flow
          context.push('/jobs/${notification.jobId}/technician/detail');
        }
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: notification.isRead
                ? Colors.transparent
                : AppTheme.primaryColor.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconForType(notification.type),
                color: AppTheme.primaryColor,
                size: 24.s,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.fz,
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatTime(notification.timestamp),
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12.fz,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    notification.body,
                    style: TextStyle(color: Colors.white70, fontSize: 14.fz),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                margin: EdgeInsetsDirectional.only(end: 8.w, top: 4.h),
                width: 8.w,
                height: 8.w,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'new_job':
        return Icons.work_outline;
      case 'price_set':
        return Icons.monetization_on_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} د';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} س';
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
