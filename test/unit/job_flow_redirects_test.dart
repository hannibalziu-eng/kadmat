import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/core/navigation/job_flow_redirects.dart';

void main() {
  group('Job Flow Redirects Tests', () {
    const jobId = 'job-123';

    test('maps accepted to customer technician-found route', () {
      final route = customerRouteForJobStatus(status: 'accepted', jobId: jobId);
      expect(route, AppRoutes.buildCustomerTechnicianFoundPath(jobId));
    });

    test('maps in_progress to customer in-progress route', () {
      final route = customerRouteForJobStatus(
        status: 'in_progress',
        jobId: jobId,
      );
      expect(route, AppRoutes.buildCustomerInProgressPath(jobId));
    });

    test('maps on_the_way to customer in-progress route', () {
      final route = customerRouteForJobStatus(
        status: 'on_the_way',
        jobId: jobId,
      );
      expect(route, AppRoutes.buildCustomerInProgressPath(jobId));
    });

    test('maps arrived to customer in-progress route', () {
      final route = customerRouteForJobStatus(status: 'arrived', jobId: jobId);
      expect(route, AppRoutes.buildCustomerInProgressPath(jobId));
    });

    test('maps pending_confirm to customer confirm-completion route', () {
      final route = customerRouteForJobStatus(
        status: 'pending_confirm',
        jobId: jobId,
      );
      expect(route, AppRoutes.buildCustomerConfirmCompletionPath(jobId));
    });

    test('maps legacy pending_confirmation to confirm-completion route', () {
      final route = customerRouteForJobStatus(
        status: 'pending_confirmation',
        jobId: jobId,
      );
      expect(route, AppRoutes.buildCustomerConfirmCompletionPath(jobId));
    });

    test('maps completed to customer rate route', () {
      final route = customerRouteForJobStatus(
        status: 'completed',
        jobId: jobId,
      );
      expect(route, AppRoutes.buildCustomerRatePath(jobId));
    });

    test('returns null for searching state', () {
      final route = customerRouteForJobStatus(
        status: 'searching',
        jobId: jobId,
      );
      expect(route, isNull);
    });
  });
}
