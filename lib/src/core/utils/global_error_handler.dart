import 'package:flutter/material.dart';
import '../widgets/error_dialog.dart';
import '../widgets/kadmat_toast.dart';
import 'error_messages.dart';

/// Centralized error handler to decide how to display errors to the user.
///
/// Usage:
/// ```dart
/// try {
///   await someAsyncOp();
/// } catch (e) {
///   GlobalErrorHandler.handle(context, e, onRetry: () => retryOp());
/// }
/// ```
class GlobalErrorHandler {
  GlobalErrorHandler._();

  /// Handle an error and display appropriate UI (Toast or Dialog).
  static void handle(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    bool showToastOnly = false,
  }) {
    final message = ErrorMessages.fromException(error);
    final isNetworkError =
        message == ErrorMessages.noInternetConnection ||
        message == ErrorMessages.connectionTimeout;

    // Determine severity
    final isCritical = !showToastOnly && (onRetry != null || !isNetworkError);

    if (isCritical) {
      // Show blocking dialog for critical errors or when retry is offered
      ErrorDialog.show(
        context,
        message,
        onRetry: onRetry,
        title: isNetworkError ? 'خطأ في الاتصال' : 'خطأ',
      );
    } else {
      // Show non-blocking toast for minor errors
      KadmatToast.showError(
        context,
        title: isNetworkError ? 'خطأ في الاتصال' : 'خطأ',
        message: message,
      );
    }
  }
}
