import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/network/rate_limiter.dart';

void main() {
  group('RateLimiter Integration - Real World Scenarios', () {
    late RateLimiter rateLimiter;

    setUp(() {
      rateLimiter = RateLimiter();
    });

    tearDown(() {
      rateLimiter.reset();
    });

    test('technician bidding flow - 5 bids per hour', () {
      // Scenario: Technician tries to bid on multiple jobs

      const technicianId = 'tech_123';
      final bids = ['job_1', 'job_2', 'job_3', 'job_4', 'job_5', 'job_6'];

      int successfulBids = 0;
      int blockedBids = 0;

      for (final jobId in bids) {
        // Simplified - in real app, key would be just technicianId
        expect(jobId, isNotEmpty);

        if (rateLimiter.canProceed('bid_submit_$technicianId')) {
          successfulBids++;
        } else {
          blockedBids++;
        }
      }

      expect(successfulBids, 5);
      expect(blockedBids, 1);

      // Check status
      final status = rateLimiter.getStatus('bid_submit_$technicianId');
      expect(status.isLimited, true);
      expect(status.message, contains('انتظر'));
    });

    test('customer accepting bids - 10 accepts per 5 minutes', () {
      // Scenario: Customer rapidly accepts and cancels

      const customerId = 'cust_456';

      // Should allow 10 accepts
      for (int i = 0; i < 10; i++) {
        expect(
          rateLimiter.canProceed('bid_accept_$customerId'),
          true,
          reason: 'Accept $i should be allowed',
        );
      }

      // 11th should be blocked
      expect(rateLimiter.canProceed('bid_accept_$customerId'), false);
    });

    test('job creation limit - 3 jobs per hour', () {
      // Scenario: Customer creates multiple jobs

      const customerId = 'cust_789';

      expect(rateLimiter.canProceed('job_create_$customerId'), true);
      expect(rateLimiter.canProceed('job_create_$customerId'), true);
      expect(rateLimiter.canProceed('job_create_$customerId'), true);
      expect(rateLimiter.canProceed('job_create_$customerId'), false);

      expect(rateLimiter.remainingRequests('job_create_$customerId'), 0);
    });

    test('mixed operations - different limits for different actions', () {
      const userId = 'user_001';

      // Fill up bid_submit (5)
      for (int i = 0; i < 5; i++) {
        rateLimiter.canProceed('bid_submit_$userId');
      }

      // Fill up job_create (3)
      for (int i = 0; i < 3; i++) {
        rateLimiter.canProceed('job_create_$userId');
      }

      // bid_submit should be blocked
      expect(rateLimiter.canProceed('bid_submit_$userId'), false);

      // job_create should be blocked
      expect(rateLimiter.canProceed('job_create_$userId'), false);

      // bid_accept should still work (different counter)
      expect(rateLimiter.canProceed('bid_accept_$userId'), true);
    });
  });
}
