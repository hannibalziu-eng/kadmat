import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/technician_landing_screen.dart';
import '../features/auth/presentation/technician_login_screen.dart';
import '../features/auth/presentation/technician_register_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/booking/presentation/booking_screen.dart';
import '../features/booking/presentation/service_details_screen.dart';
import '../features/main/main_screen.dart';
import '../features/messages/presentation/messages_screen.dart';
import '../features/tracking/presentation/tracking_screen.dart';
import '../features/orders/presentation/technician_price_input_screen.dart';
import '../features/orders/presentation/customer_price_confirmation_dialog.dart';
import '../features/technician/presentation/technician_main_screen.dart';
import '../features/profile/presentation/customer_wallet_screen.dart';
import '../features/jobs/presentation/searching_for_technician_screen.dart';
import '../features/jobs/presentation/customer_active_job_screen.dart';
import '../features/jobs/presentation/rating_screen.dart';
import '../features/technician/presentation/jobs/technician_job_detail_screen.dart';
// New job flow screens
import '../features/jobs/presentation/screens/customer_screens.dart';
import '../features/jobs/presentation/screens/technician_screens.dart';
import 'package:flutter/material.dart';

part 'router.g.dart';

@riverpod
GoRouter goRouter(GoRouterRef ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoggingIn = state.uri.path == '/login';
      final isWelcome = state.uri.path == '/welcome';
      final isRegistering = state.uri.path == '/register';
      final isRecoveringPassword = state.uri.path == '/forgot-password';
      final isTechnicianAuth = state.uri.path.startsWith('/technician');

      if (!isLoggedIn &&
          !isLoggingIn &&
          !isWelcome &&
          !isRegistering &&
          !isRecoveringPassword &&
          !isTechnicianAuth) {
        return '/welcome';
      }
      // Redirect technicians to their home if they try to access customer home
      if (isLoggedIn && state.uri.path == '/') {
        final userType = ref.read(authRepositoryProvider).userType;
        if (userType == 'technician') {
          return '/technician/home';
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
          return '/technician/home';
        }
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/technician/landing',
        builder: (context, state) => const TechnicianLandingScreen(),
      ),
      GoRoute(
        path: '/technician/login',
        builder: (context, state) => const TechnicianLoginScreen(),
      ),
      GoRoute(
        path: '/technician/register',
        builder: (context, state) => const TechnicianRegisterScreen(),
      ),
      GoRoute(
        path: '/technician/home',
        builder: (context, state) => const TechnicianMainScreen(),
      ),
      GoRoute(
        path: '/technician/job/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianJobDetailScreen(jobId: jobId);
        },
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScreen(),
        routes: [
          GoRoute(
            path: 'booking/:serviceId',
            builder: (context, state) {
              final serviceId = state.pathParameters['serviceId']!;
              return BookingScreen(serviceId: serviceId);
            },
          ),
          GoRoute(
            path: 'service-details',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return ServiceDetailsScreen(
                serviceId: extra['serviceId'],
                serviceName: extra['serviceName'],
              );
            },
          ),
          GoRoute(
            path: 'messages',
            builder: (context, state) => const MessagesScreen(),
          ),
          GoRoute(
            path: 'tracking/:bookingId',
            builder: (context, state) {
              final bookingId = state.pathParameters['bookingId']!;
              return TrackingScreen(bookingId: bookingId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/technician-price-input',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return TechnicianPriceInputScreen(
            orderId: extra['orderId'],
            serviceName: extra['serviceName'],
          );
        },
      ),
      GoRoute(
        path: '/customer-confirmation',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CustomTransitionPage(
            key: state.pageKey,
            child: CustomerPriceConfirmationDialog(
              price: extra['price'],
              technicianName: extra['technicianName'],
              serviceName: extra['serviceName'],
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            opaque: false,
            barrierDismissible: false,
            barrierColor: Colors.black.withValues(alpha: 0.5),
          );
        },
      ),
      GoRoute(
        path: '/searching-for-technician',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SearchingForTechnicianScreen(
            jobId: extra?['jobId'] ?? '',
            serviceName: extra?['serviceName'] ?? '',
            lat: extra?['lat'] as double?,
            lng: extra?['lng'] as double?,
          );
        },
      ),
      GoRoute(
        path: '/active-job/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerActiveJobScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/rate-job/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return RatingScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/customer-wallet',
        builder: (context, state) => const CustomerWalletScreen(),
      ),

      // ===== NEW JOB FLOW ROUTES =====

      // Customer Job Flow Routes
      GoRoute(
        path: '/jobs/:jobId/customer/searching',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerSearchingScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/customer/technician-found',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerTechnicianFoundScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/customer/price-offer',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerPriceOfferScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/customer/in-progress',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerInProgressScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/customer/rate',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerRateScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/customer/completed',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerCompletedScreen(jobId: jobId);
        },
      ),

      // Technician Job Flow Routes
      GoRoute(
        path: '/jobs/:jobId/technician/accepted',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianAcceptedScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/technician/set-price',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianSetPriceScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/technician/waiting',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianWaitingScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/technician/in-progress',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianInProgressScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/technician/completed',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianCompletedScreen(jobId: jobId);
        },
      ),
    ],
  );
}
