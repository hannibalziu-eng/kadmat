import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'cache_manager.g.dart';

class CacheManager {
  static const String _boxName = 'app_cache';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  /// Save data with optional expiration (TTL)
  /// [ttl] is the time-to-live duration. If null, data persists indefinitely.
  Future<void> saveData(String key, dynamic value, {Duration? ttl}) async {
    final entry = {
      'data': value,
      'expiry': ttl != null
          ? DateTime.now().add(ttl).millisecondsSinceEpoch
          : null,
    };
    await _box.put(key, jsonEncode(entry));
  }

  /// Get data if it exists and hasn't expired
  dynamic getData(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;

    try {
      final entry = jsonDecode(raw);
      final expiry = entry['expiry'] as int?;

      if (expiry != null) {
        if (DateTime.now().millisecondsSinceEpoch > expiry) {
          // Expired
          _box.delete(key);
          return null;
        }
      }

      return entry['data'];
    } catch (e) {
      debugPrint('Cache Error ($key): $e');
      return null;
    }
  }

  Future<void> removeData(String key) async {
    await _box.delete(key);
  }

  Future<void> clearCache() async {
    await _box.clear();
  }
}

@riverpod
CacheManager cacheManager(Ref ref) {
  return CacheManager();
}
