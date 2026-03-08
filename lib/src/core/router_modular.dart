import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

const Set<String> _customerPrivatePaths = {
  AppRoutes.customerWallet,
  AppRoutes.customerWalletTransactions,
  AppRoutes.customerCreateRequest,
};

const Set<String> _adminPaths = {AppRoutes.admin, AppRoutes.adminDashboard};

@visibleForTesting
bool isTechnicianAuthPath(String path) => _technicianAuthPaths.contains(path);

@visibleForTesting
bool isCustomerPrivatePath(String path) => _customerPrivatePaths.contains(path);

@visibleForTesting
bool isAdminPath(String path) =>
    _adminPaths.contains(path) || path.startsWith('${AppRoutes.admin}/');

@visibleForTesting
bool isTechnicianPrivatePath(String path) {
  if (isTechnicianAuthPath(path)) return false;

  return path == AppRoutes.technicianHome ||
      path == AppRoutes.wallet ||
      path == AppRoutes.technicianSettings ||
      path == AppRoutes.technicianHelp ||
      path.startsWith('/technician/');
}

@visibleForTesting
String? resolveRouterUserType({
  String? storedUserType,
  Map<String, dynamic>? sessionUserMetadata,
}) {
  if (storedUserType != null && storedUserType.trim().isNotEmpty) {
    return storedUserType.trim();
  }

  final fallback = sessionUserMetadata?['user_type']?.toString().trim();
  if (fallback == null || fallback.isEmpty) return null;
  return fallback;
}

@riverpod
GoRouter goRouter(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      debugPrint('📍 GoRouter Redirect: ${state.uri.path}');
      final currentSession = Supabase.instance.client.auth.currentSession;
      final resolvedUserType = resolveRouterUserType(
        storedUserType: ref.read(authRepositoryProvider).userType,
        sessionUserMetadata: currentSession?.user.userMetadata,
      );
      final isLoggedIn =
          authState.valueOrNull != null || currentSession != null;
      debugPrint('👤 Is Logged In: $isLoggedIn');

      final isLoggingIn = state.uri.path == AppRoutes.login;
      final isWelcome = state.uri.path == AppRoutes.welcome;
      final isRegistering = state.uri.path == AppRoutes.register;
      final isRecoveringPassword = state.uri.path == AppRoutes.forgotPassword;
      final isTechnicianAuthPage = isTechnicianAuthPath(state.uri.path);
      final isAdminArea = isAdminPath(state.uri.path);
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
        if (resolvedUserType != 'technician') {
          debugPrint('↪️  Redirecting customer away from technician area');
          return AppRoutes.home;
        }
      }

      if (isLoggedIn && isAdminArea && resolvedUserType != 'admin') {
        debugPrint('↪️  Redirecting non-admin away from admin area');
        return resolvedUserType == 'technician'
            ? AppRoutes.technicianHome
            : AppRoutes.home;
      }

      if (isLoggedIn &&
          resolvedUserType == 'technician' &&
          isCustomerPrivatePath(state.uri.path)) {
        debugPrint('↪️  Redirecting technician away from customer-only area');
        return AppRoutes.technicianHome;
      }

      // Public profile route should stay accessible to logged-in users.
      if (isLoggedIn && isTechnicianPublicProfile) {
        return null;
      }

      // Redirect technicians to their home if they try to access customer home
      if (isLoggedIn && state.uri.path == AppRoutes.home) {
        debugPrint('👤 User Type: $resolvedUserType');
        if (resolvedUserType == 'technician') {
          debugPrint('↪️  Redirecting to Technician Home');
          return AppRoutes.technicianHome;
        }
        if (resolvedUserType == 'admin') {
          debugPrint('↪️  Redirecting to Admin Dashboard');
          return AppRoutes.admin;
        }
      }

      if (isLoggedIn &&
          (isLoggingIn ||
              isWelcome ||
              isRegistering ||
              isRecoveringPassword ||
              isTechnicianAuthPage)) {
        debugPrint(
          '👤 Redirecting from auth page. User Type: $resolvedUserType',
        );
        if (resolvedUserType == 'technician') {
          return AppRoutes.technicianHome;
        }
        if (resolvedUserType == 'admin') {
          return AppRoutes.admin;
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
