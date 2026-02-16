import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/core/navigation/router_fallbacks.dart';

void main() {
  group('Unknown route fallback resolver', () {
    test('maps unknown technician step to technician detail', () {
      const jobId = '452c1928-727b-49e8-944e-1485eb488402';
      final resolved = resolveUnknownTechnicianJobPath(
        '/jobs/$jobId/technician/legacy-step',
      );

      expect(resolved, AppRoutes.buildTechnicianJobDetailPath(jobId));
    });

    test('does not fallback for known technician bidding step', () {
      const jobId = '452c1928-727b-49e8-944e-1485eb488402';
      final resolved = resolveUnknownTechnicianJobPath(
        '/jobs/$jobId/technician/bidding',
      );

      expect(resolved, isNull);
    });

    test('falls back to technician home for non-job unknown route', () {
      final resolved = resolveUnknownRouteFallback(
        location: '/random/unknown',
        isTechnicianUser: true,
      );

      expect(resolved, AppRoutes.technicianHome);
    });
  });
}
