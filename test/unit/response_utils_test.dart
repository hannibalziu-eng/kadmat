import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/api/response_utils.dart';

void main() {
  group('response utils', () {
    test('prefers nested data field over root field', () {
      final payload = {
        'token': 'legacy-token',
        'data': {'token': 'new-token'},
      };

      expect(responseField(payload, 'token'), 'new-token');
    });

    test('falls back to root field when nested data is missing', () {
      final payload = {'token': 'legacy-token'};
      expect(responseField(payload, 'token'), 'legacy-token');
    });

    test('returns empty list and map helpers safely', () {
      expect(responseListField({}, 'notifications'), isEmpty);
      expect(responseObjectField({}, 'service'), isEmpty);
    });

    test('parses success flag with safe default', () {
      expect(responseSucceeded({'success': true}), isTrue);
      expect(responseSucceeded({'success': false}), isFalse);
      expect(
        responseSucceeded({'token': 'legacy'}, defaultValue: true),
        isTrue,
      );
    });

    test('extracts payload map from wrapped and unwrapped responses', () {
      expect(
        responsePayloadMap({
          'success': true,
          'data': {'id': '1', 'name': 'wrapped'},
        }),
        {'id': '1', 'name': 'wrapped'},
      );

      expect(responsePayloadMap({'id': '1', 'name': 'legacy'}), {
        'id': '1',
        'name': 'legacy',
      });
    });

    test('extracts payload list from wrapped response', () {
      final payload = {
        'success': true,
        'data': [
          {'id': '1'},
          {'id': '2'},
        ],
      };
      expect(responsePayloadList(payload).length, 2);
    });
  });
}
