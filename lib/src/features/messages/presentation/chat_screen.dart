import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';

import '../../../core/api/api_error.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/error_handler.dart';
import '../../jobs/data/job_repository.dart';
import 'chat_controller.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';

/// Chat screen for messaging between customer and technician
class ChatScreen extends ConsumerStatefulWidget {
  final String jobId;
  final String? otherUserName;
  final String? otherUserImage;
  final String? otherUserPhone;

  const ChatScreen({
    super.key,
    required this.jobId,
    this.otherUserName,
    this.otherUserImage,
    this.otherUserPhone,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _isHydratingOtherUser = false;
  String? _resolvedOtherUserName;
  String? _resolvedOtherUserImage;
  String? _resolvedOtherUserPhone;

  @override
  void initState() {
    super.initState();
    _resolvedOtherUserName = widget.otherUserName;
    _resolvedOtherUserImage = widget.otherUserImage;
    _resolvedOtherUserPhone = widget.otherUserPhone;
    _hydrateOtherUserDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _handleSend(String content) async {
    if (_isSending) return;

    setState(() => _isSending = true);

    final errorMessage = await ref
        .read(chatControllerProvider(widget.jobId).notifier)
        .sendMessage(content);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (errorMessage == null) {
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _resolveOtherUserPhone() async {
    if (_resolvedOtherUserPhone != null &&
        _resolvedOtherUserPhone!.trim().isNotEmpty) {
      return _resolvedOtherUserPhone!.trim();
    }

    final currentUserId = _currentUserIdOrNull();
    if (currentUserId == null) return null;

    final job = await ref.read(jobRepositoryProvider).getJob(widget.jobId);
    if (job == null) return null;

    if (job.customerId == currentUserId) {
      return job.technician?['phone']?.toString();
    }

    if (job.technicianId == currentUserId) {
      return job.customer?['phone']?.toString();
    }

    return null;
  }

  Future<void> _hydrateOtherUserDetails() async {
    if (_isHydratingOtherUser) {
      return;
    }

    final needsName =
        _resolvedOtherUserName == null ||
        _resolvedOtherUserName!.trim().isEmpty;
    final needsImage =
        _resolvedOtherUserImage == null ||
        _resolvedOtherUserImage!.trim().isEmpty;
    final needsPhone =
        _resolvedOtherUserPhone == null ||
        _resolvedOtherUserPhone!.trim().isEmpty;

    if (!needsName && !needsImage && !needsPhone) {
      return;
    }

    final currentUserId = _currentUserIdOrNull();
    if (currentUserId == null) {
      return;
    }

    _isHydratingOtherUser = true;

    try {
      final job = await ref.read(jobRepositoryProvider).getJob(widget.jobId);
      if (!mounted || job == null) return;

      final otherParty = job.customerId == currentUserId
          ? job.technician
          : job.customer;

      if (otherParty == null) return;

      setState(() {
        _resolvedOtherUserName ??= otherParty['full_name']?.toString();
        _resolvedOtherUserImage ??= otherParty['profile_image_url']?.toString();
        _resolvedOtherUserPhone ??= otherParty['phone']?.toString();
      });
    } finally {
      _isHydratingOtherUser = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsOtherUserHydration =
        (_resolvedOtherUserName == null ||
            _resolvedOtherUserName!.trim().isEmpty) ||
        (_resolvedOtherUserImage == null ||
            _resolvedOtherUserImage!.trim().isEmpty) ||
        (_resolvedOtherUserPhone == null ||
            _resolvedOtherUserPhone!.trim().isEmpty);
    if (needsOtherUserHydration && !_isHydratingOtherUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _hydrateOtherUserDetails();
        }
      });
    }

    final chatState = ref.watch(chatControllerProvider(widget.jobId));
    final currentUserId = _currentUserIdOrNull();
    final chatError = chatState.asError?.error;
    final isCommunicationBlocked = _isCommunicationBlocked(chatError);
    final canSendMessages = chatState.hasValue;

    // Auto scroll when new messages arrive
    ref.listen(chatControllerProvider(widget.jobId), (previous, next) {
      if (next.hasValue &&
          previous?.valueOrNull?.length != next.value?.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Other user avatar
            Builder(
              builder: (context) {
                final avatarUrl = widget.otherUserImage?.trim();
                final resolvedAvatarUrl = _resolvedOtherUserImage?.trim();
                final effectiveAvatarUrl =
                    avatarUrl != null && avatarUrl.isNotEmpty
                    ? avatarUrl
                    : (resolvedAvatarUrl != null &&
                          resolvedAvatarUrl.isNotEmpty)
                    ? resolvedAvatarUrl
                    : null;
                final hasAvatar = effectiveAvatarUrl != null;
                return CircleAvatar(
                  radius: 18,
                  backgroundImage: hasAvatar
                      ? NetworkImage(effectiveAvatarUrl)
                      : null,
                  child: !hasAvatar
                      ? Text(
                          (_resolvedOtherUserName ??
                                  widget.otherUserName ??
                                  '?')[0]
                              .toUpperCase(),
                          style: const TextStyle(fontSize: 14),
                        )
                      : null,
                );
              },
            ),
            const SizedBox(width: 12),
            // Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _resolvedOtherUserName ?? widget.otherUserName ?? 'محادثة',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'متصل',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Phone call action
          if (!isCommunicationBlocked)
            IconButton(
              icon: const Icon(Icons.phone_outlined),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);

                try {
                  final phoneNumber = await _resolveOtherUserPhone();

                  if (phoneNumber != null) {
                    final uri = Uri.parse('tel:$phoneNumber');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('فشل فتح تطبيق الهاتف')),
                      );
                    }
                  } else {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('رقم الهاتف غير متوفر')),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(ErrorHandler.getMessage(e))),
                  );
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: chatState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCommunicationBlocked
                          ? Icons.lock_outline
                          : Icons.error_outline,
                      size: 48,
                      color: isCommunicationBlocked
                          ? Colors.orange.shade700
                          : Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(ErrorHandler.getMessage(error)),
                    if (!isCommunicationBlocked) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(chatControllerProvider(widget.jobId).notifier)
                            .refresh(),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ],
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد رسائل بعد',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ابدأ المحادثة الآن!',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    // Show date separator if needed
                    Widget? dateSeparator;
                    if (index == 0 ||
                        _shouldShowDateSeparator(
                          messages[index - 1].createdAt,
                          message.createdAt,
                        )) {
                      dateSeparator = _buildDateSeparator(message.createdAt);
                    }

                    return Column(
                      children: [
                        if (dateSeparator != null) dateSeparator,
                        ChatBubble(message: message, isMe: isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input field
          if (canSendMessages)
            ChatInput(onSend: _handleSend, isLoading: _isSending),
        ],
      ),
    );
  }

  bool _isCommunicationBlocked(dynamic error) {
    if (error == null) return false;

    if (error is DioException) {
      return ApiError.fromDioException(error).code ==
          'COMMUNICATION_NOT_AVAILABLE';
    }

    return ErrorHandler.getMessage(error) ==
        ErrorMessages.fromApiCode('COMMUNICATION_NOT_AVAILABLE');
  }

  String? _currentUserIdOrNull() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  bool _shouldShowDateSeparator(DateTime previous, DateTime current) {
    return previous.day != current.day ||
        previous.month != current.month ||
        previous.year != current.year;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    String text;
    if (messageDate == today) {
      text = 'اليوم';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      text = 'أمس';
    } else {
      text = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
