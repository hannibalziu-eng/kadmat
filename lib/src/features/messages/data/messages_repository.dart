import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/message.dart';

part 'messages_repository.g.dart';

/// Repository for handling chat messages between customers and technicians
class MessagesRepository {
  final SupabaseClient _client;

  MessagesRepository(this._client);

  /// Get all messages for a specific job
  Future<List<Message>> getMessages(String jobId) async {
    final response = await _client
        .from('messages')
        .select('''
          id,
          job_id,
          sender_id,
          receiver_id,
          content,
          is_read,
          created_at,
          read_at,
          sender:users!sender_id(id, full_name, profile_image_url)
        ''')
        .eq('job_id', jobId)
        .order('created_at', ascending: true);

    return (response as List).map((json) => Message.fromJson(json)).toList();
  }

  /// Send a new message
  Future<Message> sendMessage({
    required String jobId,
    required String content,
    required String receiverId,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) throw Exception('يجب تسجيل الدخول أولاً');

    final response = await _client
        .from('messages')
        .insert({
          'job_id': jobId,
          'sender_id': senderId,
          'receiver_id': receiverId,
          'content': content,
        })
        .select('''
      id,
      job_id,
      sender_id,
      receiver_id,
      content,
      is_read,
      created_at,
      sender:users!sender_id(id, full_name, profile_image_url)
    ''')
        .single();

    return Message.fromJson(response);
  }

  /// Subscribe to real-time messages for a job
  Stream<List<Message>> watchMessages(String jobId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('created_at', ascending: true)
        .map((data) => data.map((json) => Message.fromJson(json)).toList());
  }

  /// Mark all messages in a job as read for current user
  Future<int> markAsRead(String jobId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final result = await _client.rpc(
      'mark_messages_as_read',
      params: {'p_job_id': jobId, 'p_user_id': userId},
    );

    return result as int? ?? 0;
  }

  /// Get total unread message count for current user
  Future<int> getUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final result = await _client.rpc(
      'get_unread_count',
      params: {'p_user_id': userId},
    );

    return result as int? ?? 0;
  }

  /// Get unread counts grouped by job
  Future<List<UnreadCountByJob>> getUnreadCountByJob() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final result = await _client.rpc(
      'get_unread_count_by_job',
      params: {'p_user_id': userId},
    );

    return (result as List)
        .map((json) => UnreadCountByJob.fromJson(json))
        .toList();
  }

  /// Get all conversations (chats) for current user
  Future<List<Conversation>> getConversations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Get jobs where user is participant and has technician assigned
    final response = await _client
        .from('jobs')
        .select('''
          id,
          status,
          customer:users!customer_id(id, full_name, profile_image_url),
          technician:users!technician_id(id, full_name, profile_image_url),
          service:services(id, name)
        ''')
        .or('customer_id.eq.$userId,technician_id.eq.$userId')
        .not('technician_id', 'is', null)
        .order('created_at', ascending: false);

    // Get unread counts
    final unreadCounts = await getUnreadCountByJob();
    final unreadMap = {for (var u in unreadCounts) u.jobId: u.unreadCount};

    return (response as List).map((job) {
      final customerId = job['customer']?['id'];
      final otherUser = customerId == userId
          ? job['technician']
          : job['customer'];

      return Conversation(
        jobId: job['id'],
        status: job['status'],
        serviceName: job['service']?['name'],
        otherUser: otherUser != null
            ? ConversationUser.fromJson(otherUser)
            : null,
        unreadCount: unreadMap[job['id']] ?? 0,
      );
    }).toList();
  }

  /// Get the other party's ID for a job (to send message to)
  Future<String?> getOtherPartyId(String jobId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('jobs')
        .select('customer_id, technician_id')
        .eq('id', jobId)
        .maybeSingle();

    if (response == null) return null;

    final customerId = response['customer_id'];
    final technicianId = response['technician_id'];

    // Return the other party
    if (customerId == userId) return technicianId;
    if (technicianId == userId) return customerId;
    return null;
  }
}

@Riverpod(keepAlive: true)
MessagesRepository messagesRepository(Ref ref) {
  return MessagesRepository(Supabase.instance.client);
}

/// Provider for unread message count
@riverpod
Future<int> unreadMessageCount(Ref ref) async {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.getUnreadCount();
}

/// Provider for conversations list
@riverpod
Future<List<Conversation>> conversations(Ref ref) async {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.getConversations();
}
