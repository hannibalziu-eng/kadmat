import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/job_flow_redirects.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../jobs/data/job_repository.dart';
import '../../data/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(liveNotificationsProvider);
    final notifications =
        notificationsAsync.valueOrNull ?? const <NotificationItem>[];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'الإشعارات',
          style: TextStyle(
            color: KadmatColors.lightTextPrimary,
            fontSize: 20.fz,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.done_all,
                color: KadmatColors.lightTextSecondary,
              ),
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
            style: TextStyle(
              fontSize: 16.fz,
              color: KadmatColors.lightTextSecondary,
            ),
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
                    color: KadmatColors.lightTextSecondary.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'لا توجد إشعارات حالياً',
                    style: TextStyle(
                      fontSize: 16.fz,
                      color: KadmatColors.lightTextSecondary,
                    ),
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
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
                          borderRadius: BorderRadius.circular(18.r),
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
              ),
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

        final job = await ref.read(jobRepositoryProvider).getJob(dataJobId);
        final route =
            customerRouteForJobStatus(
              status: job?.status ?? '',
              jobId: dataJobId,
            ) ??
            AppRoutes.buildCustomerSearchingPath(dataJobId);

        if (context.mounted) {
          context.push(route);
        }
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : const Color(0xFFF4FAFD),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: notification.isRead
                ? KadmatColors.lightBorder
                : AppTheme.primaryColor.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
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
                          color: KadmatColors.lightTextPrimary,
                          fontSize: 16.fz,
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(
                          color: KadmatColors.lightTextSecondary,
                          fontSize: 12.fz,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    notification.body ?? '',
                    style: TextStyle(
                      color: KadmatColors.lightTextSecondary,
                      fontSize: 14.fz,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!notification.isRead) ...[
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        'جديد',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11.5.fz,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
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

    if (difference.inMinutes <= 0) {
      return 'الآن';
    }

    if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} د';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} س';
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
