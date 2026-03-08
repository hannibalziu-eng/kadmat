import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/utils/error_messages.dart';
import '../domain/conversation_thread.dart';
import '../domain/message.dart';

part 'messages_repository.g.dart';

class MessagesRepository {
  MessagesRepository(this._client, this._supabase);

  final Dio _client;
  final SupabaseClient _supabase;

  Future<List<Message>> getMessages(String jobId) async {
    try {
      final response = await _client.get(Endpoints.messagesForJob(jobId));
      final data = response.data['data'] as List? ?? const [];
      return data
          .map(
            (json) => Message.fromJson(
              json is Map<String, dynamic>
                  ? json
                  : Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw _toUserFacingException(e);
    }
  }

  Future<Message> sendMessage({
    required String jobId,
    required String content,
    String? receiverId,
  }) async {
    try {
      final response = await _client.post(
        Endpoints.messagesForJob(jobId),
        data: {'content': content},
      );
      final data = response.data['data'];
      return Message.fromJson(
        data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data),
      );
    } on DioException catch (e) {
      throw _toUserFacingException(e);
    }
  }

  Stream<List<Message>> watchMessages(String jobId) async* {
    yield await getMessages(jobId);
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 3));
      yield await getMessages(jobId);
    }
  }

  Future<int> markAsRead(String jobId) async {
    try {
      final response = await _client.patch(Endpoints.markMessagesRead(jobId));
      final payload = response.data['data'];
      if (payload is Map<String, dynamic>) {
        return (payload['updated_count'] as num?)?.toInt() ?? 0;
      }
      if (payload is Map) {
        return (payload['updated_count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      throw _toUserFacingException(e);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _client.get(Endpoints.messageUnreadCount);
      final payload = response.data['data'];
      if (payload is Map<String, dynamic>) {
        return (payload['total'] as num?)?.toInt() ?? 0;
      }
      if (payload is Map) {
        return (payload['total'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      throw _toUserFacingException(e);
    }
  }

  Future<List<UnreadCountByJob>> getUnreadCountByJob() async {
    try {
      final response = await _client.get(Endpoints.messageUnreadCount);
      final payload = response.data['data'];
      final byJob = payload is Map<String, dynamic>
          ? payload['by_job'] as List? ?? const []
          : payload is Map
          ? payload['by_job'] as List? ?? const []
          : const [];

      return byJob
          .map(
            (json) => UnreadCountByJob.fromJson(
              json is Map<String, dynamic>
                  ? json
                  : Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw _toUserFacingException(e);
    }
  }

  Future<List<ConversationThread>> getConversationThreads() async {
    try {
      final response = await _client.get(Endpoints.messageConversations);
      final data = response.data['data'] as List? ?? const [];
      return data
          .map(
            (json) => ConversationThread.fromJson(
              json is Map<String, dynamic>
                  ? json
                  : Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw _toUserFacingException(e);
    }
  }

  Future<List<Conversation>> getConversations() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final threads = await getConversationThreads();

    return threads
        .map(
          (thread) => Conversation(
            jobId: thread.jobId,
            status: thread.status,
            serviceName: thread.serviceName,
            otherUser: thread.otherUser == null
                ? null
                : ConversationUser(
                    id: thread.otherUser!.id,
                    fullName: thread.otherUser!.fullName,
                    profileImageUrl: thread.otherUser!.profileImageUrl,
                  ),
            unreadCount: thread.unreadCount,
          ),
        )
        .where(
          (thread) =>
              currentUserId == null || thread.otherUser?.id != currentUserId,
        )
        .toList();
  }

  Exception _toUserFacingException(DioException error) {
    final apiError = ApiError.fromDioException(error);
    return Exception(
      ErrorMessages.fromApiCode(apiError.code, fallback: apiError.message),
    );
  }
}

@Riverpod(keepAlive: true)
MessagesRepository messagesRepository(Ref ref) {
  return MessagesRepository(
    ref.watch(apiClientProvider),
    Supabase.instance.client,
  );
}

final conversationThreadsProvider =
    FutureProvider.autoDispose<List<ConversationThread>>((ref) async {
      final repo = ref.watch(messagesRepositoryProvider);
      return repo.getConversationThreads();
    });

@riverpod
Future<int> unreadMessageCount(Ref ref) async {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.getUnreadCount();
}

@riverpod
Future<List<Conversation>> conversations(Ref ref) async {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.getConversations();
}
