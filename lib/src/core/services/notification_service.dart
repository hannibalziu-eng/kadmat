import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'local_notifications.dart';
import 'fcm_service.dart';
import '../../features/auth/data/auth_repository.dart';

part 'notification_service.g.dart';

class NotificationService {
  final SupabaseClient _supabase;
  final LocalNotificationsService _localNotifications;
  final FcmService _fcmService;
  final AuthRepository _authRepository;

  NotificationService(
    this._supabase,
    this._localNotifications,
    this._fcmService,
    this._authRepository,
  );

  /// Initialize and request permissions
  Future<void> initialize() async {
    await _fcmService.initialize();

    // Listen for FCM token refresh and update profile
    _fcmService.onTokenRefresh.listen((token) {
      _authRepository.updateProfile(fcmToken: token);
    });

    // Also update token on initial launch if available
    final token = _fcmService.fcmToken;
    if (token != null) {
      // We don't await this to not block initialization
      _authRepository.updateProfile(fcmToken: token).catchError((e) {
        // Limit logging or ignore if user not logged in
      });
    }
  }

  /// Subscribe to notifications for a specific job
  Future<void> subscribeToJob(String jobId) async {
    await _fcmService.subscribeToTopic('job_$jobId');
  }

  /// Unsubscribe from job notifications
  Future<void> unsubscribeFromJob(String jobId) async {
    await _fcmService.unsubscribeFromTopic('job_$jobId');
  }

  /// Listen for job updates where the user is the Technician
  void listenForJobUpdates(String technicianId) {
    _supabase
        .channel('public:jobs:technician:$technicianId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'technician_id',
            value: technicianId,
          ),
          callback: (payload) {
            _handleJobUpdate(payload, isTechnician: true);
          },
        )
        .subscribe();
  }

  /// Listen for job updates where the user is the Customer
  void listenForCustomerJobUpdates(String customerId) {
    _supabase
        .channel('public:jobs:customer:$customerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (payload) {
            _handleJobUpdate(payload, isTechnician: false);
          },
        )
        .subscribe();
  }

  /// Listen for new messages for the user
  void listenForMessages(String userId) {
    _supabase
        .channel('public:messages:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final content = newRecord['content'] as String;
            final jobId = newRecord['job_id'] as String;

            _localNotifications.showNotification(
              id: DateTime.now().millisecondsSinceEpoch, // Unique ID
              title: 'رسالة جديدة',
              body: content,
              payload: jobId, // Navigate to job details
            );
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

  void _handleJobUpdate(
    PostgresChangePayload payload, {
    required bool isTechnician,
  }) {
    if (payload.eventType == PostgresChangeEvent.update) {
      final newStatus = payload.newRecord['status'];
      final oldStatus = payload.oldRecord['status'];
      final jobId = payload.newRecord['id'];

      if (newStatus != oldStatus) {
        String? title;
        String? body;

        // Technician Notifications
        if (isTechnician) {
          switch (newStatus) {
            case 'customer_agreed':
              title = 'تم قبول السعر';
              body = 'وافق العميل على عرض السعر. يمكنك البدء في العمل.';
              break;
            case 'completed': // Payment confirmed
              title = 'تم الدفع';
              body = 'قام العميل بتأكيد الدفع وإتمام الطلب.';
              break;
            case 'cancelled':
              title = 'تم إلغاء الطلب';
              body = 'قام العميل بإلغاء الطلب.';
              break;
          }
        }
        // Customer Notifications
        else {
          switch (newStatus) {
            case 'accepted':
              title = 'تم قبول طلبك';
              body = 'وافق فني على طلبك. جاري الانتظار لعرض السعر.';
              break;
            case 'price_pending':
              title = 'عرض سعر جديد';
              body = 'أرسل الفني عرض سعر للخدمة. يرجى المراجعة.';
              break;
            case 'in_progress':
              title = 'بدأ العمل';
              body = 'بدأ الفني في تنفيذ الخدمة.';
              break;
            case 'pending_confirm':
              title = 'انتهى العمل';
              body = 'أنهى الفني العمل. يرجى تأكيد الإنجاز والدفع.';
              break;
            case 'cancelled':
              title = 'تم إلغاء الطلب';
              body = 'قام الفني بإلغاء الطلب.';
              break;
          }
        }

        if (title != null && body != null) {
          _localNotifications.showNotification(
            id: jobId.hashCode,
            title: title,
            body: body,
            payload: jobId, // Pass Job ID for navigation
          );
        }
      }
    }
  }
}

@riverpod
NotificationService notificationService(NotificationServiceRef ref) {
  return NotificationService(
    Supabase.instance.client,
    LocalNotificationsService(), // We should probably use a provider for this too
    FcmService(),
    ref.watch(authRepositoryProvider),
  );
}
