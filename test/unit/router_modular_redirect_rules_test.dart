import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/core/router_modular.dart';

void main() {
  group('Router modular redirect rules', () {
    test(
      'technician auth matcher is exact and excludes technician profile',
      () {
        expect(isTechnicianAuthPath(AppRoutes.technicianLogin), isTrue);
        expect(isTechnicianAuthPath(AppRoutes.technicianRegister), isTrue);
        expect(isTechnicianAuthPath(AppRoutes.technicianLanding), isTrue);

        final profilePath = AppRoutes.buildTechnicianProfilePath(
          'c58ca97f-7948-40a9-93d3-cbf9c775a9b2',
        );
        expect(isTechnicianAuthPath(profilePath), isFalse);
      },
    );

    test(
      'technician private matcher excludes auth and customer profile path',
      () {
        expect(isTechnicianPrivatePath(AppRoutes.technicianHome), isTrue);
        expect(isTechnicianPrivatePath(AppRoutes.wallet), isTrue);
        expect(isTechnicianPrivatePath(AppRoutes.technicianSettings), isTrue);
        expect(
          isTechnicianPrivatePath('/technician/waitlist-offer/123'),
          isTrue,
        );

        final profilePath = AppRoutes.buildTechnicianProfilePath(
          'c58ca97f-7948-40a9-93d3-cbf9c775a9b2',
        );
        expect(isTechnicianPrivatePath(profilePath), isFalse);
        expect(isTechnicianPrivatePath(AppRoutes.technicianLogin), isFalse);
      },
    );

    test(
      'customer private matcher includes customer wallet routes and request creation only',
      () {
        expect(isCustomerPrivatePath(AppRoutes.customerWallet), isTrue);
        expect(
          isCustomerPrivatePath(AppRoutes.customerWalletTransactions),
          isTrue,
        );
        expect(isCustomerPrivatePath(AppRoutes.customerCreateRequest), isTrue);
        expect(isCustomerPrivatePath(AppRoutes.wallet), isFalse);
        expect(isCustomerPrivatePath(AppRoutes.notifications), isFalse);
      },
    );

    test('admin matcher includes admin routes only', () {
      expect(isAdminPath(AppRoutes.admin), isTrue);
      expect(isAdminPath(AppRoutes.adminDashboard), isTrue);
      expect(isAdminPath('/admin/users'), isTrue);
      expect(isAdminPath(AppRoutes.home), isFalse);
      expect(isAdminPath(AppRoutes.technicianHome), isFalse);
    });

    test(
      'router user type prefers stored value and falls back to session metadata',
      () {
        expect(
          resolveRouterUserType(
            storedUserType: 'technician',
            sessionUserMetadata: const {'user_type': 'customer'},
          ),
          'technician',
        );

        expect(
          resolveRouterUserType(
            storedUserType: null,
            sessionUserMetadata: const {'user_type': 'customer'},
          ),
          'customer',
        );

        expect(
          resolveRouterUserType(
            storedUserType: null,
            sessionUserMetadata: const {},
          ),
          isNull,
        );
      },
    );
  });
}
