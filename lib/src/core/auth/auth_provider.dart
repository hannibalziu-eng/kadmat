import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'oauth_service.dart';
import 'mfa_service.dart';

/// Combined authentication provider exposing all auth services
class AuthServiceProvider {
  final OAuthService oauth;
  final MFAService mfa;

  AuthServiceProvider(this.oauth, this.mfa);
}

/// Provider for the combined auth service
final authServiceProvider = Provider<AuthServiceProvider>((ref) {
  final supabase = Supabase.instance.client;
  final oauth = OAuthService(supabase);
  final mfa = MFAService(supabase);
  
  return AuthServiceProvider(oauth, mfa);
});

/// Convenience providers for individual services
final oAuthServiceProvider = Provider<OAuthService>((ref) {
  return ref.watch(authServiceProvider).oauth;
});

final mfaServiceProvider = Provider<MFAService>((ref) {
  return ref.watch(authServiceProvider).mfa;
});

/// Provider to check overall auth status
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final oauthService = ref.watch(oAuthServiceProvider);
  return await oauthService.isAuthenticated();
});

/// Provider to get current auth method
final currentAuthProvider = FutureProvider<String?>((ref) async {
  final oauthService = ref.watch(oAuthServiceProvider);
  return await oauthService.getCurrentProvider();
});

/// Provider to get MFA status
final mfaStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final mfaService = ref.watch(mfaServiceProvider);
  return await mfaService.getMFAStatus();
});