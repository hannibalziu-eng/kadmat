import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final String? audienceRole;
  final String? category;
  final List<String> channels;
  final int? priority;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.data,
    this.audienceRole,
    this.category,
    this.channels = const [],
    this.priority,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels'];
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString(),
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const <String, dynamic>{},
      audienceRole: json['audience_role']?.toString(),
      category: json['category']?.toString(),
      channels: rawChannels is List
          ? rawChannels.map((channel) => channel.toString()).toList()
          : const <String>[],
      priority: (json['priority'] as num?)?.toInt(),
      isRead: json['is_read'] ?? false,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class NotificationRepository {
  final Dio _client;
  static const _pollInterval = Duration(seconds: 5);

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
      final payload = response.data;
      final dynamic notifications = payload is Map<String, dynamic>
          ? payload['notifications'] ??
                (payload['data'] is Map<String, dynamic>
                    ? payload['data']['notifications']
                    : null)
          : null;
      final data = notifications is List ? notifications : const [];
      return data
          .map(
            (item) => NotificationItem.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (e) {
      throw Exception('فشل جلب الإشعارات');
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _client.get('/notifications/unread-count');
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        final nested = payload['data'];
        if (nested is Map<String, dynamic>) {
          return (nested['unread_count'] as num?)?.toInt() ?? 0;
        }
        return (payload['unread_count'] as num?)?.toInt() ?? 0;
      }
      if (payload is Map) {
        final nested = payload['data'];
        if (nested is Map) {
          return (nested['unread_count'] as num?)?.toInt() ?? 0;
        }
        return (payload['unread_count'] as num?)?.toInt() ?? 0;
      }
      return 0;
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

  Stream<List<NotificationItem>> watchNotifications() async* {
    yield await getNotifications();
    while (true) {
      await Future<void>.delayed(_pollInterval);
      yield await getNotifications();
    }
  }
}

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return NotificationRepository(client);
}

@riverpod
Stream<int> unreadNotificationCount(Ref ref) async* {
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser == null) {
    yield 0;
    return;
  }

  final repository = ref.watch(notificationRepositoryProvider);
  yield await repository.getUnreadCount();
  while (true) {
    await Future<void>.delayed(NotificationRepository._pollInterval);
    yield await repository.getUnreadCount();
  }
}

/// Durable notifications stream for the currently authenticated user.
final liveNotificationsProvider =
    StreamProvider.autoDispose<List<NotificationItem>>((ref) {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        return Stream.value(const <NotificationItem>[]);
      }

      final repository = ref.watch(notificationRepositoryProvider);
      return repository.watchNotifications();
    });

/// Readable unread counter derived from the durable notifications stream.
final liveUnreadNotificationsCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(liveNotificationsProvider);
  return notificationsAsync.maybeWhen(
    data: (items) => items.where((item) => !item.isRead).length,
    orElse: () => 0,
  );
});
