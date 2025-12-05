import 'package:flutter/material.dart';

/// Reusable Error Dialog Widget
/// Shows user-friendly error messages with optional retry action
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String? technicalDetails;

  const ErrorDialog({
    Key? key,
    this.title = 'خطأ',
    required this.message,
    this.onRetry,
    this.technicalDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontSize: 16)),
          if (technicalDetails != null) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('التفاصيل التقنية'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SelectableText(
                    technicalDetails!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        if (onRetry != null)
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('حسناً'),
        ),
      ],
    );
  }

  /// Show error dialog from DioException
  static void showFromDioError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    String message = 'حدث خطأ غير متوقع';
    String? technicalDetails;

    if (error.response?.data is Map) {
      final data = error.response!.data as Map;

      // Check for our API error format
      if (data['error'] != null && data['error']['message'] != null) {
        message = data['error']['message'];

        // Technical details in development
        if (data['error']['technical'] != null) {
          technicalDetails = data['error']['technical'].toString();
        }
      } else if (data['message'] != null) {
        message = data['message'];
      }
    } else if (error.message != null) {
      message = error.message;
    }

    showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        message: message,
        onRetry: onRetry,
        technicalDetails: technicalDetails,
      ),
    );
  }

  /// Show simple error dialog
  static void show(
    BuildContext context,
    String message, {
    String? title,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        title: title ?? 'خطأ',
        message: message,
        onRetry: onRetry,
      ),
    );
  }
}
