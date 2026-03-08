import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/core/navigation/job_flow_redirects.dart';

void main() {
  group('customerRouteForJobStatus', () {
    test('keeps pending/searching unmanaged for current screen logic', () {
      expect(
        customerRouteForJobStatus(status: 'pending', jobId: 'job-1'),
        isNull,
      );
      expect(
        customerRouteForJobStatus(status: 'searching', jobId: 'job-1'),
        isNull,
      );
    });
  });

  group('technicianRouteForJobStatus', () {
    test('routes accepted and price_pending to set-price flow', () {
      expect(
        technicianRouteForJobStatus(status: 'accepted', jobId: 'job-2'),
        AppRoutes.buildTechnicianSetPricePath('job-2'),
      );
      expect(
        technicianRouteForJobStatus(status: 'price_pending', jobId: 'job-2'),
        AppRoutes.buildTechnicianSetPricePath('job-2'),
      );
    });

    test('routes in-service statuses to technician job detail flow', () {
      expect(
        technicianRouteForJobStatus(status: 'on_the_way', jobId: 'job-3'),
        AppRoutes.buildTechnicianJobDetailPath('job-3'),
      );
      expect(
        technicianRouteForJobStatus(status: 'pending_confirm', jobId: 'job-3'),
        AppRoutes.buildTechnicianJobDetailPath('job-3'),
      );
    });
  });
}
