import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveJobSession {
  final String jobId;
  final String status;
  final DateTime updatedAt;
  final String? routeHint;

  const ActiveJobSession({
    required this.jobId,
    required this.status,
    required this.updatedAt,
    this.routeHint,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'job_id': jobId,
      'status': status,
      'updated_at': updatedAt.toIso8601String(),
      'route_hint': routeHint,
    };
  }

  factory ActiveJobSession.fromMap(Map<String, dynamic> map) {
    final rawUpdatedAt = map['updated_at']?.toString();
    final parsedUpdatedAt = rawUpdatedAt != null
        ? DateTime.tryParse(rawUpdatedAt)
        : DateTime.fromMillisecondsSinceEpoch(0);

    return ActiveJobSession(
      jobId: (map['job_id'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      updatedAt: parsedUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      routeHint: map['route_hint']?.toString(),
    );
  }
}

class ActiveJobSessionService {
  static const String _boxName = 'app_cache';
  static const String _keyPrefix = 'active_job_session_v1';
  static const Duration _maxSessionAge = Duration(hours: 48);

  static const Set<String> _activeStatuses = <String>{
    'pending',
    'searching',
    'accepted',
    'price_pending',
    'on_the_way',
    'arrived',
    'in_progress',
    'pending_confirm',
    'pending_confirmation',
    'payment_pending',
  };

  static const Set<String> _terminalStatuses = <String>{
    'completed',
    'rated',
    'cancelled',
    'no_technician_found',
    'expired',
  };

  Box<dynamic>? _box;

  static bool isActiveStatus(String status) =>
      _activeStatuses.contains(_normalizeStatus(status));

  static bool isTerminalStatus(String status) =>
      _terminalStatuses.contains(_normalizeStatus(status));

  static String _normalizeStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'payment_pending') return 'pending_confirm';
    if (normalized == 'pending_confirmation') return 'pending_confirm';
    return normalized;
  }

  Future<Box<dynamic>> _getBox() async {
    if (_box != null) return _box!;
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<dynamic>(_boxName);
      return _box!;
    }
    _box = await Hive.openBox<dynamic>(_boxName);
    return _box!;
  }

  String _keyForUser(String userId) => '$_keyPrefix:$userId';

  String? _resolveUserId({String? userId}) {
    if (userId != null && userId.trim().isNotEmpty) {
      return userId.trim();
    }
    return Supabase.instance.client.auth.currentUser?.id;
  }

  Future<void> sync({
    required String jobId,
    required String status,
    String? routeHint,
    String? userId,
  }) async {
    final resolvedUserId = _resolveUserId(userId: userId);
    if (resolvedUserId == null) {
      return;
    }

    final normalizedStatus = _normalizeStatus(status);
    if (isActiveStatus(normalizedStatus)) {
      await save(
        ActiveJobSession(
          jobId: jobId,
          status: normalizedStatus,
          updatedAt: DateTime.now(),
          routeHint: routeHint,
        ),
        userId: resolvedUserId,
      );
      return;
    }

    await clear(userId: resolvedUserId, jobId: jobId);
  }

  Future<void> save(ActiveJobSession session, {String? userId}) async {
    final resolvedUserId = _resolveUserId(userId: userId);
    if (resolvedUserId == null) return;

    final box = await _getBox();
    await box.put(_keyForUser(resolvedUserId), session.toMap());
  }

  Future<ActiveJobSession?> read({String? userId}) async {
    final resolvedUserId = _resolveUserId(userId: userId);
    if (resolvedUserId == null) return null;

    final box = await _getBox();
    final raw = box.get(_keyForUser(resolvedUserId));
    if (raw == null) return null;

    if (raw is! Map) {
      await box.delete(_keyForUser(resolvedUserId));
      return null;
    }

    try {
      final session = ActiveJobSession.fromMap(Map<String, dynamic>.from(raw));
      if (session.jobId.trim().isEmpty) {
        await box.delete(_keyForUser(resolvedUserId));
        return null;
      }

      final age = DateTime.now().difference(session.updatedAt);
      if (age > _maxSessionAge) {
        await box.delete(_keyForUser(resolvedUserId));
        return null;
      }

      if (!isActiveStatus(session.status)) {
        await box.delete(_keyForUser(resolvedUserId));
        return null;
      }

      return session;
    } catch (error) {
      debugPrint('⚠️ Failed to parse cached active job session: $error');
      await box.delete(_keyForUser(resolvedUserId));
      return null;
    }
  }

  Future<void> clear({String? userId, String? jobId}) async {
    final resolvedUserId = _resolveUserId(userId: userId);
    if (resolvedUserId == null) return;

    final box = await _getBox();
    final key = _keyForUser(resolvedUserId);

    if (jobId == null || jobId.trim().isEmpty) {
      await box.delete(key);
      return;
    }

    final existing = await read(userId: resolvedUserId);
    if (existing == null || existing.jobId == jobId.trim()) {
      await box.delete(key);
    }
  }
}

final activeJobSessionServiceProvider = Provider<ActiveJobSessionService>((
  ref,
) {
  return ActiveJobSessionService();
});
