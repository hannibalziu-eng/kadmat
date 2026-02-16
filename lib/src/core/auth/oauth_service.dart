import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provider for OAuthService
final oAuthServiceProvider = Provider<OAuthService>((ref) {
  return OAuthService(Supabase.instance.client);
});

/// OAuth 2.0 Service for Kadmat Application
/// Handles third-party authentication (Google, Apple, Facebook)
class OAuthService {
  final SupabaseClient _supabase;
  final _storage = const FlutterSecureStorage();

  OAuthService(this._supabase);

  /// Authenticate with Google
  Future<bool> signInWithGoogle() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'kadmat://oauth-callback',
        queryParams: {'access_type': 'offline', 'prompt': 'consent'},
      );
      return response;
    } catch (e) {
      debugPrint('Google OAuth Error: $e');
      rethrow;
    }
  }

  /// Authenticate with Apple
  Future<bool> signInWithApple() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'kadmat://oauth-callback',
      );
      return response;
    } catch (e) {
      debugPrint('Apple OAuth Error: $e');
      rethrow;
    }
  }

  /// Authenticate with Facebook
  Future<bool> signInWithFacebook() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'kadmat://oauth-callback',
      );
      return response;
    } catch (e) {
      debugPrint('Facebook OAuth Error: $e');
      rethrow;
    }
  }

  /// Check if user is authenticated via OAuth
  Future<bool> isAuthenticated() async {
    try {
      return _supabase.auth.currentSession != null;
    } catch (e) {
      debugPrint('Auth check error: $e');
      return false;
    }
  }

  /// Sign out and clear OAuth tokens
  Future<void> signOut() async {
    try {
      await _storage.delete(key: 'oauth_access_token');
      await _storage.delete(key: 'oauth_refresh_token');
      await _storage.delete(key: 'oauth_expires_at');
      await _storage.delete(key: 'oauth_provider');

      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  /// Get current OAuth provider
  Future<String?> getCurrentProvider() async {
    return await _storage.read(key: 'oauth_provider');
  }
}
