import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage.g.dart';

class SecureStorage {
  final _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: 'auth_token', value: token);
    } catch (e) {
      // Handle error appropriately (e.g., log it)
      debugPrint('Error saving token: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: 'auth_token');
    } catch (e) {
      debugPrint('Error reading token: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: 'auth_token');
    } catch (e) {
      debugPrint('Error deleting token: $e');
    }
  }
}

@riverpod
SecureStorage secureStorage(Ref ref) {
  return SecureStorage();
}
