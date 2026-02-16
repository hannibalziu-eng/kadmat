import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/core/router/route_modules.dart';

void main() {
  group('RouteModules Job Flow Contract', () {
    test('includes key technician flow routes in active modular router', () {
      final paths = RouteModules.getJobFlowRoutes().map((r) => r.path).toSet();

      expect(paths, contains(AppRoutes.technicianJobDetailV2));
      expect(paths, contains(AppRoutes.technicianBidding));
      expect(paths, contains(AppRoutes.technicianSetPrice));
      expect(paths, contains(AppRoutes.technicianInProgress));
      expect(paths, contains(AppRoutes.technicianCompleted));
    });
  });

  group('RouteModules Technician Utilities', () {
    test('includes technician settings and help routes', () {
      final paths = RouteModules.getTechnicianRoutes()
          .map((r) => r.path)
          .toSet();

      expect(paths, contains(AppRoutes.technicianSettings));
      expect(paths, contains(AppRoutes.technicianHelp));
    });
  });
}
