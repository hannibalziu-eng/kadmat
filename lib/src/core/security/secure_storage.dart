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
      print('Error saving token: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: 'auth_token');
    } catch (e) {
      print('Error reading token: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: 'auth_token');
    } catch (e) {
      print('Error deleting token: $e');
    }
  }
}

@riverpod
SecureStorage secureStorage(SecureStorageRef ref) {
  return SecureStorage();
}
