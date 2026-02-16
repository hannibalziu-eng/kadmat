import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/bidding/presentation/widgets/countdown_timer.dart';

void main() {
  group('CountdownTimer', () {
    testWidgets('renders correctly with initial time', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountdownTimer(
              endsAt: now.add(const Duration(minutes: 15)),
              onExpired: () {},
              onExtend: () {},
              now: () => now, // Fixed time for test
            ),
          ),
        ),
      );

      expect(find.text('الوقت المتبقي للمناقصة'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
    });

    testWidgets('counts down correctly', (tester) async {
      var testTime = DateTime.parse('2024-01-01 12:00:00');
      final endsAt = testTime.add(const Duration(minutes: 14));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountdownTimer(
              endsAt: endsAt,
              onExpired: () {},
              onExtend: () {},
              now: () => testTime,
            ),
          ),
        ),
      );

      // Advance time manually
      testTime = testTime.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1)); // Trigger Timer

      expect(find.text('13:59'), findsOneWidget);
    });

    testWidgets('shows warnings and urgent style when < 2 minutes', (
      tester,
    ) async {
      var testTime = DateTime.parse('2024-01-01 12:00:00');
      final endsAt = testTime.add(const Duration(minutes: 1, seconds: 59));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountdownTimer(
              endsAt: endsAt,
              onExpired: () {},
              onExtend: () {},
              now: () => testTime,
            ),
          ),
        ),
      );

      await tester.pump(); // Initial frame

      // Should show warning immediately or after post frame?
      // Logic: if remaining <= 2min, schedule update.
      // Pump adds frame.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('⚠️ تبقى دقيقتان فقط!'), findsOneWidget);
    });

    testWidgets('calls onExpired when time runs out', (tester) async {
      var expired = false;
      var testTime = DateTime.parse('2024-01-01 12:00:00');
      final endsAt = testTime.add(const Duration(seconds: 2));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountdownTimer(
              endsAt: endsAt,
              onExpired: () => expired = true,
              onExtend: () {},
              now: () => testTime,
            ),
          ),
        ),
      );

      // Advance 3 seconds
      testTime = testTime.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));

      expect(expired, isTrue);
      expect(find.text('انتهى الوقت'), findsOneWidget);
    });

    testWidgets('calls onExtend when button pressed', (tester) async {
      var extended = false;
      final now = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountdownTimer(
              endsAt: now.add(const Duration(minutes: 4)),
              onExpired: () {},
              onExtend: () => extended = true,
              now: () => now,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final extendButton = find.text('تمديد 5 دقائق');
      expect(extendButton, findsOneWidget);

      await tester.tap(extendButton);
      expect(extended, isTrue);
    });
  });
}
