import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/messages_repository.dart';
import '../domain/message.dart';

part 'chat_controller.g.dart';

/// Controller for managing chat state and actions
@riverpod
class ChatController extends _$ChatController {
  StreamSubscription<List<Message>>? _subscription;
  String? _jobId;
  String? _otherPartyId;

  @override
  AsyncValue<List<Message>> build(String jobId) {
    _jobId = jobId;
    _initializeChat();

    // Cleanup when disposed
    ref.onDispose(() {
      _subscription?.cancel();
    });

    return const AsyncValue.loading();
  }

  /// Initialize chat: load messages and subscribe to updates
  Future<void> _initializeChat() async {
    if (_jobId == null) return;

    final repo = ref.read(messagesRepositoryProvider);

    try {
      // Get other party ID for sending messages
      _otherPartyId = await repo.getOtherPartyId(_jobId!);

      // Load initial messages
      final messages = await repo.getMessages(_jobId!);
      state = AsyncValue.data(messages);

      // Mark as read
      await repo.markAsRead(_jobId!);

      // Subscribe to real-time updates
      _subscription = repo
          .watchMessages(_jobId!)
          .listen(
            (messages) {
              state = AsyncValue.data(messages);
              // Mark new messages as read automatically
              repo.markAsRead(_jobId!);
            },
            onError: (error) {
              state = AsyncValue.error(error, StackTrace.current);
            },
          );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Send a message
  Future<bool> sendMessage(String content) async {
    if (_jobId == null || _otherPartyId == null) {
      return false;
    }

    if (content.trim().isEmpty) return false;

    try {
      final repo = ref.read(messagesRepositoryProvider);
      await repo.sendMessage(
        jobId: _jobId!,
        content: content.trim(),
        receiverId: _otherPartyId!,
      );
      return true;
    } catch (e) {
      // Could show error to user here
      return false;
    }
  }

  /// Refresh messages
  Future<void> refresh() async {
    if (_jobId == null) return;

    state = const AsyncValue.loading();
    final repo = ref.read(messagesRepositoryProvider);

    try {
      final messages = await repo.getMessages(_jobId!);
      state = AsyncValue.data(messages);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Mark all messages as read
  Future<void> markAllAsRead() async {
    if (_jobId == null) return;

    final repo = ref.read(messagesRepositoryProvider);
    await repo.markAsRead(_jobId!);
  }
}

/// Provider for getting unread count for a specific job
@riverpod
Future<int> jobUnreadCount(Ref ref, String jobId) async {
  final byJob = await ref
      .read(messagesRepositoryProvider)
      .getUnreadCountByJob();

  return byJob
      .firstWhere(
        (u) => u.jobId == jobId,
        orElse: () => UnreadCountByJob(jobId: jobId, unreadCount: 0),
      )
      .unreadCount;
}
