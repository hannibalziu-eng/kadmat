import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/home/data/service_repository.dart';
import 'package:kadmat/src/features/home/domain/service.dart';
import 'package:kadmat/src/features/jobs/presentation/screens/customer_service_request_screen.dart';

class _FakeServiceRepository extends ServiceRepository {
  _FakeServiceRepository(this._services) : super(Dio());

  final List<Service> _services;

  @override
  Future<List<Service>> getServices() async => _services;
}

void main() {
  testWidgets(
    'CustomerServiceRequestScreen preselects the initial service when provided',
    (tester) async {
      final repository = _FakeServiceRepository([
        const Service(
          id: 'svc-1',
          name: 'Plumbing',
          nameAr: 'سباكة',
          basePrice: 50,
          isActive: true,
        ),
        const Service(
          id: 'svc-2',
          name: 'AC Maintenance',
          nameAr: 'صيانة تكييف',
          basePrice: 75,
          isActive: true,
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [serviceRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: CustomerServiceRequestScreen(initialServiceId: 'svc-2'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('صيانة تكييف'), findsOneWidget);
      expect(find.text('اختر الخدمة'), findsNothing);
    },
  );
}
