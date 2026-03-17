import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_theme.dart';
import '../../../core/design/kadmat_tokens.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/service_name_formatter.dart';
import '../../../core/widgets/kadmat_components.dart';
import '../../jobs/domain/job_status.dart';
import '../data/messages_repository.dart';
import '../domain/conversation_thread.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationThreadsProvider);
    final conversations =
        conversationsAsync.valueOrNull ?? const <ConversationThread>[];
    final unreadCount = conversations.fold<int>(
      0,
      (total, item) => total + item.unreadCount,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 0),
              child: _MessagesHeader(
                unreadCount: unreadCount,
                conversationCount: conversations.length,
                onRefresh: () => ref.invalidate(conversationThreadsProvider),
              ),
            ),
            Expanded(
              child: conversationsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (error, _) => _MessagesErrorState(
                  message: ErrorHandler.getMessage(error),
                  onRetry: () => ref.invalidate(conversationThreadsProvider),
                ),
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return const _MessagesEmptyState();
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
                    itemCount: conversations.length,
                    separatorBuilder: (_, _) => SizedBox(height: 14.h),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return _ConversationCard(conversation: conversation);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader({
    required this.unreadCount,
    required this.conversationCount,
    required this.onRefresh,
  });

  final int unreadCount;
  final int conversationCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFEFF8FC), Color(0xFFDCEFF7)],
        ),
        border: Border.all(color: const Color(0xFFD5E7EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'محادثاتك الفعلية فقط',
                      style: TextStyle(
                        color: KadmatColors.lightTextPrimary,
                        fontSize: 24.fz,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'التواصل يظهر بعد قبول العرض فقط، حتى تبقى المحادثات مرتبطة بطلبات حقيقية ومفيدة للطرفين.',
                      style: TextStyle(
                        color: KadmatColors.lightTextSecondary,
                        fontSize: 13.fz,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              IconButton.filledTonal(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0C171C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: _HeaderStatTile(
                  label: 'محادثات نشطة',
                  value: '$conversationCount',
                  icon: Icons.chat_bubble_outline_rounded,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _HeaderStatTile(
                  label: 'غير مقروءة',
                  value: '$unreadCount',
                  icon: Icons.mark_chat_unread_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation});

  final ConversationThread conversation;

  @override
  Widget build(BuildContext context) {
    final name = conversation.otherUser?.fullName?.trim().isNotEmpty == true
        ? conversation.otherUser!.fullName!.trim()
        : 'مستخدم';
    final subtitle = (conversation.lastMessage?.trim().isNotEmpty ?? false)
        ? conversation.lastMessage!.trim()
        : 'لا توجد رسائل بعد';
    final avatarText = name.isNotEmpty ? name.characters.first : '?';
    final phone = conversation.otherUser?.phone?.trim();
    final avatarUrl = conversation.otherUser?.profileImageUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    final serviceName = formatServiceDisplayName(conversation.serviceName);
    final statusColor = _statusColor(conversation.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24.r),
        onTap: () => _openConversation(context, name, phone),
        child: Padding(
          padding: EdgeInsets.all(18.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28.r,
                    backgroundColor: KadmatColors.brandAccent,
                    backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                    child: !hasAvatar
                        ? Text(
                            avatarText.toUpperCase(),
                            style: TextStyle(
                              color: KadmatColors.brandSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18.fz,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (conversation.unreadCount > 0)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: KadmatColors.brandPrimary,
                                  borderRadius: BorderRadius.circular(999.r),
                                ),
                                child: Text(
                                  '${conversation.unreadCount}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.fz,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _Pill(
                    label: serviceName,
                    color: KadmatColors.brandSecondary,
                    background: KadmatColors.brandAccent,
                  ),
                  _Pill(
                    label: _statusLabel(conversation.status),
                    color: statusColor,
                    background: statusColor.withValues(alpha: 0.12),
                  ),
                  if (conversation.lastMessageAt != null)
                    _Pill(
                      label: _formatTimestamp(conversation.lastMessageAt!),
                      color: KadmatColors.lightTextSecondary,
                      background: Theme.of(context).scaffoldBackgroundColor,
                    ),
                ],
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: KadmatSecondaryButton(
                      label: 'اتصال',
                      icon: Icons.phone_outlined,
                      onPressed: phone == null || phone.isEmpty
                          ? null
                          : () async {
                              final uri = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: KadmatPrimaryButton(
                      label: 'فتح المحادثة',
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed: () => _openConversation(context, name, phone),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openConversation(BuildContext context, String name, String? phone) {
    context.push(
      AppRoutes.buildJobChatPath(conversation.jobId),
      extra: {
        'otherUserName': name,
        'otherUserImage': conversation.otherUser?.profileImageUrl,
        'otherUserPhone': phone,
      },
    );
  }

  static String _statusLabel(String status) {
    switch (JobStatus.normalize(status)) {
      case JobStatus.accepted:
        return 'تم القبول';
      case JobStatus.pricePending:
        return 'بانتظار السعر';
      case JobStatus.onTheWay:
        return 'في الطريق';
      case JobStatus.arrived:
        return 'وصل الفني';
      case JobStatus.inProgress:
        return 'قيد التنفيذ';
      case JobStatus.pendingConfirm:
        return 'بانتظار التأكيد';
      case JobStatus.completed:
        return 'مكتمل';
      case JobStatus.rated:
        return 'مقَيَّم';
      default:
        return status;
    }
  }

  static Color _statusColor(String status) {
    switch (JobStatus.normalize(status)) {
      case JobStatus.completed:
      case JobStatus.rated:
        return KadmatColors.stateSuccess;
      case JobStatus.pendingConfirm:
        return KadmatColors.stateWarning;
      case JobStatus.arrived:
      case JobStatus.inProgress:
      case JobStatus.onTheWay:
        return KadmatColors.stateInfo;
      default:
        return KadmatColors.lightTextSecondary;
    }
  }

  static String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'الآن';
    }
    if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} د';
    }
    if (difference.inDays < 1) {
      return DateFormat.Hm('ar').format(timestamp);
    }
    if (difference.inDays == 1) {
      return 'أمس';
    }
    return DateFormat('d/M', 'ar').format(timestamp);
  }
}

class _MessagesEmptyState extends StatelessWidget {
  const _MessagesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: KadmatColors.lightBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  color: KadmatColors.brandAccent,
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 34.s,
                  color: KadmatColors.brandSecondary,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'لا توجد محادثات متاحة الآن',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'تظهر المحادثات بعد قبول العرض وبدء التواصل مع الفني، لذلك تبقى هذه المساحة نظيفة ومتصلة بطلبات حقيقية فقط.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesErrorState extends StatelessWidget {
  const _MessagesErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: KadmatColors.lightBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: KadmatColors.stateError,
              ),
              SizedBox(height: 16.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 16.h),
              KadmatPrimaryButton(
                label: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStatTile extends StatelessWidget {
  const _HeaderStatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFDCE5E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: KadmatColors.brandAccent,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18.s),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: KadmatColors.lightTextPrimary,
                  fontSize: 18.fz,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: KadmatColors.lightTextSecondary,
                  fontSize: 12.fz,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12.fz,
        ),
      ),
    );
  }
}
