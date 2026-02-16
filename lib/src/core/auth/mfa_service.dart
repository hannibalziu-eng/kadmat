import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provider for MFAService
final mfaServiceProvider = Provider<MFAService>((ref) {
  return MFAService(Supabase.instance.client);
});

/// Multi-Factor Authentication Service for Kadmat Application
/// Provides TOTP-based MFA (authenticator app)
class MFAService {
  final SupabaseClient _supabase;
  final _storage = const FlutterSecureStorage();

  MFAService(this._supabase);

  /// Enable MFA for current user (TOTP-based)
  Future<Map<String, dynamic>?> enrollMFA({String? friendlyName}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Enroll in TOTP MFA
      final response = await _supabase.auth.mfa.enroll(
        factorType: FactorType.totp,
        friendlyName: friendlyName ?? 'Authenticator App',
      );

      // Store factor ID for verification
      await _storage.write(key: 'mfa_factor_id', value: response.id);

      return {
        'id': response.id,
        'type': response.type.name,
        'totp': {
          'qr_code': response.totp?.qrCode,
          'secret': response.totp?.secret,
          'uri': response.totp?.uri,
        },
      };
    } catch (e) {
      debugPrint('Enable MFA Error: $e');
      rethrow;
    }
  }

  /// Verify MFA enrollment with TOTP code
  Future<bool> verifyMFAEnrollment(String code) async {
    try {
      final factorId = await _storage.read(key: 'mfa_factor_id');
      if (factorId == null) {
        throw Exception('No MFA factor configured');
      }

      // Challenge first
      final challenge = await _supabase.auth.mfa.challenge(factorId: factorId);

      // Verify with the code
      await _supabase.auth.mfa.verify(
        factorId: factorId,
        challengeId: challenge.id,
        code: code,
      );

      await _storage.write(key: 'mfa_enabled', value: 'true');
      return true;
    } catch (e) {
      debugPrint('Verify MFA Error: $e');
      rethrow;
    }
  }

  /// Authenticate with MFA code (for login flow)
  Future<bool> verifyMFALogin(String code) async {
    try {
      final factors = await _supabase.auth.mfa.listFactors();
      if (factors.totp.isEmpty) {
        throw Exception('No TOTP factor found');
      }

      final factorId = factors.totp.first.id;

      // Challenge
      final challenge = await _supabase.auth.mfa.challenge(factorId: factorId);

      // Verify
      await _supabase.auth.mfa.verify(
        factorId: factorId,
        challengeId: challenge.id,
        code: code,
      );

      return true;
    } catch (e) {
      debugPrint('MFA Login Verify Error: $e');
      rethrow;
    }
  }

  /// Check if MFA is enabled for current user
  Future<bool> isMFAEnabled() async {
    try {
      final factors = await _supabase.auth.mfa.listFactors();
      return factors.totp.isNotEmpty;
    } catch (e) {
      debugPrint('Check MFA Error: $e');
      return false;
    }
  }

  /// Unenroll MFA factor
  Future<bool> disableMFA() async {
    try {
      final factors = await _supabase.auth.mfa.listFactors();
      if (factors.totp.isEmpty) {
        return false;
      }

      final factorId = factors.totp.first.id;
      await _supabase.auth.mfa.unenroll(factorId);

      await _storage.delete(key: 'mfa_factor_id');
      await _storage.delete(key: 'mfa_enabled');

      return true;
    } catch (e) {
      debugPrint('Disable MFA Error: $e');
      rethrow;
    }
  }

  /// Get MFA status for current user
  Future<Map<String, dynamic>> getMFAStatus() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {'enabled': false, 'available': false};
      }

      final factors = await _supabase.auth.mfa.listFactors();

      return {
        'enabled': factors.totp.isNotEmpty,
        'available': true,
        'factors': factors.totp
            .map(
              (f) => {
                'id': f.id,
                'friendlyName': f.friendlyName,
                'type': f.factorType.name,
                'status': f.status.name,
              },
            )
            .toList(),
      };
    } catch (e) {
      debugPrint('Get MFA Status Error: $e');
      return {'enabled': false, 'available': false};
    }
  }

  /// Authenticate with MFA during login flow
  /// Signs in with email/password then verifies MFA code
  Future<bool> authenticateWithMFA(
    String email,
    String password,
    String mfaCode,
  ) async {
    try {
      // First, sign in with email/password
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        return false;
      }

      // Check if MFA is required
      final aal = _supabase.auth.mfa.getAuthenticatorAssuranceLevel();

      if (aal.currentLevel == AuthenticatorAssuranceLevels.aal1 &&
          aal.nextLevel == AuthenticatorAssuranceLevels.aal2) {
        // MFA is required, verify the code
        return verifyMFALogin(mfaCode);
      }

      // No MFA required, already authenticated
      return true;
    } catch (e) {
      debugPrint('MFA Auth Error: $e');
      rethrow;
    }
  }

  /// Get the current assurance level
  AuthMFAGetAuthenticatorAssuranceLevelResponse getAssuranceLevel() {
    return _supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  }
}
