import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:kadmat/main.dart';

void main() {
  patrolTest('Technician Flow: Login and Navigation', ($) async {
    // Launch app
    await $.pumpWidgetAndSettle(const MyApp());

    // 1. Verify on Welcome Screen
    expect($('تسجيل الدخول'), findsOneWidget);

    // 2. Navigate to Login
    await $('تسجيل الدخول').tap();
    await $.pumpAndSettle();

    // 3. Enter Credentials
    // Targeting by InputDecoration hintText since keys aren't explicit
    await $(TextField)
        .which(
          (w) =>
              (w as TextField).decoration?.hintText?.contains('البريد') ??
              false,
        )
        .enterText('tech@test.com');
    await $(TextField)
        .which(
          (w) =>
              (w as TextField).decoration?.hintText?.contains('كلمة المرور') ??
              false,
        )
        .enterText('password123');

    // 4. Submit
    await $('تسجيل الدخول').tap();
    await $.pumpAndSettle();

    // 5. Verify Home Screen (Technician Dashboard)
    expect($('الرئيسية'), findsAtLeastNWidgets(1));
    expect($('الطلبات'), findsOneWidget);
    expect($('المحفظة'), findsOneWidget);

    // 6. Navigate to Requests Tab
    await $('الطلبات').tap();
    await $.pumpAndSettle();

    // 7. Verify Requests Screen Loaded
    // Check we are on the screen by finding the tab labels
    expect($('طلبات جديدة'), findsAtLeastNWidgets(1));

    // 8. Verify No Error State (confirms RPC fix)
    expect(find.textContaining('خطأ:'), findsNothing);

    // 9. Check for Job List or Empty State
    // We handle both cases since test data might vary
    final hasEmptyState = $('لا توجد طلبات جديدة حالياً').exists;
    if (hasEmptyState) {
      debugPrint('✅ Validated Empty State for Requests');
    } else {
      // If not empty, we expect cards
      debugPrint('✅ Validated Jobs List Present');
      expect($(Card), findsAtLeastNWidgets(1));
    }
  });
}
