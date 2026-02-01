import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/technician_landing_screen.dart';
import '../../features/auth/presentation/technician_login_screen.dart';
import '../../features/auth/presentation/technician_register_screen.dart';
import '../navigation/app_routes.dart';

List<GoRoute> getAuthRoutes() {
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
