/// Configuration for rate limiting
class RateLimitConfig {
  final int maxRequests;
  final Duration window;

  const RateLimitConfig({required this.maxRequests, required this.window});

  @override
  String toString() =>
      'RateLimitConfig(max: $maxRequests, window: ${window.inMinutes}m)';
}

/// Rate limiter for API calls
///
/// Usage:
/// ```dart
/// if (!rateLimiter.canProceed('bid_submit_$userId')) {
///   final wait = rateLimiter.timeUntilAllowed('bid_submit_$userId');
///   throw RateLimitException('Try again in ${wait?.inMinutes} minutes');
/// }
/// ```
class RateLimiter {
  final Map<String, List<DateTime>> _requests = {};

  /// Default configurations for different action types
  final Map<String, RateLimitConfig> _configs = {
    'bid_submit': const RateLimitConfig(
      maxRequests: 5,
      window: Duration(hours: 1),
    ),
    'bid_accept': const RateLimitConfig(
      maxRequests: 10,
      window: Duration(minutes: 5),
    ),
    'job_create': const RateLimitConfig(
      maxRequests: 3,
      window: Duration(hours: 1),
    ),
    'waitlist_accept': const RateLimitConfig(
      maxRequests: 3,
      window: Duration(minutes: 5),
    ),
  };

  /// Check if action can proceed
  ///
  /// Automatically records the request if allowed
  bool canProceed(String key) {
    final config = _getConfig(key);
    if (config == null) {
      // No limit configured, allow freely
      return true;
    }

    final now = DateTime.now();
    final windowStart = now.subtract(config.window);

    // Clean old requests and keep only those within window
    _requests[key] = (_requests[key] ?? [])
        .where((timestamp) => timestamp.isAfter(windowStart))
        .toList();

    // Check if under limit
    if (_requests[key]!.length >= config.maxRequests) {
      return false;
    }

    // Record this request
    _requests[key]!.add(now);
    return true;
  }

  /// Check without recording (for UI display)
  bool peek(String key) {
    final config = _getConfig(key);
    if (config == null) return true;

    final now = DateTime.now();
    final windowStart = now.subtract(config.window);

    final recentRequests = (_requests[key] ?? [])
        .where((timestamp) => timestamp.isAfter(windowStart))
        .length;

    return recentRequests < config.maxRequests;
  }

  /// Get time until next allowed request
  ///
  /// Returns null if not limited or no config found
  Duration? timeUntilAllowed(String key) {
    final config = _getConfig(key);
    if (config == null) return null;

    final requests = _requests[key] ?? [];
    if (requests.length < config.maxRequests) {
      return null; // Not limited
    }

    // Find oldest request and calculate when window expires
    final oldest = requests.first;
    final resetTime = oldest.add(config.window);
    final remaining = resetTime.difference(DateTime.now());

    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get current status for display
  RateLimitStatus getStatus(String key) {
    final config = _getConfig(key);
    if (config == null) {
      return RateLimitStatus.unlimited(key: key);
    }

    final requests = _requests[key] ?? [];
    final now = DateTime.now();
    final windowStart = now.subtract(config.window);
    final recentRequests = requests.where((t) => t.isAfter(windowStart)).length;

    return RateLimitStatus(
      key: key,
      isLimited: recentRequests >= config.maxRequests,
      remainingRequests: config.maxRequests - recentRequests,
      totalRequests: config.maxRequests,
      resetIn: timeUntilAllowed(key),
      windowDuration: config.window,
    );
  }

  /// Get remaining requests count
  int remainingRequests(String key) {
    final config = _getConfig(key);
    if (config == null) return -1; // Unlimited

    final now = DateTime.now();
    final windowStart = now.subtract(config.window);
    final recentRequests = (_requests[key] ?? [])
        .where((t) => t.isAfter(windowStart))
        .length;

    return (config.maxRequests - recentRequests).clamp(0, config.maxRequests);
  }

  /// Reset all limits (for testing or logout)
  void reset() {
    _requests.clear();
  }

  /// Reset specific key
  void resetKey(String key) {
    _requests.remove(key);
  }

  /// Add custom config (for dynamic limits)
  void setConfig(String key, RateLimitConfig config) {
    _configs[key] = config;
  }

  /// Get config for key (supports prefix match)
  RateLimitConfig? getConfig(String key) => _getConfig(key);

  RateLimitConfig? _getConfig(String key) {
    if (_configs.containsKey(key)) return _configs[key];

    // Find longest matching prefix
    String? bestMatch;
    for (final configKey in _configs.keys) {
      if (key.startsWith(configKey)) {
        if (bestMatch == null || configKey.length > bestMatch.length) {
          bestMatch = configKey;
        }
      }
    }
    return bestMatch != null ? _configs[bestMatch] : null;
  }
}

/// Status object for UI display
class RateLimitStatus {
  final String? key;
  final bool isLimited;
  final int remainingRequests;
  final int totalRequests;
  final Duration? resetIn;
  final Duration? windowDuration;

  const RateLimitStatus({
    this.key,
    required this.isLimited,
    required this.remainingRequests,
    required this.totalRequests,
    this.resetIn,
    this.windowDuration,
  });

  const RateLimitStatus.unlimited({this.key})
    : isLimited = false,
      remainingRequests = -1,
      totalRequests = -1,
      resetIn = null,
      windowDuration = null;

  /// Human readable message in Arabic
  String get message {
    if (!isLimited) {
      if (remainingRequests == -1) return 'غير محدود';
      return 'متبقي $remainingRequests من $totalRequests';
    }

    if (resetIn == null) return 'تم تجاوز الحد';

    final minutes = resetIn!.inMinutes;
    if (minutes > 0) {
      return 'انتظر $minutes دقيقة';
    }
    final seconds = resetIn!.inSeconds;
    return 'انتظر $seconds ثانية';
  }

  @override
  String toString() =>
      'RateLimitStatus(key: $key, limited: $isLimited, remaining: $remainingRequests/$totalRequests)';
}

/// Exception for rate limit violations
class RateLimitException implements Exception {
  final String message;
  final Duration? retryAfter;
  final String? key;

  const RateLimitException(this.message, {this.retryAfter, this.key});

  @override
  String toString() => 'RateLimitException: $message';
}
