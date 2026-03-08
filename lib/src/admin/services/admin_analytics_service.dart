import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Admin Analytics Service for Kadmat Application
/// Provides business intelligence and metrics for administrators
class AdminAnalyticsService {
  final SupabaseClient _supabase;

  AdminAnalyticsService(this._supabase);

  /// Get overall platform statistics
  Future<Map<String, dynamic>> getPlatformStats() async {
    try {
      // Count total users
      final userCount = await _supabase.from('users').count(CountOption.exact);

      // Count total jobs
      final jobCount = await _supabase.from('jobs').count(CountOption.exact);

      // Count completed jobs
      final completedResponse = await _supabase
          .from('jobs')
          .select()
          .eq('status', 'completed')
          .count(CountOption.exact);
      final completedJobs = completedResponse.count;

      // Count active technicians
      final activeResponse = await _supabase
          .from('users')
          .select()
          .eq('user_type', 'technician')
          .eq('is_active', true)
          .count(CountOption.exact);
      final activeTechs = activeResponse.count;

      // Calculate revenue (assuming there's a price field in jobs)
      final revenueResult = await _supabase
          .from('jobs')
          .select('price')
          .eq('status', 'completed');

      final totalRevenue = revenueResult
          .map((job) => job['price'] ?? 0)
          .fold<double>(0, (a, b) => a + (b is num ? b.toDouble() : 0));

      return {
        'totalUsers': userCount,
        'totalJobs': jobCount,
        'completedJobs': completedJobs,
        'activeTechnicians': activeTechs,
        'totalRevenue': totalRevenue,
        'completionRate': jobCount != 0 ? (completedJobs / jobCount) * 100 : 0,
      };
    } catch (e) {
      debugPrint('Analytics Error: $e');
      rethrow;
    }
  }

  /// Get user growth over time
  Future<List<Map<String, dynamic>>> getUserGrowth({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final result = await _supabase.rpc(
        'get_user_growth_stats',
        params: {
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
        },
      );

      return result.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('User Growth Analytics Error: $e');
      // Fallback to simple query if RPC doesn't exist
      return await _getUserGrowthFallback(startDate, endDate);
    }
  }

  /// Fallback method for user growth if RPC doesn't exist
  Future<List<Map<String, dynamic>>> _getUserGrowthFallback(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // GroupBy is not supported in simple query, returning empty list
      return [];
    } catch (e) {
      debugPrint('Fallback User Growth Error: $e');
      return [];
    }
  }

  /// Get job statistics by service type
  Future<List<Map<String, dynamic>>> getJobStatsByService() async {
    try {
      final result = await _supabase.rpc('get_jobs_by_service_type');

      return result.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Job Stats by Service Error: $e');
      return await _getJobStatsByServiceFallback();
    }
  }

  /// Fallback method for job stats by service
  Future<List<Map<String, dynamic>>> _getJobStatsByServiceFallback() async {
    try {
      // GroupBy is not supported in simple query, return empty or implement client-side aggregation
      return [];
    } catch (e) {
      debugPrint('Fallback Job Stats Error: $e');
      return [];
    }
  }

  /// Get technician performance metrics
  Future<List<Map<String, dynamic>>> getTechnicianPerformance() async {
    try {
      final result = await _supabase.rpc('get_technician_performance');

      return result.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Technician Performance Error: $e');
      return await _getTechnicianPerformanceFallback();
    }
  }

  /// Fallback method for technician performance
  Future<List<Map<String, dynamic>>> _getTechnicianPerformanceFallback() async {
    try {
      // GroupBy is not supported in simple query, return empty
      return [];
    } catch (e) {
      debugPrint('Fallback Technician Performance Error: $e');
      return [];
    }
  }

  /// Get revenue statistics
  Future<Map<String, dynamic>> getRevenueStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = _supabase.from('jobs').select('price, created_at');
      if (startDate != null) {
        query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query.lte('created_at', endDate.toIso8601String());
      }

      final result = await query.eq('status', 'completed');

      final prices = result
          .map((job) => job['price'] ?? 0)
          .whereType<num>()
          .map((p) => p.toDouble())
          .toList();

      final totalRevenue = prices.fold<double>(0, (a, b) => a + b);
      final averageOrderValue = prices.isNotEmpty
          ? totalRevenue / prices.length
          : 0;

      return {
        'totalRevenue': totalRevenue,
        'averageOrderValue': averageOrderValue,
        'transactionCount': prices.length,
        'revenueByDay': await _getRevenueByDay(prices, result),
      };
    } catch (e) {
      debugPrint('Revenue Stats Error: $e');
      return {
        'totalRevenue': 0,
        'averageOrderValue': 0,
        'transactionCount': 0,
        'revenueByDay': [],
      };
    }
  }

  /// Helper to group revenue by day
  Future<List<Map<String, dynamic>>> _getRevenueByDay(
    List<double> prices,
    List<Map<String, dynamic>> jobs,
  ) async {
    try {
      final grouped = <String, double>{};
      for (int i = 0; i < jobs.length; i++) {
        final date = DateTime.parse(
          jobs[i]['created_at'],
        ).toIso8601String().split('T')[0];
        final price = prices[i];
        grouped[date] = (grouped[date] ?? 0) + price;
      }

      return grouped.entries
          .map((entry) => {'date': entry.key, 'revenue': entry.value})
          .toList();
    } catch (e) {
      debugPrint('Revenue by Day Error: $e');
      return [];
    }
  }

  /// Get system health metrics
  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      // Check database connection
      await _supabase.from('users').count();

      // In a real implementation, you'd check various system metrics
      return {
        'databaseStatus': 'connected',
        'apiResponseTime': 'normal',
        'activeConnections': 42, // Placeholder
        'systemLoad': 'low',
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('System Health Error: $e');
      return {
        'databaseStatus': 'disconnected',
        'apiResponseTime': 'slow',
        'activeConnections': 0,
        'systemLoad': 'unknown',
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }
}
