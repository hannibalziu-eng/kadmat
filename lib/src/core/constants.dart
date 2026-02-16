import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String _readEnv(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get supabaseUrl => _readEnv('SUPABASE_URL');
  static String get supabaseAnonKey => _readEnv('SUPABASE_ANON_KEY');
  static String get supportPhone => _readEnv('SUPPORT_PHONE');
  static String get supportEmail => _readEnv('SUPPORT_EMAIL');

  /// Flag to switch payment gateway mode. true for real gateway, false for mock.
  static bool get useRealPayments {
    final v = (_readEnv('USE_REAL_PAYMENTS')).toLowerCase();
    return v == 'true' || v == '1';
  }
}
