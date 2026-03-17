import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kadmat/main.dart' as app;

import 'helpers/test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skipReason = KadmatTestConfig.skipReasonIfDisabled();

  group('Auth journey', () {
    testWidgets(
      'app startup has no uncaught errors before auth actions',
      skip: skipReason,
      (tester) async {
        KadmatTestConfig.debugPrintConfig();

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.byType(WidgetsApp), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
