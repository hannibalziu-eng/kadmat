import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/service_name_formatter.dart';
import '../../jobs/domain/job_status.dart';
import '../data/messages_repository.dart';
import '../domain/conversation_thread.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationThreadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرسائل'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(conversationThreadsProvider),
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessagesErrorState(
          message: ErrorHandler.getMessage(error),
          onRetry: () => ref.invalidate(conversationThreadsProvider),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const _MessagesEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _ConversationCard(conversation: conversation);
            },
          );
        },
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

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push(
            AppRoutes.buildJobChatPath(conversation.jobId),
            extra: {
              'otherUserName': name,
              'otherUserImage': conversation.otherUser?.profileImageUrl,
              'otherUserPhone': phone,
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                    child: !hasAvatar ? Text(avatarText.toUpperCase()) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (conversation.unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${conversation.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _Pill(
                              label: serviceName,
                              color: Theme.of(context).colorScheme.primary,
                              background: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                            ),
                            _Pill(
                              label: _statusLabel(conversation.status),
                              color: _statusColor(conversation.status),
                              background: _statusColor(
                                conversation.status,
                              ).withValues(alpha: 0.12),
                            ),
                            if (conversation.lastMessageAt != null)
                              Text(
                                _formatTimestamp(conversation.lastMessageAt!),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: phone == null || phone.isEmpty
                          ? null
                          : () async {
                              final uri = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('اتصال'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push(
                          AppRoutes.buildJobChatPath(conversation.jobId),
                          extra: {
                            'otherUserName': name,
                            'otherUserImage':
                                conversation.otherUser?.profileImageUrl,
                            'otherUserPhone': phone,
                          },
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('فتح المحادثة'),
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
        return Colors.green;
      case JobStatus.pendingConfirm:
        return Colors.orange;
      case JobStatus.arrived:
      case JobStatus.inProgress:
      case JobStatus.onTheWay:
        return Colors.blue;
      default:
        return Colors.grey;
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد محادثات متاحة الآن',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تظهر المحادثات بعد قبول العرض وبدء التواصل مع الفني.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
