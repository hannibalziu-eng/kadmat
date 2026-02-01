import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Flag to switch payment gateway mode. true for real gateway, false for mock.
  static bool get useRealPayments {
    final v = (dotenv.env['USE_REAL_PAYMENTS'] ?? 'false').toLowerCase();
    return v == 'true' || v == '1';
  }
}
