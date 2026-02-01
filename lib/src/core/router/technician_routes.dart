import 'package:go_router/go_router.dart';
import '../../features/technician/presentation/technician_main_screen.dart';
import '../../features/technician/presentation/jobs/technician_job_detail_screen.dart';
import '../../features/technician/presentation/technician_profile_screen.dart';
import '../navigation/app_routes.dart';

List<GoRoute> getTechnicianRoutes() {
  return [
    GoRoute(
      path: AppRoutes.technicianHome,
      builder: (context, state) => const TechnicianMainScreen(),
    ),
    GoRoute(
      path: AppRoutes.technicianJobDetail,
      builder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return TechnicianJobDetailScreen(jobId: jobId);
      },
    ),
    GoRoute(
      path: AppRoutes.technicianProfile,
      builder: (context, state) {
        final technicianId = state.pathParameters['technicianId']!;
        return TechnicianProfileScreen(technicianId: technicianId);
      },
    ),
  ];
}
