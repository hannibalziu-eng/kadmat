import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/api_client.dart';

part 'notification_repository.g.dart';

class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'],
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'],
      data: json['data'] ?? {},
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class NotificationRepository {
  final Dio _client;

  NotificationRepository(this._client);

  Future<List<NotificationItem>> getNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _client.get(
        '/notifications',
        queryParameters: {
          'page': page,
          'limit': limit,
          'unread_only': unreadOnly,
        },
      );
      final List data = response.data['notifications'] ?? [];
      return data.map((e) => NotificationItem.fromJson(e)).toList();
    } catch (e) {
      throw Exception('فشل جلب الإشعارات');
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _client.get('/notifications/unread-count');
      return response.data['unread_count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client.post('/notifications/$notificationId/read');
    } catch (e) {
      throw Exception('فشل تحديث الإشعار');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _client.post('/notifications/mark-all-read');
    } catch (e) {
      throw Exception('فشل تحديث الإشعارات');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _client.delete('/notifications/$notificationId');
    } catch (e) {
      throw Exception('فشل حذف الإشعار');
    }
  }

  /// Watch notifications in real-time
  Stream<List<NotificationItem>> watchNotifications(String userId) {
    return Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => NotificationItem.fromJson(e)).toList());
  }
}

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(NotificationRepositoryRef ref) {
  final client = ref.watch(apiClientProvider);
  return NotificationRepository(client);
}

@riverpod
Stream<int> unreadNotificationCount(UnreadNotificationCountRef ref) async* {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    yield 0;
    return;
  }

  yield* Supabase.instance.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((data) => data.where((n) => n['is_read'] == false).length);
}
