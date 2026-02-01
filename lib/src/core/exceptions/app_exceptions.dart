/// Custom exceptions for better error handling in the application
/// These exceptions provide specific error types for different scenarios
library;

/// Exception thrown when a job has already been accepted by another technician
class JobAlreadyAcceptedException implements Exception {
  final String message;
  JobAlreadyAcceptedException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when job status transition is invalid
class InvalidStatusException implements Exception {
  final String message;
  final String? currentStatus;
  InvalidStatusException(this.message, {this.currentStatus});

  @override
  String toString() => message;
}

/// Exception thrown when technician is locked (has active job)
class TechnicianLockedException implements Exception {
  final String message;
  TechnicianLockedException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when job is not found
class JobNotFoundException implements Exception {
  final String message;
  JobNotFoundException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown for network-related errors
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when a request is queued for offline processing
class OfflineRequestQueuedException implements Exception {
  final String message;
  OfflineRequestQueuedException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when job creation fails
/// Provides detailed error information for debugging
class JobCreationException implements Exception {
  final String message;
  final int statusCode;
  final String errorCode;
  final dynamic responseData;
  final dynamic originalException;

  JobCreationException({
    required this.message,
    required this.statusCode,
    required this.errorCode,
    this.responseData,
    this.originalException,
  });

  @override
  String toString() =>
      'JobCreationException(code: $errorCode, status: $statusCode, message: $message)';

  /// User-friendly error message for display
  String get userMessage {
    switch (errorCode) {
      case 'VALIDATION_FAILED':
        return 'يرجى التحقق من البيانات المدخلة';
      case 'UNAUTHORIZED':
        return 'يرجى تسجيل الدخول مجدداً';
      case 'DATABASE_ERROR':
        return 'حدث خطأ في الخادم، يرجى المحاولة لاحقاً';
      case 'NETWORK_ERROR':
        return 'تحقق من اتصالك بالإنترنت';
      default:
        return message;
    }
  }
}
