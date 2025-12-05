import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cache_manager.g.dart';

class CacheManager {
  static const String _boxName = 'app_cache';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  Future<void> saveData(String key, dynamic value) async {
    await _box.put(key, value);
  }

  dynamic getData(String key) {
    return _box.get(key);
  }

  Future<void> removeData(String key) async {
    await _box.delete(key);
  }

  Future<void> clearCache() async {
    await _box.clear();
  }
}

@riverpod
CacheManager cacheManager(CacheManagerRef ref) {
  return CacheManager();
}
