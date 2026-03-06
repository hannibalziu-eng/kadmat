import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../features/auth/data/auth_repository.dart';
import 'router/route_modules.dart';
import 'navigation/app_routes.dart';
import 'navigation/router_fallbacks.dart';

part 'router_modular.g.dart';

const Set<String> _technicianAuthPaths = {
  AppRoutes.technicianLanding,
  AppRoutes.technicianLogin,
  AppRoutes.technicianRegister,
};

@visibleForTesting
bool isTechnicianAuthPath(String path) => _technicianAuthPaths.contains(path);

@visibleForTesting
bool isTechnicianPrivatePath(String path) {
  if (isTechnicianAuthPath(path)) return false;

  return path == AppRoutes.technicianHome ||
      path == AppRoutes.technicianSettings ||
      path == AppRoutes.technicianHelp ||
      path.startsWith('/technician/');
}

@riverpod
GoRouter goRouter(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      debugPrint('📍 GoRouter Redirect: ${state.uri.path}');
      final isLoggedIn = authState.valueOrNull != null;
      debugPrint('👤 Is Logged In: $isLoggedIn');

      final isLoggingIn = state.uri.path == AppRoutes.login;
      final isWelcome = state.uri.path == AppRoutes.welcome;
      final isRegistering = state.uri.path == AppRoutes.register;
      final isRecoveringPassword = state.uri.path == AppRoutes.forgotPassword;
      final isTechnicianAuthPage = isTechnicianAuthPath(state.uri.path);
      final isTechnicianPrivateArea = isTechnicianPrivatePath(state.uri.path);
      final isTechnicianPublicProfile = state.uri.path.startsWith(
        '/technician-profile/',
      );

      if (!isLoggedIn &&
          !isLoggingIn &&
          !isWelcome &&
          !isRegistering &&
          !isRecoveringPassword &&
          !isTechnicianAuthPage) {
        debugPrint('↪️  Redirecting to Welcome (Not logged in)');
        return AppRoutes.welcome;
      }

      if (isLoggedIn && isTechnicianPrivateArea) {
        final userType = ref.read(authRepositoryProvider).userType;
        if (userType != 'technician') {
          debugPrint('↪️  Redirecting customer away from technician area');
          return AppRoutes.home;
        }
      }

      // Public profile route should stay accessible to logged-in users.
      if (isLoggedIn && isTechnicianPublicProfile) {
        return null;
      }

      // Redirect technicians to their home if they try to access customer home
      if (isLoggedIn && state.uri.path == AppRoutes.home) {
        final userType = ref.read(authRepositoryProvider).userType;
        debugPrint('👤 User Type: $userType');
        if (userType == 'technician') {
          debugPrint('↪️  Redirecting to Technician Home');
          return AppRoutes.technicianHome;
        }
      }

      if (isLoggedIn &&
          (isLoggingIn ||
              isWelcome ||
              isRegistering ||
              isRecoveringPassword ||
              isTechnicianAuthPage)) {
        final userType = ref.read(authRepositoryProvider).userType;
        debugPrint('👤 Redirecting from auth page. User Type: $userType');
        if (userType == 'technician') {
          return AppRoutes.technicianHome;
        }
        return AppRoutes.home;
      }
      debugPrint('✅ No Redirect');
      return null;
    },
    routes: RouteModules.buildAppRoutes(),
    errorBuilder: (context, state) {
      final isTechnician =
          ref.read(authRepositoryProvider).userType == 'technician';
      final fallbackPath = resolveUnknownRouteFallback(
        location: state.uri.path,
        isTechnicianUser: isTechnician,
      );

      debugPrint(
        '⚠️ Unknown route: ${state.uri.path} -> redirecting to $fallbackPath',
      );

      if (state.uri.path != fallbackPath) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go(fallbackPath);
          }
        });
      }

      return const Scaffold(body: SizedBox.shrink());
    },
  );
}
