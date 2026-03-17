import 'package:flutter/foundation.dart';

/// Controls whether live E2E tests should run against a real backend.
///
/// Usage:
/// `flutter test integration_test --dart-define=KADMAT_E2E_ENABLED=true`
class KadmatTestConfig {
  static const bool e2eEnabled = bool.fromEnvironment(
    'KADMAT_E2E_ENABLED',
    defaultValue: false,
  );

  static const String supabaseUrl = String.fromEnvironment(
    'KADMAT_TEST_SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'KADMAT_TEST_SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static String? skipReasonIfDisabled() {
    if (!e2eEnabled) {
      return 'Set --dart-define=KADMAT_E2E_ENABLED=true to run live journeys.';
    }
    if (!hasSupabaseConfig) {
      return 'Missing Supabase test config dart-defines.';
    }
    return null;
  }

  static void debugPrintConfig() {
    debugPrint(
      'KadmatTestConfig(e2eEnabled: $e2eEnabled, hasSupabaseConfig: $hasSupabaseConfig)',
    );
  }
}
