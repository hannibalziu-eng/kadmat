import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_notifications.dart';
import 'fcm_service.dart';
import 'push/push_gateway.dart';
import '../../features/auth/data/auth_repository.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation/app_routes.dart';

part 'notification_service.g.dart';

class NotificationService {
  final SupabaseClient _supabase;
  final LocalNotificationsService _localNotifications;
  final PushGateway _pushGateway;
  final AuthRepository _authRepository;
  bool _isInitialized = false;

  StreamSubscription<String>? _tokenRefreshSubscription;
  RealtimeChannel? _technicianJobsChannel;
  RealtimeChannel? _customerJobsChannel;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _newRequestsChannel;

  String? _technicianJobsUserId;
  String? _customerJobsUserId;
  String? _messagesUserId;

  NotificationService(
    this._supabase,
    this._localNotifications,
    this._pushGateway,
    this._authRepository,
  );

  /// Initialize and request permissions
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _pushGateway.initialize();

    // Listen for FCM token refresh and update profile
    _tokenRefreshSubscription = _pushGateway.onTokenRefresh.listen((token) {
      _authRepository.updateProfile(fcmToken: token).catchError((_) {});
    });

    // Also update token on initial launch if available
    final token = _pushGateway.currentToken;
    if (token != null) {
      unawaited(
        _authRepository.updateProfile(fcmToken: token).catchError((_) {}),
      );
    }
  }

  /// Subscribe to notifications for a specific job
  Future<void> subscribeToJob(String jobId) async {
    await _pushGateway.subscribeToTopic('job_$jobId');
  }

  /// Unsubscribe from job notifications
  Future<void> unsubscribeFromJob(String jobId) async {
    await _pushGateway.unsubscribeFromTopic('job_$jobId');
  }

  /// Listen for job updates where the user is the Technician
  void listenForJobUpdates(String technicianId) {
    if (technicianId.isEmpty) return;
    if (_technicianJobsUserId == technicianId &&
        _technicianJobsChannel != null) {
      return;
    }

    if (_technicianJobsChannel != null) {
      unawaited(_supabase.removeChannel(_technicianJobsChannel!));
      _technicianJobsChannel = null;
    }

    final channel = _supabase.channel('public:jobs:technician:$technicianId');
    channel
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

    _technicianJobsChannel = channel;
    _technicianJobsUserId = technicianId;
  }

  /// Listen for job updates where the user is the Customer
  void listenForCustomerJobUpdates(String customerId) {
    if (customerId.isEmpty) return;
    if (_customerJobsUserId == customerId && _customerJobsChannel != null) {
      return;
    }

    if (_customerJobsChannel != null) {
      unawaited(_supabase.removeChannel(_customerJobsChannel!));
      _customerJobsChannel = null;
    }

    final channel = _supabase.channel('public:jobs:customer:$customerId');
    channel
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

    _customerJobsChannel = channel;
    _customerJobsUserId = customerId;
  }

  /// Listen for new messages for the user
  void listenForMessages(String userId) {
    if (userId.isEmpty) return;
    if (_messagesUserId == userId && _messagesChannel != null) {
      return;
    }

    if (_messagesChannel != null) {
      unawaited(_supabase.removeChannel(_messagesChannel!));
      _messagesChannel = null;
    }

    final channel = _supabase.channel('public:messages:$userId');
    channel
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

    _messagesChannel = channel;
    _messagesUserId = userId;
  }

  void listenForNewRequests(double latitude, double longitude) {
    // Note: Supabase Realtime doesn't support complex spatial filters easily.
    // For MVP, we might just listen to ALL pending jobs and filter client-side
    // or rely on polling.
    // Here we listen to all inserts on jobs table where status is pending.
    // Ideally, we would filter by location, but that requires PostGIS support in Realtime which is limited.

    if (_newRequestsChannel != null) return;

    final channel = _supabase.channel('public:jobs:pending');
    channel
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
            final jobId = payload.newRecord['id'] as String?;
            if (jobId == null || jobId.isEmpty) return;

            // Trigger a local notification for a new job request.
            // Nearby filtering remains handled by dashboard RPC stream.
            _localNotifications.showNotification(
              id: jobId.hashCode,
              title: 'طلب جديد',
              body: 'يوجد طلب خدمة جديد بالقرب منك',
              payload: jobId,
            );
          },
        )
        .subscribe();

    _newRequestsChannel = channel;
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
            case 'on_the_way':
              title = 'تم قبول السعر';
              body = 'وافق العميل على عرض السعر. تحرّك الآن إلى موقع العميل.';
              break;
            case 'arrived':
              title = 'تم تسجيل الوصول';
              body = 'تم تحديث الحالة إلى: وصلت إلى موقع العميل.';
              break;
            case 'in_progress':
              title = 'تم بدء التنفيذ';
              body = 'تم تحديث الحالة إلى: جاري تنفيذ الخدمة.';
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
            case 'on_the_way':
              title = 'الفني في الطريق';
              body = 'وافقْت على السعر، والفني متجه إليك الآن.';
              break;
            case 'arrived':
              title = 'الفني وصل';
              body = 'الفني وصل إلى موقعك.';
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

  /// Handle notification tap (local or remote)
  Future<void> handleNotificationTap(
    Map<String, dynamic> data,
    BuildContext context,
  ) async {
    final type = data['type'];

    if (type == 'waitlist_offer') {
      final waitlistId = data['waitlist_id'];
      if (waitlistId != null) {
        context.push(AppRoutes.buildWaitlistOfferPath(waitlistId));
      }
    }
    // ... handle other types
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();

    if (_technicianJobsChannel != null) {
      await _supabase.removeChannel(_technicianJobsChannel!);
      _technicianJobsChannel = null;
    }
    if (_customerJobsChannel != null) {
      await _supabase.removeChannel(_customerJobsChannel!);
      _customerJobsChannel = null;
    }
    if (_messagesChannel != null) {
      await _supabase.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
    if (_newRequestsChannel != null) {
      await _supabase.removeChannel(_newRequestsChannel!);
      _newRequestsChannel = null;
    }

    _technicianJobsUserId = null;
    _customerJobsUserId = null;
    _messagesUserId = null;
    _isInitialized = false;
  }
}

@riverpod
NotificationService notificationService(Ref ref) {
  final service = NotificationService(
    Supabase.instance.client,
    ref.watch(localNotificationsProvider),
    ref.watch(pushGatewayProvider),
    ref.watch(authRepositoryProvider),
  );

  ref.onDispose(() {
    unawaited(service.dispose());
  });

  return service;
}
