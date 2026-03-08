import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/app_theme.dart';
import 'package:kadmat/src/core/utils/technician_summary.dart';
import 'package:kadmat/src/features/jobs/presentation/widgets/technician_offer_identity.dart';

void main() {
  testWidgets('renders technician identity summary details', (tester) async {
    final technician = TechnicianSummary.fromMap({
      'full_name': 'أحمد الفني',
      'title': 'خبير صيانة تكييف',
      'specialization': 'صيانة تكييف',
      'location': 'طرابلس - حي الأندلس',
      'rating': 4.9,
      'completed_jobs': 14,
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: TechnicianOfferIdentity(technician: technician),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('أحمد الفني'), findsOneWidget);
    expect(find.text('خبير صيانة تكييف'), findsOneWidget);
    expect(find.text('صيانة تكييف'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('14 مكتملة'), findsOneWidget);
    expect(find.text('طرابلس - حي الأندلس'), findsOneWidget);
  });
}
