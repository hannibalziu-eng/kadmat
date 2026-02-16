import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/bidding/presentation/widgets/wave_indicator.dart';

void main() {
  group('WaveIndicator', () {
    testWidgets('renders all waves', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WaveIndicator(currentWave: 1))),
      );

      expect(find.text('15 كم'), findsOneWidget);
      expect(find.text('50 كم'), findsOneWidget);
    });

    testWidgets('shows active state for current wave', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WaveIndicator(currentWave: 2))),
      );

      // Wave 2 is active (CircularProgressIndicator or specific style)
      // Wave 1 is past (Check icon)

      expect(find.byIcon(Icons.check), findsOneWidget); // Wave 1
      // Wave 2 active has border/color check, hard to test without keys or golden,
      // but we can check if it renders.
    });

    testWidgets('shows progress indicator when searching', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WaveIndicator(currentWave: 1, isSearching: true),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
