import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';

void main() {
  group('AppRoutes Tests', () {
    test('should have consistent route paths', () {
      expect(AppRoutes.home, '/');
      expect(AppRoutes.welcome, '/welcome');
      expect(AppRoutes.login, '/login');
      expect(AppRoutes.register, '/register');
    });

    test('should build customer rate path correctly', () {
      const jobId = 'job123';
      final ratePath = AppRoutes.buildCustomerRatePath(jobId);

      expect(ratePath, '/customer/job/$jobId/rate');
    });

    test('should handle empty job ID in rate path', () {
      const jobId = '';
      final ratePath = AppRoutes.buildCustomerRatePath(jobId);

      expect(ratePath, '/customer/job//rate');
    });

    test('should have technician routes defined', () {
      expect(AppRoutes.technicianHome, '/technician/home');
      expect(AppRoutes.technicianLogin, '/technician/login');
      expect(AppRoutes.technicianRegister, '/technician/register');
    });

    test('should have job flow routes defined', () {
      expect(AppRoutes.activeJob, '/active-job');
      expect(AppRoutes.customerWallet, '/customer/wallet');
      expect(AppRoutes.wallet, '/wallet');
    });
  });
}
