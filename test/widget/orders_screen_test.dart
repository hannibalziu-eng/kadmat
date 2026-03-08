import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/jobs/domain/job.dart';
import 'package:kadmat/src/features/jobs/presentation/job_controller.dart';
import 'package:kadmat/src/features/orders/presentation/orders_screen.dart';

void main() {
  testWidgets(
    'OrdersScreen renders live jobs and no longer shows simulation controls',
    (tester) async {
      final job = Job(
        id: 'job-12345678',
        customerId: 'customer-1',
        serviceId: 'service-1',
        technicianId: 'tech-1',
        status: 'on_the_way',
        lat: 24.7,
        lng: 46.6,
        createdAt: DateTime(2026, 3, 7),
        service: const {'name': 'سباكة'},
        technician: const {'full_name': 'فني مباشر', 'phone': '2222222222'},
        acceptedBidId: 'offer-1',
        finalPrice: 150,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchMyJobsRealtimeProvider.overrideWith(
              (ref) => Stream.value([job]),
            ),
          ],
          child: const MaterialApp(home: OrdersScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('سباكة'), findsOneWidget);
      expect(find.textContaining('فني مباشر'), findsOneWidget);
      expect(find.text('محاكاة الفني'), findsNothing);
    },
  );

  testWidgets(
    'OrdersScreen does not claim technician is unassigned when technicianId exists',
    (tester) async {
      final job = Job(
        id: 'job-87654321',
        customerId: 'customer-1',
        serviceId: 'service-1',
        technicianId: 'tech-1',
        status: 'rated',
        lat: 24.7,
        lng: 46.6,
        createdAt: DateTime(2026, 3, 7),
        service: const {'name': 'صيانة'},
        technician: const {},
        acceptedBidId: 'offer-1',
        finalPrice: 95,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchMyJobsRealtimeProvider.overrideWith(
              (ref) => Stream.value([job]),
            ),
          ],
          child: const MaterialApp(home: OrdersScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تم تعيين فني'), findsOneWidget);
      expect(find.text('بانتظار تعيين الفني'), findsNothing);
    },
  );
}
