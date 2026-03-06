import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/app_theme.dart';
import 'package:kadmat/src/core/widgets/kadmat_components.dart';

void main() {
  group('KadmatComponents', () {
    testWidgets('primary button shows loader and disables tap while loading', (
      tester,
    ) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: KadmatPrimaryButton(
              label: 'حفظ',
              isLoading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('حفظ'), findsNothing);

      await tester.tap(find.byType(KadmatPrimaryButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('secondary button renders label and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: KadmatSecondaryButton(
              label: 'تسجيل الدخول',
              icon: Icons.login,
            ),
          ),
        ),
      );

      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);
    });

    testWidgets('text field renders label and validates', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Form(
              key: formKey,
              child: KadmatTextField(
                controller: controller,
                label: 'البريد الإلكتروني',
                prefixIcon: Icons.email,
                validator: (value) =>
                    value == null || value.isEmpty ? 'مطلوب' : null,
              ),
            ),
          ),
        ),
      );

      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);

      expect(formKey.currentState!.validate(), isFalse);
      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      expect(formKey.currentState!.validate(), isTrue);
    });
  });
}
