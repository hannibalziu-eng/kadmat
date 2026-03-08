import 'package:go_router/go_router.dart';

// Auth Features
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/technician_landing_screen.dart';
import '../../features/auth/presentation/technician_login_screen.dart';
import '../../features/auth/presentation/technician_register_screen.dart';

// Home & Core Features
import '../../features/main/main_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/messages/presentation/chat_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/customer_wallet_screen.dart';
import '../../features/profile/presentation/customer_wallet_transactions_screen.dart';

// Technician Features
import '../../features/technician/presentation/technician_main_screen.dart';
import '../../features/technician/presentation/jobs/technician_job_detail_screen.dart';
import '../../features/technician/presentation/technician_public_profile_screen.dart';
import '../../features/technician/presentation/screens/technician_settings_screen.dart';
import '../../features/technician/presentation/screens/technician_help_screen.dart';

// Job & Order Features
import '../../features/jobs/presentation/screens/customer_job_tracking_screen.dart';
import '../../features/jobs/presentation/screens/customer_payment_processing_screen.dart';
import '../../features/jobs/presentation/payment/customer_payment_approval_screen.dart';
import '../../features/jobs/presentation/screens/customer_screens.dart';
import '../../features/jobs/presentation/screens/technician_screens.dart';
import '../../features/jobs/presentation/screens/customer_service_request_screen.dart';
import '../../features/jobs/presentation/screens/technician_complete_work_screen.dart';
import '../../features/jobs/presentation/screens/customer_service_completion_confirmation_screen.dart';
import '../../features/bidding/presentation/screens/technician_bidding_screen.dart';
import '../../features/bidding/presentation/screens/waitlist_offer_screen.dart';

// Payment & Photos
import '../../features/jobs/presentation/photos/pre_service_photo_screen.dart';
import '../../features/jobs/presentation/photos/post_service_photo_screen.dart';
import '../../features/jobs/presentation/payment/price_confirmation_screen.dart';
import '../../features/orders/presentation/technician_price_input_screen.dart';

// Admin Features
import '../../admin/presentation/screens/admin_dashboard_screen.dart';
import '../navigation/app_routes.dart';

/// Modular route definitions for better organization and maintainability
class RouteModules {
  static List<GoRoute> buildAppRoutes() {
    final routes = <GoRoute>[
      ...getMainRoutes(),
      ...getAuthRoutes(),
      ...getTechnicianRoutes(),
      ...getJobFlowRoutes(),
      ...getAdminRoutes(),
      ...getUtilityRoutes(),
    ];

    _assertUniqueAbsolutePaths(routes);
    return routes;
  }

  // Get all route definitions organized by feature
  static List<GoRoute> getAuthRoutes() {
    return [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
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
    ];
  }

  static List<GoRoute> getMainRoutes() {
    return [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MainScreen(),
        routes: [
          GoRoute(
            path: 'booking/:serviceId',
            builder: (context, state) {
              final serviceId = state.pathParameters['serviceId']!;
              return CustomerServiceRequestScreen(initialServiceId: serviceId);
            },
          ),
          GoRoute(
            path: 'service-details',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? const {};
              return CustomerServiceRequestScreen(
                initialServiceId: extra['serviceId']?.toString(),
              );
            },
          ),
          GoRoute(
            path: 'messages',
            builder: (context, state) => const MessagesScreen(),
          ),
          GoRoute(
            path: 'tracking/:bookingId',
            redirect: (context, state) {
              final bookingId = state.pathParameters['bookingId']!;
              return AppRoutes.buildCustomerInProgressPath(bookingId);
            },
          ),
          GoRoute(
            path: AppRoutes.asChild(AppRoutes.customerWallet),
            builder: (context, state) => const CustomerWalletScreen(),
          ),
          GoRoute(
            path: AppRoutes.asChild(AppRoutes.customerWalletTransactions),
            builder: (context, state) =>
                const CustomerWalletTransactionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.asChild(AppRoutes.notifications),
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ];
  }

  static List<GoRoute> getTechnicianRoutes() {
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
          return TechnicianPublicProfileScreen(technicianId: technicianId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianSettings,
        builder: (context, state) => const TechnicianSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.technicianHelp,
        builder: (context, state) => const TechnicianHelpScreen(),
      ),
    ];
  }

  static List<GoRoute> getJobFlowRoutes() {
    return [
      // Customer Job Flow
      GoRoute(
        path: AppRoutes.activeJob,
        // Legacy alias: keep deep links working but route to canonical flow entry.
        redirect: (context, state) {
          final jobId = state.pathParameters['jobId'];
          if (jobId == null || jobId.isEmpty) return AppRoutes.home;
          return AppRoutes.buildCustomerSearchingPath(jobId);
        },
      ),
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
        path: AppRoutes.customerPaymentApproval,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerPaymentApprovalScreen(jobId: jobId);
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
      // Technician Job Flow
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
      GoRoute(
        path: AppRoutes.technicianPriceConfirmation,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return PriceConfirmationScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianCompleteWorkInput,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianCompleteWorkScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.technicianBidding,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianBiddingScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.waitlistOffer,
        builder: (context, state) {
          final waitlistId = state.pathParameters['waitlistId']!;
          return WaitlistOfferScreen(waitlistId: waitlistId);
        },
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return ChatScreen(
            jobId: jobId,
            otherUserName: extra['otherUserName']?.toString(),
            otherUserImage: extra['otherUserImage']?.toString(),
            otherUserPhone: extra['otherUserPhone']?.toString(),
          );
        },
      ),
    ];
  }

  static List<GoRoute> getAdminRoutes() {
    return [
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ];
  }

  static List<GoRoute> getUtilityRoutes() {
    return [
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
        path: AppRoutes.searchingForTechnician,
        // Legacy route fallback: redirect to canonical searching screen when possible.
        redirect: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final jobId = extra?['jobId']?.toString();
          if (jobId != null && jobId.isNotEmpty) {
            return AppRoutes.buildCustomerSearchingPath(jobId);
          }
          return AppRoutes.home;
        },
      ),
      GoRoute(
        path: AppRoutes.customerCreateRequest,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return CustomerServiceRequestScreen(
            initialServiceId: extra['serviceId']?.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.rateJob,
        redirect: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return AppRoutes.buildCustomerRatePath(jobId);
        },
      ),
    ];
  }

  static void _assertUniqueAbsolutePaths(List<GoRoute> routes) {
    assert(() {
      final seen = <String>{};
      final duplicates = <String>{};

      void walk(List<RouteBase> nodes, String parentPath) {
        for (final node in nodes) {
          if (node is! GoRoute) continue;

          final absolutePath = _resolveAbsolutePath(parentPath, node.path);
          if (!seen.add(absolutePath)) {
            duplicates.add(absolutePath);
          }

          if (node.routes.isNotEmpty) {
            walk(node.routes, absolutePath);
          }
        }
      }

      walk(routes, '');

      if (duplicates.isNotEmpty) {
        throw StateError(
          'Duplicate GoRoute paths detected: ${duplicates.join(', ')}',
        );
      }

      return true;
    }());
  }

  static String _resolveAbsolutePath(String parentPath, String currentPath) {
    if (currentPath.startsWith('/')) {
      return _normalizePath(currentPath);
    }

    if (parentPath.isEmpty || parentPath == '/') {
      return _normalizePath('/$currentPath');
    }

    return _normalizePath('$parentPath/$currentPath');
  }

  static String _normalizePath(String path) {
    final normalized = path.replaceAll(RegExp(r'/+'), '/');
    if (normalized.length > 1 && normalized.endsWith('/')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
