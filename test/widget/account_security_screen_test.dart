import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/profile/presentation/account_security_screen.dart';

void main() {
  testWidgets(
    'AccountSecurityScreen shows one active control and non-interactive upcoming features',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AccountSecurityScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.text('أبقِ أمان الحساب بسيطًا وواضحًا'), findsOneWidget);
      expect(find.text('المتاح الآن'), findsOneWidget);
      expect(find.text('لاحقًا'), findsAtLeastNWidgets(1));
      expect(find.text('تغيير كلمة المرور'), findsAtLeastNWidgets(1));
      expect(
        find.text('المصادقة الثنائية (2FA)', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('الأجهزة المتصلة', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'AccountSecurityScreen opens change password dialog from the active option',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AccountSecurityScreen())),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('تغيير كلمة المرور').first);
      await tester.pumpAndSettle();

      expect(find.text('كلمة المرور الجديدة'), findsOneWidget);
      expect(find.text('تأكيد كلمة المرور'), findsOneWidget);
    },
  );
}
