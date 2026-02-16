import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../api/api_error.dart';
import '../widgets/kadmat_toast.dart';
import '../widgets/error_dialog.dart';
import 'error_messages.dart';

/// Unified Error Handler for the entire application
///
/// Usage:
/// ```dart
/// try {
///   await someAsyncOperation();
/// } catch (e, stack) {
///   ErrorHandler.handle(context, e, onRetry: _retry);
/// }
/// ```
class ErrorHandler {
  ErrorHandler._();

  /// Handle error with toast notification
  /// Shows user-friendly message and optionally logs for analytics
  static void handle(
    BuildContext context,
    dynamic error, {
    bool showDialog = false,
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    final message = customMessage ?? getMessage(error);

    // Log error for debugging
    log(error, StackTrace.current);

    if (showDialog) {
      ErrorDialog.show(context, message, onRetry: onRetry);
    } else {
      KadmatToast.showError(context, title: 'خطأ', message: message);
    }
  }

  /// Get user-friendly message from any error type
  static String getMessage(dynamic error) {
    if (error == null) return ErrorMessages.unknownError;

    // Handle DioException specifically
    if (error is DioException) {
      return _handleDioError(error);
    }

    // Handle String errors
    if (error is String) {
      return error;
    }

    // Handle Exception with message
    if (error is Exception) {
      final message = error.toString();
      // Remove "Exception: " prefix if present
      if (message.startsWith('Exception: ')) {
        return message.substring(11);
      }
      return ErrorMessages.fromException(error);
    }

    // Fallback to ErrorMessages helper
    return ErrorMessages.fromException(error);
  }

  /// Handle Dio-specific errors
  static String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ErrorMessages.connectionTimeout;
      case DioExceptionType.connectionError:
        return ErrorMessages.noInternetConnection;
      case DioExceptionType.badResponse:
        return _handleApiResponseError(error);
      case DioExceptionType.cancel:
        return ErrorMessages.operationCancelled;
      default:
        return ErrorMessages.requestFailed;
    }
  }

  /// Handle standardized backend API error contract.
  static String _handleApiResponseError(DioException error) {
    final apiError = ApiError.fromDioException(error);
    if (apiError.code != null || apiError.message.isNotEmpty) {
      return ErrorMessages.fromApiCode(
        apiError.code,
        fallback: apiError.message,
      );
    }

    return _handleStatusCodeFallback(error.response?.statusCode);
  }

  /// HTTP status fallback when body is missing or malformed.
  static String _handleStatusCodeFallback(int? statusCode) {
    switch (statusCode) {
      case 400:
        return ErrorMessages.invalidInput;
      case 401:
        return ErrorMessages.unauthorized;
      case 403:
        return ErrorMessages.forbidden;
      case 404:
        return ErrorMessages.jobNotFound;
      case 409:
        return ErrorMessages.requestFailed;
      case 429:
        return ErrorMessages.rateLimited;
      case 500:
      case 502:
      case 503:
        return ErrorMessages.serverError;
      default:
        return ErrorMessages.unknownError;
    }
  }

  /// Log error for debugging and future analytics
  static void log(dynamic error, StackTrace? stackTrace) {
    if (error is DioException) {
      final apiError = ApiError.fromDioException(error);
      if (apiError.requestId != null) {
        debugPrint(
          '📌 API requestId=${apiError.requestId} code=${apiError.code ?? 'UNKNOWN'} status=${apiError.statusCode ?? 'n/a'}',
        );
      }
    }

    debugPrint('❌ ErrorHandler: $error');
    if (stackTrace != null) {
      debugPrint(
        '📍 StackTrace: ${stackTrace.toString().split('\n').take(5).join('\n')}',
      );
    }

    // Record to Firebase Crashlytics
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: false,
        reason: 'Caught by ErrorHandler',
      );
    } catch (e) {
      // Crashlytics might not be initialized in some environments (web, tests)
      debugPrint('⚠️ Failed to log to Crashlytics: $e');
    }
  }
}
