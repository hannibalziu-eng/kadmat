import 'package:flutter_test/flutter_test.dart';

import 'package:kadmat/src/features/jobs/domain/job.dart';
import 'package:kadmat/src/features/jobs/domain/job_visibility_policy.dart';

Job _buildJob({
  required String id,
  required String status,
  required DateTime createdAt,
  String? technicianId,
  String customerId = 'customer-1',
  String serviceId = 'service-1',
}) {
  return Job(
    id: id,
    customerId: customerId,
    serviceId: serviceId,
    technicianId: technicianId,
    status: status,
    lat: 24.7136,
    lng: 46.6753,
    createdAt: createdAt,
  );
}

void main() {
  group('JobVisibilityPolicy', () {
    test('shows pending unassigned job within 24h', () {
      final now = DateTime(2026, 2, 13, 12, 0, 0);
      final job = _buildJob(
        id: '1',
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 1)),
      );

      expect(
        JobVisibilityPolicy.isVisibleForTechnicianQueue(job, now: now),
        isTrue,
      );
    });

    test('hides cancelled job', () {
      final now = DateTime(2026, 2, 13, 12, 0, 0);
      final job = _buildJob(
        id: '2',
        status: 'cancelled',
        createdAt: now.subtract(const Duration(minutes: 20)),
      );

      expect(
        JobVisibilityPolicy.isVisibleForTechnicianQueue(job, now: now),
        isFalse,
      );
    });

    test('hides assigned job even if status is pending', () {
      final now = DateTime(2026, 2, 13, 12, 0, 0);
      final job = _buildJob(
        id: '3',
        status: 'pending',
        technicianId: 'tech-1',
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      expect(
        JobVisibilityPolicy.isVisibleForTechnicianQueue(job, now: now),
        isFalse,
      );
    });

    test('hides pending/searching older than 24h', () {
      final now = DateTime(2026, 2, 13, 12, 0, 0);
      final job = _buildJob(
        id: '4',
        status: 'searching',
        createdAt: now.subtract(const Duration(hours: 25)),
      );

      expect(
        JobVisibilityPolicy.isVisibleForTechnicianQueue(job, now: now),
        isFalse,
      );
    });

    test('hides no_technician_found older than 2h', () {
      final now = DateTime(2026, 2, 13, 12, 0, 0);
      final job = _buildJob(
        id: '5',
        status: 'no_technician_found',
        createdAt: now.subtract(const Duration(hours: 3)),
      );

      expect(
        JobVisibilityPolicy.isVisibleForTechnicianQueue(job, now: now),
        isFalse,
      );
    });

    test('filters and sorts visible jobs descending by creation time', () {
      final now = DateTime(2026, 2, 13, 12, 0, 0);
      final jobs = <Job>[
        _buildJob(
          id: 'old-visible',
          status: 'pending',
          customerId: 'customer-2',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        _buildJob(
          id: 'hidden-cancelled',
          status: 'cancelled',
          createdAt: now.subtract(const Duration(minutes: 30)),
        ),
        _buildJob(
          id: 'new-visible',
          status: 'searching',
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
      ];

      final result = JobVisibilityPolicy.filterForTechnicianQueue(
        jobs,
        now: now,
      );

      expect(result.map((e) => e.id).toList(), ['new-visible', 'old-visible']);
    });

    test('keeps only newest open request per customer/service pair', () {
      final now = DateTime(2026, 2, 13, 12, 0, 0);
      final jobs = <Job>[
        _buildJob(
          id: 'old-duplicate',
          status: 'searching',
          customerId: 'customer-dup',
          serviceId: 'service-dup',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
        _buildJob(
          id: 'new-duplicate',
          status: 'pending',
          customerId: 'customer-dup',
          serviceId: 'service-dup',
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
        _buildJob(
          id: 'other-service',
          status: 'pending',
          customerId: 'customer-dup',
          serviceId: 'service-other',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
      ];

      final result = JobVisibilityPolicy.filterForTechnicianQueue(
        jobs,
        now: now,
      );

      expect(result.map((e) => e.id).toList(), [
        'other-service',
        'new-duplicate',
      ]);
    });
  });
}
