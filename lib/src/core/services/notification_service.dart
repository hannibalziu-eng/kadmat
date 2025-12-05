import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'local_notifications.dart';

part 'notification_service.g.dart';

class NotificationService {
  final SupabaseClient _supabase;
  final LocalNotificationsService _localNotifications;

  NotificationService(this._supabase, this._localNotifications);

  void listenForJobUpdates(String userId) {
    _supabase
        .channel('public:jobs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'technician_id',
            value: userId,
          ),
          callback: (payload) {
            _handleJobUpdate(payload);
          },
        )
        .subscribe();
  }

  void listenForNewRequests(double latitude, double longitude) {
    // Note: Supabase Realtime doesn't support complex spatial filters easily.
    // For MVP, we might just listen to ALL pending jobs and filter client-side
    // or rely on polling.
    // Here we listen to all inserts on jobs table where status is pending.
    // Ideally, we would filter by location, but that requires PostGIS support in Realtime which is limited.

    _supabase
        .channel('public:jobs:pending')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'pending',
          ),
          callback: (payload) {
            // Trigger a local notification for a new job request
            // In a real app, we would check distance here before notifying
            _localNotifications.showNotification(
              id: 1,
              title: 'طلب جديد',
              body: 'يوجد طلب خدمة جديد بالقرب منك',
            );
          },
        )
        .subscribe();
  }

  void _handleJobUpdate(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.update) {
      final newStatus = payload.newRecord['status'];
      final oldStatus = payload.oldRecord['status'];

      if (newStatus != oldStatus) {
        _localNotifications.showNotification(
          id: 2,
          title: 'تحديث حالة الطلب',
          body: 'تم تغيير حالة الطلب إلى $newStatus',
        );
      }
    }
  }
}

@riverpod
NotificationService notificationService(NotificationServiceRef ref) {
  return NotificationService(
    Supabase.instance.client,
    LocalNotificationsService(), // We should probably use a provider for this too
  );
}
