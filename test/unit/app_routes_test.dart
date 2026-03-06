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

      expect(ratePath, '/jobs/$jobId/customer/rate');
    });

    test('should build customer payment paths correctly', () {
      const jobId = 'job123';
      final approvalPath = AppRoutes.buildCustomerPaymentApprovalPath(jobId);
      final processingPath = AppRoutes.buildCustomerPaymentProcessingPath(
        jobId,
      );

      expect(approvalPath, '/jobs/$jobId/customer/payment-approval');
      expect(processingPath, '/jobs/$jobId/customer/payment-processing');
    });

    test('should build active job path correctly', () {
      const jobId = 'job123';
      final activePath = AppRoutes.buildActiveJobPath(jobId);

      expect(activePath, '/active-job/$jobId');
    });

    test('should handle empty job ID in rate path', () {
      const jobId = '';
      final ratePath = AppRoutes.buildCustomerRatePath(jobId);

      expect(ratePath, '/jobs//customer/rate');
    });

    test('should build technician detail path correctly', () {
      const jobId = 'job123';
      final detailPath = AppRoutes.buildTechnicianJobDetailPath(jobId);

      expect(detailPath, '/jobs/$jobId/technician/detail');
    });

    test('should build technician bidding path correctly', () {
      const jobId = 'job123';
      final biddingPath = AppRoutes.buildTechnicianBiddingPath(jobId);

      expect(biddingPath, '/jobs/$jobId/technician/bidding');
    });

    test('should convert absolute path to child route path', () {
      expect(AppRoutes.asChild('/wallet'), 'wallet');
      expect(AppRoutes.asChild('messages'), 'messages');
    });

    test('should build technician profile path with encoded id', () {
      const technicianId = 'user id/123';
      final path = AppRoutes.buildTechnicianProfilePath(technicianId);

      expect(path, '/technician-profile/user%20id%2F123');
    });

    test('should fallback to home for empty technician profile id', () {
      final path = AppRoutes.buildTechnicianProfilePath('   ');

      expect(path, AppRoutes.home);
    });

    test('should have technician routes defined', () {
      expect(AppRoutes.technicianHome, '/technician/home');
      expect(AppRoutes.technicianLogin, '/technician/login');
      expect(AppRoutes.technicianRegister, '/technician/register');
    });

    test('should have job flow routes defined', () {
      expect(AppRoutes.activeJob, '/active-job/:jobId');
      expect(AppRoutes.customerWallet, '/customer-wallet');
      expect(AppRoutes.wallet, '/wallet');
    });
  });
}
