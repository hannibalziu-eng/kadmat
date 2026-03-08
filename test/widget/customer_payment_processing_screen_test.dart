import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/jobs/data/job_repository.dart';
import 'package:kadmat/src/features/jobs/domain/job.dart';
import 'package:kadmat/src/features/jobs/presentation/screens/customer_payment_processing_screen.dart';
import 'package:mockito/mockito.dart';

class _MockJobRepository extends Mock implements JobRepository {
  @override
  Future<Job?> getJobById(String jobId) {
    return super.noSuchMethod(
          Invocation.method(#getJobById, [jobId]),
          returnValue: Future<Job?>.value(null),
          returnValueForMissingStub: Future<Job?>.value(null),
        )
        as Future<Job?>;
  }
}

void main() {
  testWidgets(
    'CustomerPaymentProcessingScreen shows only supported payment option when online payments are disabled',
    (tester) async {
      final mockRepository = _MockJobRepository();
      final job = Job(
        id: 'job-1',
        customerId: 'customer-1',
        serviceId: 'service-1',
        status: 'pending_confirm',
        createdAt: DateTime(2026, 3, 8),
        lat: 32.887,
        lng: 13.191,
        finalPrice: 120,
      );

      when(mockRepository.getJobById('job-1')).thenAnswer((_) async => job);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [jobRepositoryProvider.overrideWithValue(mockRepository)],
          child: const MaterialApp(
            home: CustomerPaymentProcessingScreen(jobId: 'job-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Apple Pay'), findsNothing);
      expect(find.text('بطاقة مدى / ائتمان'), findsNothing);
      expect(find.text('نقداً (تم التسليم للفني)'), findsOneWidget);
      expect(find.text('الدفع الإلكتروني مؤجل في هذه النسخة'), findsOneWidget);
      expect(find.text('تأكيد التسليم النقدي'), findsOneWidget);
    },
  );
}
