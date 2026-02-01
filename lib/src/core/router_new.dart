import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/main/main_screen.dart';
import 'auth_routes.dart';
import 'booking_routes.dart';
import 'technician_routes.dart';
import 'wallet_routes.dart';
import 'job_flow_routes.dart';
import '../navigation/app_routes.dart';

part 'router.g.dart';

@riverpod
GoRouter goRouter(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoggingIn = state.uri.path == AppRoutes.login;
      final isWelcome = state.uri.path == AppRoutes.welcome;
      final isRegistering = state.uri.path == AppRoutes.register;
      final isRecoveringPassword = state.uri.path == AppRoutes.forgotPassword;
      final isTechnicianAuth = state.uri.path.startsWith('/technician');

      if (!isLoggedIn &&
          !isLoggingIn &&
          !isWelcome &&
          !isRegistering &&
          !isRecoveringPassword &&
          !isTechnicianAuth) {
        return AppRoutes.welcome;
      }

      // Redirect technicians to their home if they try to access customer home
      if (isLoggedIn && state.uri.path == AppRoutes.home) {
        final userType = ref.read(authRepositoryProvider).userType;
        if (userType == 'technician') {
          return AppRoutes.technicianHome;
        }
      }

      if (isLoggedIn &&
          (isLoggingIn ||
              isWelcome ||
              isRegistering ||
              isRecoveringPassword ||
              isTechnicianAuth)) {
        final userType = ref.read(authRepositoryProvider).userType;
        if (userType == 'technician') {
          return AppRoutes.technicianHome;
        }
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      // Main route
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MainScreen(),
        routes: [...getBookingRoutes()],
      ),

      // Auth routes
      ...getAuthRoutes(),

      // Technician routes
      ...getTechnicianRoutes(),

      // Wallet routes
      ...getWalletRoutes(),

      // Job flow routes
      ...getJobFlowRoutes(),

      // Additional routes that don't fit in modules
      GoRoute(
        path: AppRoutes.activeJob,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerActiveJobScreen(jobId: jobId);
        },
      ),

      GoRoute(
        path: AppRoutes.customerWallet,
        builder: (context, state) => const CustomerWalletScreen(),
      ),

      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),

      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          final extra = state.extra as Map<String, dynamic>;
          return ChatScreen(
            jobId: jobId,
            otherUserName: extra['otherUserName'],
            otherUserImage: extra['otherUserImage'],
          );
        },
      ),
    ],
  );
}
