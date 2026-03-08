import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/utils/service_name_formatter.dart';

void main() {
  group('formatServiceDisplayName', () {
    test('prefers Arabic service name when available', () {
      expect(
        formatServiceDisplayName(const {
          'name': 'ac_maintenance',
          'name_ar': 'صيانة تكييف',
        }),
        'صيانة تكييف',
      );
    });

    test('localizes known service slug when Arabic name is missing', () {
      expect(formatServiceDisplayName('ac_maintenance'), 'صيانة تكييف');
    });

    test('falls back to a cleaned English label for unknown slugs', () {
      expect(
        formatServiceDisplayName('custom_service_type'),
        'Custom Service Type',
      );
    });
  });
}
