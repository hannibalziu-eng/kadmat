import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/utils/error_messages.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final Dio _client;
  final _storage = const FlutterSecureStorage();
  final _authStateController = StreamController<String?>.broadcast();
  late final StreamSubscription<AuthState> _authSubscription;
  String? _currentUser;
  String? _userType;
  Map<String, dynamic>? _userProfile;
  bool _isPerformingLogin = false;

  AuthRepository(this._client) {
    _checkAuthStatus();
    _setupAuthListener();
  }

  String _friendlyErrorMessage(dynamic error, {required String fallback}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message =
            data['message'] ??
            (data['error'] is Map<String, dynamic>
                ? data['error']['message']
                : null);
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    }

    final resolved = ErrorMessages.fromException(error);
    return resolved == ErrorMessages.unknownError ? fallback : resolved;
  }

  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedOut) {
        if (_isPerformingLogin) {
          debugPrint('ℹ️ Ignoring signedOut event during login cleanup');
          return;
        }
        _handleSignOut();
      } else if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        if (session != null) {
          _updateAuthState(session);
        }
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await _updateAuthState(session);
    } else {
      _authStateController.add(null);
    }
  }

  Future<void> _updateAuthState(Session session) async {
    final storedUserType = await _storage.read(key: 'user_type');

    try {
      if (_userProfile == null) {
        // Only fetch if we don't have it (optimization)
        final profileData = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', session.user.id)
            .single();
        _userProfile = profileData;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to fetch profile: $e');
    }

    final profileUserType = _userProfile?['user_type']?.toString();
    final metadataUserType = session.user.userMetadata?['user_type']?.toString();
    final resolvedUserType = storedUserType ?? profileUserType ?? metadataUserType;

    // Keep `currentUser` as UUID to match DB relations (`technician_id/customer_id`).
    _currentUser = session.user.id;
    _userType = resolvedUserType;
    _authStateController.add(_currentUser);
  }

  Future<void> _handleSignOut() async {
    await _storage.delete(key: 'user_type');
    _currentUser = null;
    _userType = null;
    _userProfile = null;
    _authStateController.add(null);
  }

  Stream<String?> authStateChanges() => _authStateController.stream;

  String? get currentUser => _currentUser;
  String? get userType => _userType;
  Map<String, dynamic>? get userProfile => _userProfile;

  void mergeCachedUserProfile(Map<String, dynamic> updates) {
    _userProfile = {...?_userProfile, ...updates};
  }

  Future<void> signInWithEmailAndPassword(
    String email,
    String password, {
    String? requiredUserType,
  }) async {
    try {
      _isPerformingLogin = true;

      // Clear any existing session locally (without triggering auth listener redirect)
      // This prevents "Invalid Refresh Token" issues from lingering sessions
      try {
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Ignore signOut errors - we're just cleaning up
      }

      if (kIsWeb) {
        final authResponse = await Supabase.instance.client.auth
            .signInWithPassword(email: email, password: password);
        final session = authResponse.session;
        final user = authResponse.user;

        if (session == null || user == null) {
          throw Exception(ErrorMessages.authSessionSyncFailed);
        }

        final profileData = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .single();

        final type =
            profileData['user_type']?.toString() ??
            user.userMetadata?['user_type']?.toString() ??
            'customer';

        if (requiredUserType != null && type != requiredUserType) {
          await Supabase.instance.client.auth.signOut(
            scope: SignOutScope.local,
          );
          throw Exception(
            requiredUserType == 'technician'
                ? 'عذراً، هذا الحساب مخصص للعملاء فقط. يرجى استخدام تطبيق العملاء.'
                : 'عذراً، هذا الحساب مخصص للفنيين فقط. يرجى استخدام تطبيق الفني.',
          );
        }

        await _storage.write(key: 'user_type', value: type);
        _userType = type;
        _userProfile = Map<String, dynamic>.from(profileData);
        _currentUser = user.id;
        _authStateController.add(_currentUser);
        return;
      }

      final response = await _client.post(
        Endpoints.login,
        data: {'email': email, 'password': password},
      );

      final refreshToken = response.data['refresh_token'];
      final user = response.data['user'];
      final type = user['user_type'] ?? 'customer';

      if (requiredUserType != null && type != requiredUserType) {
        throw Exception(
          requiredUserType == 'technician'
              ? 'عذراً، هذا الحساب مخصص للعملاء فقط. يرجى استخدام تطبيق العملاء.'
              : 'عذراً، هذا الحساب مخصص للفنيين فقط. يرجى استخدام تطبيق الفني.',
        );
      }

      await _storage.write(key: 'user_type', value: type);
      _userType = type;

      if (refreshToken != null) {
        try {
          await Supabase.instance.client.auth.setSession(refreshToken);
        } on AuthException catch (e) {
          throw Exception(_authSessionErrorMessage(e));
        }
      } else {
        throw Exception(ErrorMessages.authSessionSyncFailed);
      }

      // _updateAuthState will be triggered by listener via onAuthStateChange,
      // but we can also manually update local state for immediate feedback/navigation if needed.
      // However, relying on the listener is safer for consistency.
    } on DioException catch (e) {
      // Handle network errors specifically
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw Exception('فشل الاتصال بالخادم. تأكد من اتصالك بالإنترنت.');
      }
      final data = e.response?.data;
      final message =
          (data is Map<String, dynamic>
                  ? (data['message'] ??
                      (data['error'] is Map<String, dynamic>
                          ? data['error']['message']
                          : null))
                  : null)
              as String?;
      if (e.response?.statusCode == 401) {
        throw Exception(ErrorMessages.invalidCredentials);
      }
      if (e.response?.statusCode == 429) {
        throw Exception(ErrorMessages.rateLimited);
      }
      if (e.response?.statusCode != null &&
          (e.response!.statusCode! >= 500)) {
        throw Exception(ErrorMessages.serverError);
      }
      final resolved =
          (message != null && message.trim().isNotEmpty)
              ? message.trim()
              : 'فشل تسجيل الدخول';
      throw Exception(resolved);
    } on AuthException catch (e) {
      throw Exception(_authSessionErrorMessage(e));
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(_friendlyErrorMessage(e, fallback: 'فشل تسجيل الدخول'));
    } finally {
      _isPerformingLogin = false;
    }
  }

  String _authSessionErrorMessage(AuthException error) {
    final raw = error.message.trim();
    final normalized = raw.toLowerCase();

    if (normalized.isEmpty) {
      return ErrorMessages.authSessionSyncFailed;
    }

    if (normalized.contains('invalid refresh token') ||
        normalized.contains('refresh_token_already_used') ||
        normalized.contains('refresh token cannot be empty') ||
        normalized.contains('session missing') ||
        normalized.contains('session_not_found') ||
        normalized.contains('no refresh_token detected') ||
        normalized.contains('no access_token detected')) {
      return ErrorMessages.authSessionSyncFailed;
    }

    if (normalized.contains('network') ||
        normalized.contains('fetch') ||
        normalized.contains('connection') ||
        normalized.contains('timeout')) {
      return ErrorMessages.noInternetConnection;
    }

    final resolved = ErrorMessages.fromException(raw);
    return resolved == ErrorMessages.unknownError ? raw : resolved;
  }

  Future<void> register({
    required String email,
    required String password,
    required String phone,
    required String fullName,
    String userType = 'customer',
    String? serviceId,
    List<String>? documentUrls,
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
          if (documentUrls != null && documentUrls.isNotEmpty)
            'document_urls': documentUrls,
        },
      );

      // Pre-set user type locally to ensure sign-in logic picks it up
      _userType = userType;
      await _storage.write(key: 'user_type', value: userType);

      // Auto login after register
      await signInWithEmailAndPassword(
        email,
        password,
        requiredUserType: userType,
      );
    } catch (e) {
      throw Exception(_friendlyErrorMessage(e, fallback: 'فشل إنشاء الحساب'));
    }
  }

  Future<void> signInAsGuest() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = 'guest';
    _authStateController.add(_currentUser);
  }

  Future<void> signOut() async {
    // This will trigger the onAuthStateChange listener with signedOut event
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? fcmToken,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل الدخول');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (fcmToken != null) updates['fcm_token'] = fcmToken;

    try {
      await Supabase.instance.client
          .from('users')
          .update(updates)
          .eq('id', user.id);

      if (_userProfile != null) {
        _userProfile!.addAll(updates);
      }
    } catch (e) {
      throw Exception(
        _friendlyErrorMessage(e, fallback: 'فشل تحديث الملف الشخصي'),
      );
    }
  }

  /// Update user password
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception(
        e.message.trim().isEmpty
            ? 'تعذر إرسال رابط إعادة التعيين'
            : e.message.trim(),
      );
    } catch (e) {
      throw Exception(
        _friendlyErrorMessage(e, fallback: 'تعذر إرسال رابط إعادة التعيين'),
      );
    }
  }

  Future<void> updatePassword({required String newPassword}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل الدخول');

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw Exception(
        e.message.trim().isEmpty ? 'فشل تغيير كلمة المرور' : e.message.trim(),
      );
    } catch (e) {
      throw Exception(
        _friendlyErrorMessage(e, fallback: 'فشل تغيير كلمة المرور'),
      );
    }
  }

  void dispose() {
    _authSubscription.cancel();
    _authStateController.close();
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  final repo = AuthRepository(client);
  ref.onDispose(() => repo.dispose());
  return repo;
}

@riverpod
Stream<String?> authStateChanges(Ref ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges();
}
