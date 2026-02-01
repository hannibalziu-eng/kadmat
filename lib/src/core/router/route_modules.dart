import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

/// Modular route definitions for better organization and maintainability
class RouteModules {
  // Get all route definitions organized by feature
  static List<GoRoute> getAuthRoutes() {
    return [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
    ];
  }

  static List<GoRoute> getMainRoutes() {
    return [
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
          GoRoute(
            path: 'wallet',
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: 'customer-wallet',
            builder: (context, state) => const CustomerWalletScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ];
  }

  static List<GoRoute> getTechnicianRoutes() {
    return [
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
      GoRoute(
        path: '/technician-profile/:technicianId',
        builder: (context, state) {
          final technicianId = state.pathParameters['technicianId']!;
          return TechnicianProfileScreen(technicianId: technicianId);
        },
      ),
    ];
  }

  static List<GoRoute> getJobFlowRoutes() {
    return [
      // Customer Job Flow
      GoRoute(
        path: '/active-job/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerActiveJobScreen(jobId: jobId);
        },
      ),
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
          return CustomerJobTrackingScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/customer/payment-processing',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerPaymentProcessingScreen(jobId: jobId);
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
      GoRoute(
        path: '/jobs/:jobId/customer/confirm-completion',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return CustomerServiceCompletionConfirmationScreen(jobId: jobId);
        },
      ),
      // Technician Job Flow
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
          return TechnicianPriceInputScreen(orderId: jobId);
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
      GoRoute(
        path: '/jobs/:jobId/technician/pre-photos',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return PreServicePhotoScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/technician/post-photos',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return PostServicePhotoScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/technician/price-confirmation',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return PriceConfirmationScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/technician/complete-work-input',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return TechnicianCompleteWorkScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/chat',
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
    ];
  }

  static List<GoRoute> getUtilityRoutes() {
    return [
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
        path: '/customer/create-request',
        builder: (context, state) => const CustomerServiceRequestScreen(),
      ),
      GoRoute(
        path: '/rate-job/:jobId',
        redirect: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return '/jobs/$jobId/customer/rate';
        },
      ),
    ];
  }
}

// Import these screen widgets in your router file
// These are placeholders for type checking
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianLandingScreen extends StatelessWidget {
  const TechnicianLandingScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianLoginScreen extends StatelessWidget {
  const TechnicianLoginScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianRegisterScreen extends StatelessWidget {
  const TechnicianRegisterScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key, required this.serviceId});
  final String serviceId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class ServiceDetailsScreen extends StatelessWidget {
  const ServiceDetailsScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
  });
  final String serviceId, serviceName;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerWalletScreen extends StatelessWidget {
  const CustomerWalletScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianMainScreen extends StatelessWidget {
  const TechnicianMainScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianJobDetailScreen extends StatelessWidget {
  const TechnicianJobDetailScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianProfileScreen extends StatelessWidget {
  const TechnicianProfileScreen({super.key, required this.technicianId});
  final String technicianId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerActiveJobScreen extends StatelessWidget {
  const CustomerActiveJobScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerSearchingScreen extends StatelessWidget {
  const CustomerSearchingScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerTechnicianFoundScreen extends StatelessWidget {
  const CustomerTechnicianFoundScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerPriceOfferScreen extends StatelessWidget {
  const CustomerPriceOfferScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerJobTrackingScreen extends StatelessWidget {
  const CustomerJobTrackingScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerPaymentProcessingScreen extends StatelessWidget {
  const CustomerPaymentProcessingScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerRateScreen extends StatelessWidget {
  const CustomerRateScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerCompletedScreen extends StatelessWidget {
  const CustomerCompletedScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerServiceCompletionConfirmationScreen extends StatelessWidget {
  const CustomerServiceCompletionConfirmationScreen({
    super.key,
    required this.jobId,
  });
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianAcceptedScreen extends StatelessWidget {
  const TechnicianAcceptedScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianPriceInputScreen extends StatelessWidget {
  const TechnicianPriceInputScreen({
    super.key,
    required this.orderId,
    this.serviceName,
  });
  final String orderId;
  final String? serviceName;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianWaitingScreen extends StatelessWidget {
  const TechnicianWaitingScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianInProgressScreen extends StatelessWidget {
  const TechnicianInProgressScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianCompletedScreen extends StatelessWidget {
  const TechnicianCompletedScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class PreServicePhotoScreen extends StatelessWidget {
  const PreServicePhotoScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class PostServicePhotoScreen extends StatelessWidget {
  const PostServicePhotoScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class PriceConfirmationScreen extends StatelessWidget {
  const PriceConfirmationScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class TechnicianCompleteWorkScreen extends StatelessWidget {
  const TechnicianCompleteWorkScreen({super.key, required this.jobId});
  final String jobId;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.jobId,
    required this.otherUserName,
    required this.otherUserImage,
  });
  final String jobId, otherUserName, otherUserImage;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerPriceConfirmationDialog extends StatelessWidget {
  const CustomerPriceConfirmationDialog({
    super.key,
    required this.price,
    required this.technicianName,
    required this.serviceName,
  });
  final dynamic price;
  final String technicianName, serviceName;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class SearchingForTechnicianScreen extends StatelessWidget {
  const SearchingForTechnicianScreen({
    super.key,
    required this.jobId,
    required this.serviceName,
    this.lat,
    this.lng,
  });
  final String jobId, serviceName;
  final double? lat, lng;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class CustomerServiceRequestScreen extends StatelessWidget {
  const CustomerServiceRequestScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}
