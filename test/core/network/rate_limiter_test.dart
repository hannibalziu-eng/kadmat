import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/network/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    late RateLimiter rateLimiter;

    setUp(() {
      rateLimiter = RateLimiter();
    });

    tearDown(() {
      rateLimiter.reset();
    });

    group('Basic Functionality', () {
      test('should allow request when under limit', () {
        // Act & Assert
        expect(rateLimiter.canProceed('bid_submit'), true);
      });

      test('should allow exactly maxRequests requests', () {
        // Arrange
        const maxRequests = 5;

        // Act - Make exactly maxRequests
        for (int i = 0; i < maxRequests; i++) {
          expect(
            rateLimiter.canProceed('bid_submit'),
            true,
            reason: 'Request ${i + 1} should be allowed',
          );
        }
      });

      test('should block request when over limit', () {
        // Arrange - Make maxRequests
        for (int i = 0; i < 5; i++) {
          rateLimiter.canProceed('bid_submit');
        }

        // Act & Assert
        expect(rateLimiter.canProceed('bid_submit'), false);
      });

      test('should track different keys independently', () {
        // Arrange - Config for test keys
        rateLimiter.setConfig(
          'key',
          const RateLimitConfig(maxRequests: 5, window: Duration(minutes: 1)),
        );

        // Fill up key1
        for (int i = 0; i < 5; i++) {
          rateLimiter.canProceed('key1');
        }

        // Assert
        expect(rateLimiter.canProceed('key1'), false); // key1 blocked
        expect(rateLimiter.canProceed('key2'), true); // key2 allowed
        expect(rateLimiter.canProceed('key3'), true); // key3 allowed
      });
    });

    group('Time Window', () {
      test('should return time until allowed when limited', () async {
        // Arrange - Fill up limit
        for (int i = 0; i < 5; i++) {
          rateLimiter.canProceed('bid_submit');
        }

        // Act
        final waitTime = rateLimiter.timeUntilAllowed('bid_submit');

        // Assert
        expect(waitTime, isNotNull);
        expect(waitTime!.inMinutes, greaterThan(0));
        expect(waitTime.inMinutes, lessThanOrEqualTo(60));
      });

      test('should return null when not limited', () {
        // Act
        final waitTime = rateLimiter.timeUntilAllowed('bid_submit');

        // Assert
        expect(waitTime, isNull);
      });

      test('should reset after window expires', () async {
        // Arrange - Create custom short window for testing
        rateLimiter.setConfig(
          'test_key',
          const RateLimitConfig(
            maxRequests: 2,
            window: Duration(milliseconds: 100),
          ),
        );

        // Fill up
        rateLimiter.canProceed('test_key');
        rateLimiter.canProceed('test_key');
        expect(rateLimiter.canProceed('test_key'), false);

        // Wait for window to expire
        await Future.delayed(const Duration(milliseconds: 150));

        // Assert - Should be allowed again
        expect(rateLimiter.canProceed('test_key'), true);
      });
    });

    group('Peek Functionality', () {
      test('peek should not record request', () {
        // Arrange
        rateLimiter.setConfig(
          'peek_test',
          const RateLimitConfig(maxRequests: 2, window: Duration(hours: 1)),
        );

        // Act - Peek multiple times
        rateLimiter.peek('peek_test');
        rateLimiter.peek('peek_test');
        rateLimiter.peek('peek_test');

        // Assert - Should still allow 2 real requests
        expect(rateLimiter.canProceed('peek_test'), true);
        expect(rateLimiter.canProceed('peek_test'), true);
        expect(rateLimiter.canProceed('peek_test'), false);
      });

      test('peek should return same result as canProceed for status', () {
        // Act & Assert
        expect(
          rateLimiter.peek('bid_submit'),
          rateLimiter.canProceed('bid_submit'),
        );
      });
    });

    group('Status Information', () {
      test('should return correct status when unlimited', () {
        // Act
        final status = rateLimiter.getStatus('unknown_key');

        // Assert
        expect(status.isLimited, false);
        expect(status.remainingRequests, -1);
      });

      test('should return correct status when limited', () {
        // Arrange
        for (int i = 0; i < 5; i++) {
          rateLimiter.canProceed('bid_submit');
        }

        // Act
        final status = rateLimiter.getStatus('bid_submit');

        // Assert
        expect(status.isLimited, true);
        expect(status.remainingRequests, 0);
        expect(status.totalRequests, 5);
        expect(status.resetIn, isNotNull);
      });

      test('should return correct remaining count', () {
        // Arrange
        rateLimiter.canProceed('bid_submit'); // 1 used
        rateLimiter.canProceed('bid_submit'); // 2 used

        // Act & Assert
        expect(rateLimiter.remainingRequests('bid_submit'), 3);
      });
    });

    group('Configuration', () {
      test('should use custom config when set', () {
        // Arrange
        rateLimiter.setConfig(
          'custom',
          const RateLimitConfig(maxRequests: 3, window: Duration(minutes: 10)),
        );

        // Act & Assert
        expect(rateLimiter.canProceed('custom'), true);
        expect(rateLimiter.canProceed('custom'), true);
        expect(rateLimiter.canProceed('custom'), true);
        expect(rateLimiter.canProceed('custom'), false); // 4th blocked
      });

      test('should return null for unknown config', () {
        expect(rateLimiter.getConfig('unknown'), isNull);
      });

      test('should return config for known key', () {
        final config = rateLimiter.getConfig('bid_submit');
        expect(config, isNotNull);
        expect(config!.maxRequests, 5);
      });
    });

    group('Reset Functionality', () {
      test('reset should clear all limits', () {
        // Arrange
        for (int i = 0; i < 5; i++) {
          rateLimiter.canProceed('bid_submit');
        }
        expect(rateLimiter.canProceed('bid_submit'), false);

        // Act
        rateLimiter.reset();

        // Assert
        expect(rateLimiter.canProceed('bid_submit'), true);
      });

      test('resetKey should clear only specific key', () {
        // Arrange
        rateLimiter.setConfig(
          'key',
          const RateLimitConfig(maxRequests: 5, window: Duration(minutes: 1)),
        );

        for (int i = 0; i < 5; i++) {
          rateLimiter.canProceed('key1');
          rateLimiter.canProceed('key2');
        }

        // Act
        rateLimiter.resetKey('key1');

        // Assert
        expect(rateLimiter.canProceed('key1'), true); // Reset
        expect(rateLimiter.canProceed('key2'), false); // Still blocked
      });
    });

    group('Arabic Messages', () {
      test('should return Arabic message when limited', () {
        // Arrange
        for (int i = 0; i < 5; i++) {
          rateLimiter.canProceed('bid_submit');
        }
        final status = rateLimiter.getStatus('bid_submit');

        // Act
        final message = status.message;

        // Assert
        expect(message, contains('انتظر'));
        expect(message, contains('دقيقة'));
      });

      test('should return Arabic message when not limited', () {
        // Arrange
        final status = rateLimiter.getStatus('bid_submit');

        // Act
        final message = status.message;

        // Assert
        expect(message, contains('متبقي'));
      });
    });

    group('Edge Cases', () {
      test('should handle rapid successive calls', () {
        // Arrange
        rateLimiter.setConfig(
          'rapid_test',
          const RateLimitConfig(maxRequests: 5, window: Duration(minutes: 1)),
        );

        // Act - 100 rapid calls
        int allowed = 0;
        for (int i = 0; i < 100; i++) {
          if (rateLimiter.canProceed('rapid_test')) {
            allowed++;
          }
        }

        // Assert - Should allow exactly 5
        expect(allowed, 5);
      });

      test('should handle empty key', () {
        expect(rateLimiter.canProceed(''), true);
        expect(rateLimiter.getStatus('').isLimited, false);
      });

      test('should handle very long key', () {
        final longKey = 'a' * 1000;
        expect(rateLimiter.canProceed(longKey), true);
      });
    });
  });

  group('RateLimitStatus', () {
    test('unlimited status has correct values', () {
      const status = RateLimitStatus.unlimited();

      expect(status.isLimited, false);
      expect(status.remainingRequests, -1);
      expect(status.message, 'غير محدود');
    });

    test('toString contains key information', () {
      final limiter = RateLimiter();
      limiter.canProceed('test');
      final status = limiter.getStatus('test');

      expect(status.toString(), contains('test'));
      expect(status.toString(), contains('limited'));
    });
  });

  group('RateLimitException', () {
    test('should store message and retryAfter', () {
      const exception = RateLimitException(
        'Too many requests',
        retryAfter: Duration(minutes: 5),
        key: 'test_key',
      );

      expect(exception.message, 'Too many requests');
      expect(exception.retryAfter?.inMinutes, 5);
      expect(exception.key, 'test_key');
      expect(exception.toString(), contains('Too many requests'));
    });
  });
}
