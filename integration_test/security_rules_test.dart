import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skipReason = KadmatTestConfig.skipReasonIfDisabled();

  group('Security rules sanity', () {
    testWidgets(
      'requires dedicated fixture users and policies',
      skip:
          skipReason ??
          'Enable after provisioning dedicated Supabase test fixtures.',
      (tester) async {
        // Intentionally a guarded placeholder:
        // this test should be implemented with fixture accounts that represent:
        // - anonymous
        // - authenticated customer
        // - authenticated technician
        // and then verify RLS boundaries.
        expect(true, isTrue);
      },
    );
  });
}
