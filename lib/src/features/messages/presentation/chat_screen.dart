import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_controller.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';

/// Chat screen for messaging between customer and technician
class ChatScreen extends ConsumerStatefulWidget {
  final String jobId;
  final String? otherUserName;
  final String? otherUserImage;

  const ChatScreen({
    super.key,
    required this.jobId,
    this.otherUserName,
    this.otherUserImage,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  bool _isSending = false;

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

    final success = await ref
        .read(chatControllerProvider(widget.jobId).notifier)
        .sendMessage(content);

    setState(() => _isSending = false);

    if (success) {
      _scrollToBottom();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل إرسال الرسالة، حاول مرة أخرى'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider(widget.jobId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

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
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherUserImage != null
                  ? NetworkImage(widget.otherUserImage!)
                  : null,
              child: widget.otherUserImage == null
                  ? Text(
                      (widget.otherUserName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName ?? 'محادثة',
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
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            onPressed: () {
              // TODO: Implement phone call
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
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('حدث خطأ: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(chatControllerProvider(widget.jobId).notifier)
                          .refresh(),
                      child: const Text('إعادة المحاولة'),
                    ),
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
          ChatInput(onSend: _handleSend, isLoading: _isSending),
        ],
      ),
    );
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
