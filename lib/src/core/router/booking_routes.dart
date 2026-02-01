import 'package:go_router/go_router.dart';
import '../../features/booking/presentation/booking_screen.dart';
import '../../features/booking/presentation/service_details_screen.dart';
import '../navigation/app_routes.dart';

List<GoRoute> getBookingRoutes() {
  return [
    GoRoute(
      path: AppRoutes.booking,
      builder: (context, state) {
        final serviceId = state.pathParameters['serviceId']!;
        return BookingScreen(serviceId: serviceId);
      },
    ),
    GoRoute(
      path: AppRoutes.serviceDetails,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ServiceDetailsScreen(
          serviceId: extra['serviceId'],
          serviceName: extra['serviceName'],
        );
      },
    ),
  ];
}
