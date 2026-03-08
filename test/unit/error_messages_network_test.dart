import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/utils/error_messages.dart';

void main() {
  group('ErrorMessages.networkFailureMessage', () {
    test('returns localhost guidance for loopback API targets', () {
      final message = ErrorMessages.networkFailureMessage(
        url: 'http://127.0.0.1:3000/api/jobs',
      );

      expect(message, ErrorMessages.localBackendUnreachable);
    });

    test(
      'returns generic backend unreachable message for non-loopback hosts',
      () {
        final message = ErrorMessages.networkFailureMessage(
          url: 'http://192.168.1.105:3000/api/jobs',
        );

        expect(message, ErrorMessages.backendUnreachable);
      },
    );

    test('falls back to no-internet when URL is empty', () {
      final message = ErrorMessages.networkFailureMessage(url: '');

      expect(message, ErrorMessages.noInternetConnection);
    });
  });
}
