import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Notification Model ---
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String? type; // 'new_job', 'price_set', 'info', etc.
  final String? jobId; // Related Job ID for navigation

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.type,
    this.jobId,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? jobId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      jobId: jobId ?? this.jobId,
    );
  }
}

// --- State Management ---
class NotificationListNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationListNotifier() : super([]);

  // Add a new notification (e.g. from FCM)
  void addNotification(NotificationModel notification) {
    state = [notification, ...state];
  }

  // Mark a notification as read
  void markAsRead(String notificationId) {
    state = [
      for (final notif in state)
        if (notif.id == notificationId) notif.copyWith(isRead: true) else notif,
    ];
  }

  // Mark all as read
  void markAllAsRead() {
    state = [for (final notif in state) notif.copyWith(isRead: true)];
  }

  // Delete a notification
  void deleteNotification(String notificationId) {
    state = state.where((n) => n.id != notificationId).toList();
  }

  // Get unread count
  int get unreadCount => state.where((n) => !n.isRead).length;
}

// --- Provider ---
final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, List<NotificationModel>>((
      ref,
    ) {
      return NotificationListNotifier();
    });
