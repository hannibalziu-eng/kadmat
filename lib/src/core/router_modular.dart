import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../features/auth/data/auth_repository.dart';
import 'router/route_modules.dart';
import 'navigation/app_routes.dart';

part 'router_modular.g.dart';

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
      // Main routes with nested sub-routes
      ...RouteModules.getMainRoutes(),

      // Auth routes
      ...RouteModules.getAuthRoutes(),

      // Technician routes
      ...RouteModules.getTechnicianRoutes(),

      // Job flow routes
      ...RouteModules.getJobFlowRoutes(),

      // Utility routes
      ...RouteModules.getUtilityRoutes(),
    ],
  );
}
