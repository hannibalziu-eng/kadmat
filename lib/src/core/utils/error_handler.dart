import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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
        return _handleStatusCode(error.response?.statusCode, error);
      case DioExceptionType.cancel:
        return ErrorMessages.operationCancelled;
      default:
        return ErrorMessages.requestFailed;
    }
  }

  /// Handle HTTP status codes
  static String _handleStatusCode(int? statusCode, DioException error) {
    // Try to extract message from response body
    if (error.response?.data is Map) {
      final data = error.response!.data as Map;
      if (data['error'] is Map && data['error']['message'] != null) {
        return data['error']['message'];
      }
      if (data['message'] != null) {
        return data['message'];
      }
    }

    // Fallback to status code-based messages
    switch (statusCode) {
      case 400:
        return ErrorMessages.requestFailed;
      case 401:
        return ErrorMessages.unauthorized;
      case 403:
        return ErrorMessages.unauthorized;
      case 404:
        return ErrorMessages.jobNotFound;
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
    debugPrint('❌ ErrorHandler: $error');
    if (stackTrace != null) {
      debugPrint(
        '📍 StackTrace: ${stackTrace.toString().split('\n').take(5).join('\n')}',
      );
    }

    // TODO: Add analytics/crash reporting here (e.g., Firebase Crashlytics)
    // Crashlytics.instance.recordError(error, stackTrace);
  }
}
