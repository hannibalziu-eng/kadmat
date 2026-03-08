import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/utils/location_error_message.dart';

void main() {
  group('resolveLocationErrorMessage', () {
    test('maps permission failures to user-friendly guidance', () {
      final message = resolveLocationErrorMessage(Exception('Permission denied'));

      expect(message, contains('اسمح'));
      expect(message, contains('الموقع'));
    });

    test('maps timeout failures to retry guidance', () {
      final message = resolveLocationErrorMessage(Exception('Timeout exceeded'));

      expect(message, contains('تعذر تحديد الموقع'));
    });

    test('falls back to generic location message', () {
      final message = resolveLocationErrorMessage(Exception('weird failure'));

      expect(message, contains('تعذر تحديد الموقع الحالي'));
    });
  });
}
