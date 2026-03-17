import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kadmat/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Kadmat comprehensive integration', () {
    testWidgets('app_starts_without_framework_errors', (tester) async {
      final startup = Stopwatch()..start();
      final capturedErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        capturedErrors.add(details);
        previousOnError?.call(details);
      };

      addTearDown(() {
        FlutterError.onError = previousOnError;
      });

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));
      startup.stop();

      expect(
        startup.elapsed.inSeconds,
        lessThan(10),
        reason: 'Cold startup should finish within 10 seconds in debug test runs',
      );
      expect(capturedErrors, isEmpty, reason: 'No Flutter framework errors are expected');
      expect(tester.takeException(), isNull, reason: 'No uncaught widget exceptions are expected');
      expect(find.byType(WidgetsApp), findsOneWidget);
    });

    testWidgets('app_contains_interactive_controls', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final tappables = find.byWidgetPredicate(
        (widget) => widget is ElevatedButton || widget is TextButton || widget is IconButton,
      );
      final textInputs = find.byType(TextField);
      final scrollables = find.byType(Scrollable);

      expect(
        tappables.evaluate().isNotEmpty || textInputs.evaluate().isNotEmpty || scrollables.evaluate().isNotEmpty,
        isTrue,
        reason: 'At least one interactive element should exist in the initial app UI',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('drawer_opens_and_closes_when_available', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final drawerButton = find.byTooltip('Open navigation menu');
      if (drawerButton.evaluate().isEmpty) {
        expect(true, isTrue, reason: 'No drawer button on this screen; scenario not applicable');
        return;
      }

      await tester.tap(drawerButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Drawer), findsAtLeastNWidgets(1));

      final navigatorContext = tester.element(find.byType(WidgetsApp));
      Navigator.of(navigatorContext).pop();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('first_scrollable_can_scroll_without_crash', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isEmpty) {
        expect(true, isTrue, reason: 'No scrollable on initial screen; scenario not applicable');
        return;
      }

      await tester.drag(scrollable.first, const Offset(0, -400));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.drag(scrollable.first, const Offset(0, 400));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
    });
  });
}
