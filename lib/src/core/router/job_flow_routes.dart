import 'package:go_router/go_router.dart';
import '../../features/jobs/presentation/screens/customer_screens.dart';
import '../navigation/app_routes.dart';

List<GoRoute> getJobFlowRoutes() {
  return [
    // Customer Job Flow Routes
    GoRoute(
      path: AppRoutes.customerJobSearching,
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return CustomerSearchingScreen(jobId: jobId);
      },
    ),
    GoRoute(
      path: AppRoutes.customerTechnicianFound,
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return CustomerTechnicianFoundScreen(jobId: jobId);
      },
    ),
    GoRoute(
      path: AppRoutes.customerPriceOffer,
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return CustomerPriceOfferScreen(jobId: jobId);
      },
    ),
    GoRoute(
      path: AppRoutes.customerInProgress,
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return CustomerJobTrackingScreen(jobId: jobId);
      },
    ),
    GoRoute(
      path: AppRoutes.customerPaymentProcessing,
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return CustomerPaymentProcessingScreen(jobId: jobId);
      },
    ),
    GoRoute(
      path: AppRoutes.customerRate,
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return CustomerRateScreen(jobId: jobId);
      },
    ),
    GoRoute(
      path: AppRoutes.customerCompleted,
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return CustomerCompletedScreen(jobId: jobId);
      },
    ),
  ];
}
