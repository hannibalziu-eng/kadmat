// Admin Dashboard Models for Kadmat Application

/// Platform statistics model
class PlatformStats {
  final int totalUsers;
  final int totalJobs;
  final int completedJobs;
  final int activeTechnicians;
  final double totalRevenue;
  final double completionRate;

  PlatformStats({
    required this.totalUsers,
    required this.totalJobs,
    required this.completedJobs,
    required this.activeTechnicians,
    required this.totalRevenue,
    required this.completionRate,
  });

  factory PlatformStats.fromJson(Map<String, dynamic> json) {
    return PlatformStats(
      totalUsers: json['totalUsers'] ?? 0,
      totalJobs: json['totalJobs'] ?? 0,
      completedJobs: json['completedJobs'] ?? 0,
      activeTechnicians: json['activeTechnicians'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      completionRate: (json['completionRate'] ?? 0).toDouble(),
    );
  }
}

/// User growth statistics model
class UserGrowthStat {
  final String date;
  final int count;

  UserGrowthStat({required this.date, required this.count});

  factory UserGrowthStat.fromJson(Map<String, dynamic> json) {
    return UserGrowthStat(date: json['date'] ?? '', count: json['count'] ?? 0);
  }
}

/// Job statistics by service type
class JobStatByService {
  final String serviceId;
  final int count;

  JobStatByService({required this.serviceId, required this.count});

  factory JobStatByService.fromJson(Map<String, dynamic> json) {
    return JobStatByService(
      serviceId: json['service_id'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

/// Technician performance model
class TechnicianPerformance {
  final String technicianId;
  final int jobCount;
  final double avgRating;

  TechnicianPerformance({
    required this.technicianId,
    required this.jobCount,
    required this.avgRating,
  });

  factory TechnicianPerformance.fromJson(Map<String, dynamic> json) {
    return TechnicianPerformance(
      technicianId: json['technician_id'] ?? '',
      jobCount: json['job_count'] ?? 0,
      avgRating: (json['avg_rating'] ?? 0.0).toDouble(),
    );
  }
}

/// Revenue statistics model
class RevenueStats {
  final double totalRevenue;
  final double averageOrderValue;
  final int transactionCount;
  final List<RevenueByDay> revenueByDay;

  RevenueStats({
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.transactionCount,
    required this.revenueByDay,
  });

  factory RevenueStats.fromJson(Map<String, dynamic> json) {
    return RevenueStats(
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      averageOrderValue: (json['averageOrderValue'] ?? 0).toDouble(),
      transactionCount: json['transactionCount'] ?? 0,
      revenueByDay:
          (json['revenueByDay'] as List?)
              ?.map((item) => RevenueByDay.fromJson(item))
              .toList() ??
          [],
    );
  }
}

/// Revenue by day model
class RevenueByDay {
  final String date;
  final double revenue;

  RevenueByDay({required this.date, required this.revenue});

  factory RevenueByDay.fromJson(Map<String, dynamic> json) {
    return RevenueByDay(
      date: json['date'] ?? '',
      revenue: (json['revenue'] ?? 0).toDouble(),
    );
  }
}

/// System health model
class SystemHealth {
  final String databaseStatus;
  final String apiResponseTime;
  final int activeConnections;
  final String systemLoad;
  final String lastUpdated;

  SystemHealth({
    required this.databaseStatus,
    required this.apiResponseTime,
    required this.activeConnections,
    required this.systemLoad,
    required this.lastUpdated,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    return SystemHealth(
      databaseStatus: json['databaseStatus'] ?? 'unknown',
      apiResponseTime: json['apiResponseTime'] ?? 'unknown',
      activeConnections: json['activeConnections'] ?? 0,
      systemLoad: json['systemLoad'] ?? 'unknown',
      lastUpdated: json['lastUpdated'] ?? DateTime.now().toIso8601String(),
    );
  }
}

/// Admin user model
class AdminUser {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final DateTime createdAt;
  final bool isActive;

  AdminUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    required this.isActive,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['name'] ?? 'N/A',
      role: json['role'] ?? 'admin',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: json['is_active'] ?? true,
    );
  }
}

/// Admin notification model
class AdminNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime timestamp;
  final bool isRead;
  final String? relatedEntityId;

  AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    required this.isRead,
    this.relatedEntityId,
  });

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    return AdminNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'info',
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      isRead: json['is_read'] ?? false,
      relatedEntityId: json['related_entity_id'],
    );
  }
}
