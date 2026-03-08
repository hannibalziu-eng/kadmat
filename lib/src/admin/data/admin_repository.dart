import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/admin_models.dart';
import '../services/admin_analytics_service.dart';

part 'admin_repository.g.dart';

/// Repository for admin-related data operations
class AdminRepository {
  final SupabaseClient _supabase;
  final AdminAnalyticsService _analyticsService;

  AdminRepository(this._supabase, this._analyticsService);

  /// Get platform statistics
  Future<PlatformStats> getPlatformStats() async {
    final stats = await _analyticsService.getPlatformStats();
    return PlatformStats.fromJson(stats);
  }

  /// Get user growth statistics
  Future<List<UserGrowthStat>> getUserGrowth({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final growthData = await _analyticsService.getUserGrowth(
      startDate: startDate,
      endDate: endDate,
    );
    return growthData.map((json) => UserGrowthStat.fromJson(json)).toList();
  }

  /// Get job statistics by service type
  Future<List<JobStatByService>> getJobStatsByService() async {
    final stats = await _analyticsService.getJobStatsByService();
    return stats.map((json) => JobStatByService.fromJson(json)).toList();
  }

  /// Get technician performance metrics
  Future<List<TechnicianPerformance>> getTechnicianPerformance() async {
    final performance = await _analyticsService.getTechnicianPerformance();
    return performance
        .map((json) => TechnicianPerformance.fromJson(json))
        .toList();
  }

  /// Get revenue statistics
  Future<RevenueStats> getRevenueStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final stats = await _analyticsService.getRevenueStats(
      startDate: startDate,
      endDate: endDate,
    );
    return RevenueStats.fromJson(stats);
  }

  /// Get system health metrics
  Future<SystemHealth> getSystemHealth() async {
    final health = await _analyticsService.getSystemHealth();
    return SystemHealth.fromJson(health);
  }

  /// Get admin users
  Future<List<AdminUser>> getAdminUsers() async {
    try {
      final result = await _supabase
          .from('admin_users')
          .select()
          .order('created_at', ascending: false);

      return result.map((json) => AdminUser.fromJson(json)).toList();
    } catch (e) {
      // If admin_users table doesn't exist, return empty list
      // In a real implementation, you might want to create this table
      return [];
    }
  }

  /// Get admin notifications
  Future<List<AdminNotification>> getAdminNotifications({
    int limit = 50,
    bool onlyUnread = false,
  }) async {
    try {
      var query = _supabase.from('admin_notifications').select();

      if (onlyUnread) {
        query = query.eq('is_read', false);
      }

      final result = await query
          .order('timestamp', ascending: false)
          .limit(limit);
      return result.map((json) => AdminNotification.fromJson(json)).toList();
    } catch (e) {
      // If admin_notifications table doesn't exist, return empty list
      return [];
    }
  }

  /// Mark admin notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('admin_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all users with pagination
  Future<List<Map<String, dynamic>>> getAllUsers({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    String? userType,
  }) async {
    try {
      var query = _supabase.from('users').select('*, profiles(*)');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('email', '%$searchQuery%');
      }

      if (userType != null && userType.isNotEmpty) {
        query = query.eq('user_type', userType);
      }

      return await query
          .order('created_at', ascending: false)
          .range((page - 1) * limit, page * limit - 1);
    } catch (e) {
      return [];
    }
  }

  /// Get all jobs with pagination
  Future<List<Map<String, dynamic>>> getAllJobs({
    int page = 1,
    int limit = 20,
    String? status,
    String? serviceId,
  }) async {
    try {
      var query = _supabase
          .from('jobs')
          .select('*, users!assigned_technician_id(*)');

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      if (serviceId != null && serviceId.isNotEmpty) {
        query = query.eq('service_id', serviceId);
      }

      return await query
          .order('created_at', ascending: false)
          .range((page - 1) * limit, page * limit - 1);
    } catch (e) {
      return [];
    }
  }

  /// Update user account status
  Future<bool> updateUserStatus(String userId, bool isActive) async {
    try {
      await _supabase
          .from('users')
          .update({'is_active': isActive})
          .eq('id', userId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update job status
  Future<bool> updateJobStatus(String jobId, String status) async {
    try {
      await _supabase.from('jobs').update({'status': status}).eq('id', jobId);

      return true;
    } catch (e) {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
AdminRepository adminRepository(Ref ref) {
  final supabase = Supabase.instance.client;
  final analyticsService = AdminAnalyticsService(supabase);
  return AdminRepository(supabase, analyticsService);
}
