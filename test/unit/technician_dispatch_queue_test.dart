import 'package:flutter_test/flutter_test.dart';

import 'package:kadmat/src/features/jobs/domain/job.dart';
import 'package:kadmat/src/features/technician/presentation/utils/technician_dispatch_queue.dart';

Job _buildJob({
  required String id,
  required String status,
  required DateTime createdAt,
  double lat = 24.7136,
  double lng = 46.6753,
}) {
  return Job(
    id: id,
    customerId: 'customer-1',
    serviceId: 'service-1',
    status: status,
    lat: lat,
    lng: lng,
    createdAt: createdAt,
  );
}

void main() {
  group('TechnicianDispatchQueue', () {
    test('hides expired pending/searching and no_technician_found jobs', () {
      final now = DateTime(2026, 2, 13, 12, 0, 0);

      final pendingExpired = _buildJob(
        id: 'pending-expired',
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 25)),
      );
      final noTechExpired = _buildJob(
        id: 'no-tech-expired',
        status: 'no_technician_found',
        createdAt: now.subtract(const Duration(hours: 3)),
      );

      expect(
        TechnicianDispatchQueue.isExpiredQueueJob(pendingExpired, now: now),
        isTrue,
      );
      expect(
        TechnicianDispatchQueue.isExpiredQueueJob(noTechExpired, now: now),
        isTrue,
      );
    });

    test('prepareJobs supports urgent filter and sorting', () {
      final now = DateTime(2026, 2, 13, 12, 0, 0);
      final location = TechnicianGeoPoint(lat: 24.7136, lng: 46.6753);
      final jobs = <Job>[
        _buildJob(
          id: 'new-close',
          status: 'pending',
          createdAt: now.subtract(const Duration(minutes: 3)),
          lat: 24.71361,
          lng: 46.67531,
        ),
        _buildJob(
          id: 'urgent-far',
          status: 'pending',
          createdAt: now.subtract(const Duration(minutes: 40)),
          lat: 24.80,
          lng: 46.90,
        ),
      ];

      final urgentOnly = TechnicianDispatchQueue.prepareJobs(
        jobs: jobs,
        sortMode: TechnicianDispatchSortMode.closest,
        urgentOnly: true,
        technicianLocation: location,
        now: now,
      );

      expect(urgentOnly.map((e) => e.id).toList(), ['urgent-far']);
    });

    test('closest sorting works when location is available', () {
      final now = DateTime(2026, 2, 13, 12, 0, 0);
      final location = TechnicianGeoPoint(lat: 24.7136, lng: 46.6753);
      final jobs = <Job>[
        _buildJob(
          id: 'far',
          status: 'pending',
          createdAt: now.subtract(const Duration(minutes: 8)),
          lat: 25.0,
          lng: 47.2,
        ),
        _buildJob(
          id: 'near',
          status: 'pending',
          createdAt: now.subtract(const Duration(minutes: 9)),
          lat: 24.7137,
          lng: 46.6754,
        ),
      ];

      final result = TechnicianDispatchQueue.prepareJobs(
        jobs: jobs,
        sortMode: TechnicianDispatchSortMode.closest,
        urgentOnly: false,
        technicianLocation: location,
        now: now,
      );

      expect(result.map((e) => e.id).toList(), ['near', 'far']);
    });

    test(
      'pickPriorityJob favors no_technician_found under same conditions',
      () {
        final now = DateTime(2026, 2, 13, 12, 0, 0);
        final location = TechnicianGeoPoint(lat: 24.7136, lng: 46.6753);
        final jobs = <Job>[
          _buildJob(
            id: 'urgent-pending',
            status: 'pending',
            createdAt: now.subtract(const Duration(minutes: 20)),
          ),
          _buildJob(
            id: 'no-tech',
            status: 'no_technician_found',
            createdAt: now.subtract(const Duration(minutes: 5)),
          ),
        ];

        final priority = TechnicianDispatchQueue.pickPriorityJob(
          jobs: jobs,
          technicianLocation: location,
          now: now,
        );

        expect(priority?.id, 'no-tech');
      },
    );
  });
}
