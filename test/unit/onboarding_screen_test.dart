import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/auth/presentation/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('shows first page and moves to second page on next tap', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

      expect(find.text('اختر الخدمة التي تحتاجها'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      expect(find.text('حدد موقعك'), findsOneWidget);
    });
  });
}
