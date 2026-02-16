import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(liveNotificationsProvider);
    final notifications =
        notificationsAsync.valueOrNull ?? const <NotificationItem>[];

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
              onPressed: () async {
                try {
                  await ref
                      .read(notificationRepositoryProvider)
                      .markAllAsRead();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تعذر تحديث الإشعارات')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            'تعذر تحميل الإشعارات',
            style: TextStyle(fontSize: 16.fz, color: Colors.white70),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
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
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(liveNotificationsProvider);
              await ref.read(liveNotificationsProvider.future);
            },
            child: ListView.separated(
              padding: EdgeInsets.all(16.w),
              itemCount: items.length,
              separatorBuilder: (context, index) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final notification = items[index];
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
                  confirmDismiss: (_) async {
                    try {
                      await ref
                          .read(notificationRepositoryProvider)
                          .deleteNotification(notification.id);
                      return true;
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تعذر حذف الإشعار')),
                        );
                      }
                      return false;
                    }
                  },
                  child: _NotificationItem(notification: notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationItem extends ConsumerWidget {
  final NotificationItem notification;

  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        if (!notification.isRead) {
          try {
            await ref
                .read(notificationRepositoryProvider)
                .markAsRead(notification.id);
          } catch (_) {}
        }

        final dataJobId = _extractJobId(notification);
        if (dataJobId == null || dataJobId.isEmpty) return;

        final userType = ref.read(authRepositoryProvider).userType;
        if (userType == 'technician') {
          if (context.mounted) {
            context.push(AppRoutes.buildTechnicianJobDetailPath(dataJobId));
          }
          return;
        }

        if (context.mounted) {
          context.push(AppRoutes.buildCustomerSearchingPath(dataJobId));
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
                        _formatTime(notification.createdAt),
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12.fz,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    notification.body ?? '',
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
      case 'price_pending':
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

  String? _extractJobId(NotificationItem item) {
    final dynamic value = item.data['job_id'] ?? item.data['jobId'];
    if (value is String) return value;
    return null;
  }
}
