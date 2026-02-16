import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/core/router_modular.dart';

void main() {
  group('Router modular redirect rules', () {
    test('technician auth matcher is exact and excludes technician profile', () {
      expect(isTechnicianAuthPath(AppRoutes.technicianLogin), isTrue);
      expect(isTechnicianAuthPath(AppRoutes.technicianRegister), isTrue);
      expect(isTechnicianAuthPath(AppRoutes.technicianLanding), isTrue);

      final profilePath = AppRoutes.buildTechnicianProfilePath(
        'c58ca97f-7948-40a9-93d3-cbf9c775a9b2',
      );
      expect(isTechnicianAuthPath(profilePath), isFalse);
    });

    test('technician private matcher excludes auth and customer profile path', () {
      expect(isTechnicianPrivatePath(AppRoutes.technicianHome), isTrue);
      expect(isTechnicianPrivatePath(AppRoutes.technicianSettings), isTrue);
      expect(isTechnicianPrivatePath('/technician/waitlist-offer/123'), isTrue);

      final profilePath = AppRoutes.buildTechnicianProfilePath(
        'c58ca97f-7948-40a9-93d3-cbf9c775a9b2',
      );
      expect(isTechnicianPrivatePath(profilePath), isFalse);
      expect(isTechnicianPrivatePath(AppRoutes.technicianLogin), isFalse);
    });
  });
}
