import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kadmat/main.dart' as app;

import 'helpers/test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skipReason = KadmatTestConfig.skipReasonIfDisabled();

  group('Customer journey', () {
    testWidgets('launches app and keeps UI responsive', skip: skipReason, (
      tester,
    ) async {
      KadmatTestConfig.debugPrintConfig();

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(WidgetsApp), findsOneWidget);
      expect(tester.takeException(), isNull);

      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.first, const Offset(0, -300));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await tester.drag(scrollables.first, const Offset(0, 300));
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      expect(tester.takeException(), isNull);
    });
  });
}
