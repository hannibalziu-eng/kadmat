import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final Dio _client;
  final _storage = const FlutterSecureStorage();
  final _authStateController = StreamController<String?>.broadcast();
  String? _currentUser;
  String? _userType;
  Map<String, dynamic>? _userProfile;

  AuthRepository(this._client) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await _storage.read(key: 'auth_token');
    final userType = await _storage.read(key: 'user_type');
    // Note: For a real app, we should fetch the profile from API using the token
    // For now, we'll rely on what we have or fetch it if needed.
    // Since we don't persist the full profile in secure storage (it's too big/complex),
    // we might need to fetch it again or store basic info.
    // For simplicity in this fix, we'll assume the user needs to login to get fresh data,
    // or we could fetch it here. Let's fetch it if we have a token.

    if (token != null) {
      _currentUser = 'user';
      _userType = userType;
      // Ideally fetch profile here, but for now let's just set state
      _authStateController.add(_currentUser);
    } else {
      _authStateController.add(null);
    }
  }

  Stream<String?> authStateChanges() => _authStateController.stream;

  String? get currentUser => _currentUser;
  String? get userType => _userType;
  Map<String, dynamic>? get userProfile => _userProfile;

  Future<void> signInWithEmailAndPassword(
    String email,
    String password, {
    String? requiredUserType,
  }) async {
    try {
      final response = await _client.post(
        Endpoints.login,
        data: {'email': email, 'password': password},
      );

      final token = response.data['token'];
      final user = response.data['user'];
      final type = user['user_type'] ?? 'customer';

      // Fetch extended profile including badges (if technician)
      // This is a temporary direct Supabase call until the API returns full nested data
      final userId = user['id'];
      Map<String, dynamic> fullProfile = Map<String, dynamic>.from(user);

      /*
      try {
        if (type == 'technician') {
          // Fetch badges
          final badgesData = await Supabase.instance.client
              .from('technician_badges')
              .select('badge_type, label, icon_name')
              .eq('technician_id', userId);

          if (badgesData.isNotEmpty) {
            fullProfile['badges'] = badgesData;
          }
        }
      } catch (e) {
        print('Error fetching badges: $e');
        // Continue without badges if fetch fails
      }
      */

      // Enforce User Type Check
      if (requiredUserType != null && type != requiredUserType) {
        throw Exception(
          requiredUserType == 'technician'
              ? 'عذراً، هذا الحساب مخصص للعملاء فقط. يرجى استخدام تطبيق العملاء.'
              : 'عذراً، هذا الحساب مخصص للفنيين فقط. يرجى استخدام تطبيق الفني.',
        );
      }

      await _storage.write(key: 'auth_token', value: token);
      await _storage.write(key: 'user_type', value: type);

      _currentUser = user['email'];
      _userType = type;
      _userProfile = fullProfile; // Store the full user profile
      _authStateController.add(_currentUser);
    } catch (e) {
      if (e is DioException) {
        final message = e.response?.data['message'] ?? 'فشل تسجيل الدخول';
        final statusCode = e.response?.statusCode;
        final rawData = e.response?.data;
        throw Exception(
          '$message (Status: $statusCode, Data: $rawData, Error: ${e.message})',
        );
      }
      // Re-throw if it's already an Exception (like our user type check)
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String phone,
    required String fullName,
    String userType = 'customer',
    String? serviceId,
  }) async {
    try {
      await _client.post(
        Endpoints.register,
        data: {
          'email': email,
          'password': password,
          'phone': phone,
          'full_name': fullName,
          'user_type': userType,
          if (serviceId != null) 'service_id': serviceId,
        },
      );

      // Auto login after register or ask user to login
      await signInWithEmailAndPassword(email, password);
    } catch (e) {
      if (e is DioException) {
        final message = e.response?.data['message'] ?? 'فشل إنشاء الحساب';
        final statusCode = e.response?.statusCode;
        final rawData = e.response?.data;
        throw Exception(
          '$message (Status: $statusCode, Data: $rawData, Error: ${e.message})',
        );
      }
      throw Exception('حدث خطأ غير متوقع: $e');
    }
  }

  Future<void> signInAsGuest() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = 'guest';
    _authStateController.add(_currentUser);
  }

  Future<void> signOut() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_type');
    _currentUser = null;
    _userType = null;
    _userProfile = null;
    _authStateController.add(null);
  }

  void dispose() {
    _authStateController.close();
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  final client = ref.watch(apiClientProvider);
  final repo = AuthRepository(client);
  ref.onDispose(() => repo.dispose());
  return repo;
}

@riverpod
Stream<String?> authStateChanges(AuthStateChangesRef ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges();
}
