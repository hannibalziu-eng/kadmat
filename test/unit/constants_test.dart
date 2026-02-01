import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/constants.dart';

void main() {
  group('AppConstants Tests', () {
    test(
      'should return empty strings when environment variables are not set',
      () {
        // Test when dotenv is not loaded
        expect(AppConstants.supabaseUrl, isEmpty);
        expect(AppConstants.supabaseAnonKey, isEmpty);
      },
    );

    test('should handle environment variable loading safely', () {
      // This test ensures the app doesn't crash when env vars are missing
      expect(() => AppConstants.supabaseUrl, returnsNormally);
      expect(() => AppConstants.supabaseAnonKey, returnsNormally);
    });
  });
}
