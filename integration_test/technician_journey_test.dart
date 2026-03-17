import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kadmat/main.dart' as app;

import 'helpers/test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skipReason = KadmatTestConfig.skipReasonIfDisabled();

  group('Technician journey', () {
    testWidgets(
      'launches app and can handle navigation interactions',
      skip: skipReason,
      (tester) async {
        KadmatTestConfig.debugPrintConfig();

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 10));

        final drawerButton = find.byTooltip('Open navigation menu');
        if (drawerButton.evaluate().isNotEmpty) {
          await tester.tap(drawerButton.first);
          await tester.pumpAndSettle(const Duration(seconds: 3));
        }

        final tappables = find.byWidgetPredicate(
          (w) => w is ElevatedButton || w is TextButton || w is IconButton,
        );
        if (tappables.evaluate().isNotEmpty) {
          await tester.tap(tappables.first);
          await tester.pump(const Duration(milliseconds: 400));
        }

        expect(tester.takeException(), isNull);
      },
    );
  });
}
