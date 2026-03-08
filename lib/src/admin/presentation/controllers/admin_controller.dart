import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/admin_models.dart';
import '../../data/admin_repository.dart';

part 'admin_controller.g.dart';

/// Controller for admin dashboard functionality
@riverpod
class AdminController extends _$AdminController {
  @override
  FutureOr<void> build() {}

  /// Load platform statistics
  Future<PlatformStats> loadPlatformStats() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final stats = await repo.getPlatformStats();
      state = const AsyncValue.data(null);
      return stats;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Load user growth data
  Future<List<UserGrowthStat>> loadUserGrowth({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final growthData = await repo.getUserGrowth(
        startDate: startDate,
        endDate: endDate,
      );
      state = const AsyncValue.data(null);
      return growthData;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Load job statistics by service
  Future<List<JobStatByService>> loadJobStatsByService() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final stats = await repo.getJobStatsByService();
      state = const AsyncValue.data(null);
      return stats;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Load technician performance
  Future<List<TechnicianPerformance>> loadTechnicianPerformance() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final performance = await repo.getTechnicianPerformance();
      state = const AsyncValue.data(null);
      return performance;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Load revenue statistics
  Future<RevenueStats> loadRevenueStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final stats = await repo.getRevenueStats(
        startDate: startDate,
        endDate: endDate,
      );
      state = const AsyncValue.data(null);
      return stats;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Load system health
  Future<SystemHealth> loadSystemHealth() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final health = await repo.getSystemHealth();
      state = const AsyncValue.data(null);
      return health;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Load admin notifications
  Future<List<AdminNotification>> loadNotifications({
    int limit = 50,
    bool onlyUnread = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final notifications = await repo.getAdminNotifications(
        limit: limit,
        onlyUnread: onlyUnread,
      );
      state = const AsyncValue.data(null);
      return notifications;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final success = await repo.markNotificationAsRead(notificationId);

      // Refresh notifications list if successful
      if (success) {
        ref.invalidate(adminNotificationsProvider);
      }

      return success;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Load all users
  Future<List<Map<String, dynamic>>> loadAllUsers({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    String? userType,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final users = await repo.getAllUsers(
        page: page,
        limit: limit,
        searchQuery: searchQuery,
        userType: userType,
      );
      state = const AsyncValue.data(null);
      return users;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Load all jobs
  Future<List<Map<String, dynamic>>> loadAllJobs({
    int page = 1,
    int limit = 20,
    String? status,
    String? serviceId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final jobs = await repo.getAllJobs(
        page: page,
        limit: limit,
        status: status,
        serviceId: serviceId,
      );
      state = const AsyncValue.data(null);
      return jobs;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Update user status
  Future<bool> updateUserStatus(String userId, bool isActive) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final success = await repo.updateUserStatus(userId, isActive);

      // Refresh users list if successful
      if (success) {
        ref.invalidate(adminUsersProvider);
      }

      return success;
    } catch (e) {
      debugPrint('Error updating user status: $e');
      return false;
    }
  }

  /// Update job status
  Future<bool> updateJobStatus(String jobId, String status) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final success = await repo.updateJobStatus(jobId, status);

      // Refresh jobs list if successful
      if (success) {
        ref.invalidate(adminJobsProvider);
      }

      return success;
    } catch (e) {
      debugPrint('Error updating job status: $e');
      return false;
    }
  }
}

/// Providers for specific admin data
@riverpod
Future<PlatformStats> adminPlatformStats(Ref ref) {
  return ref.watch(adminControllerProvider.notifier).loadPlatformStats();
}

@riverpod
Future<List<JobStatByService>> adminJobStatsByService(Ref ref) {
  return ref.watch(adminControllerProvider.notifier).loadJobStatsByService();
}

@riverpod
Future<List<TechnicianPerformance>> adminTechnicianPerformance(Ref ref) {
  return ref
      .watch(adminControllerProvider.notifier)
      .loadTechnicianPerformance();
}

@riverpod
Future<RevenueStats> adminRevenueStats(Ref ref) {
  return ref.watch(adminControllerProvider.notifier).loadRevenueStats();
}

@riverpod
Future<SystemHealth> adminSystemHealth(Ref ref) {
  return ref.watch(adminControllerProvider.notifier).loadSystemHealth();
}

@riverpod
Future<List<AdminNotification>> adminNotifications(Ref ref) {
  return ref.watch(adminControllerProvider.notifier).loadNotifications();
}

@riverpod
Future<List<Map<String, dynamic>>> adminUsers(Ref ref) {
  return ref.watch(adminControllerProvider.notifier).loadAllUsers();
}

@riverpod
Future<List<Map<String, dynamic>>> adminJobs(Ref ref) {
  return ref.watch(adminControllerProvider.notifier).loadAllJobs();
}
