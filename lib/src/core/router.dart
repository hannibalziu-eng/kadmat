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
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/booking/presentation/booking_screen.dart';
import '../features/booking/presentation/service_details_screen.dart';
import '../features/main/main_screen.dart';
import '../features/messages/presentation/messages_screen.dart';
import '../features/messages/presentation/chat_screen.dart';
import '../features/tracking/presentation/tracking_screen.dart';
import '../features/orders/presentation/technician_price_input_screen.dart';
import '../features/orders/presentation/customer_price_confirmation_dialog.dart';
import '../features/technician/presentation/technician_main_screen.dart';
import '../features/profile/presentation/customer_wallet_screen.dart';
import '../features/jobs/presentation/searching_for_technician_screen.dart';
import '../features/technician/presentation/jobs/technician_job_detail_screen.dart';
import '../features/jobs/presentation/customer_active_job_screen.dart';

import '../features/technician/presentation/technician_profile_screen.dart';
// New job flow screens
import '../features/jobs/presentation/screens/customer_screens.dart';
import '../features/jobs/presentation/screens/technician_screens.dart';
import '../features/jobs/presentation/screens/technician_complete_work_screen.dart';
import '../features/jobs/presentation/screens/customer_payment_processing_screen.dart';
import '../features/jobs/presentation/photos/pre_service_photo_screen.dart';
import '../features/jobs/presentation/photos/post_service_photo_screen.dart';
import '../features/jobs/presentation/payment/price_confirmation_screen.dart';
import '../features/jobs/presentation/payment/customer_payment_approval_screen.dart';
import '../features/jobs/presentation/screens/customer_service_completion_confirmation_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/jobs/presentation/screens/customer_service_request_screen.dart';
import '../features/jobs/presentation/screens/customer_job_tracking_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation/app_routes.dart';

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
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.technicianLanding,
        builder: (context, state) => const TechnicianLandingScreen(),
      ),
      GoRoute(
        path: AppRoutes.technicianLogin,
        builder: (context, state) => const TechnicianLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.technicianRegister,
        builder: (context, state) => const TechnicianRegisterScreen(),
      ),
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
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MainScreen(),
        routes: [
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
          GoRoute(
            path: AppRoutes.messages,
            builder: (context, state) => const MessagesScreen(),
          ),
          GoRoute(
            path: AppRoutes.tracking,
            builder: (context, state) {
              final bookingId = state.pathParameters['bookingId']!;
              return TrackingScreen(bookingId: bookingId);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.technicianPriceInput,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return TechnicianPriceInputScreen(
            orderId: extra['orderId'],
            serviceName: extra['serviceName'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.customerConfirmation,
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
        path: AppRoutes.searchingForTechnician,
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
        path: AppRoutes.activeJob,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerActiveJobScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.rateJob,
        redirect: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return AppRoutes.buildCustomerRatePath(jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.customerWallet,
        builder: (context, state) => const CustomerWalletScreen(),
      ),

      GoRoute(
        path: AppRoutes.customerCreateRequest,
        builder: (context, state) => const CustomerServiceRequestScreen(),
      ),

      // ===== NEW JOB FLOW ROUTES =====

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
          return CustomerJobTrackingScreen(jobId: jobId); // Use Tracking Screen
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
      GoRoute(
        path: AppRoutes.customerConfirmCompletion,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerServiceCompletionConfirmationScreen(jobId: jobId);
        },
      ),

      // Technician Job Flow Routes
      GoRoute(
        path: AppRoutes.technicianAccepted,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianAcceptedScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianJobDetailV2,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianJobDetailScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianSetPrice,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianPriceInputScreen(orderId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianWaiting,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianWaitingScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianInProgress,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianInProgressScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianCompleted,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianCompletedScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianCompleteWorkInput,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianCompleteWorkScreen(jobId: jobId);
        },
      ),

      // Photo Capture Routes
      GoRoute(
        path: AppRoutes.technicianPrePhotos,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return PreServicePhotoScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianPostPhotos,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return PostServicePhotoScreen(jobId: jobId);
        },
      ),

      // Payment Confirmation Routes
      GoRoute(
        path: AppRoutes.technicianPriceConfirmation,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return PriceConfirmationScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.customerPaymentApproval,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerPaymentApprovalScreen(jobId: jobId);
        },
      ),

      // Technician Profile Route
      GoRoute(
        path: AppRoutes.technicianProfile,
        builder: (context, state) {
          final technicianId = state.pathParameters['technicianId']!;
          return TechnicianProfileScreen(technicianId: technicianId);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
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
