import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Lightweight debug logger for this Cursor debug session.
/// Writes NDJSON lines to the shared debug log file if possible.
class DebugLogger {
  static const String _logPath =
      '/Users/wew/Desktop/kadmat/.cursor/debug.log'; // Host workspace path

  /// Write a single debug event as NDJSON.
  ///
  /// This is best-effort: any IO errors are swallowed to avoid crashing the app.
  static Future<void> log({
    required String location,
    required String message,
    Map<String, dynamic>? data,
    String runId = 'pre-fix',
    String hypothesisId = 'H1',
  }) async {
    // Avoid using dart:io on Web builds.
    if (kIsWeb) return;

    // #region agent log
    final event = <String, dynamic>{
      'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'message': message,
      'data': data ?? <String, dynamic>{},
      'runId': runId,
      'hypothesisId': hypothesisId,
    };

    try {
      final file = File(_logPath);
      await file.writeAsString('${jsonEncode(event)}\n', mode: FileMode.append);
    } catch (_) {
      // Swallow all IO errors – logging must never crash the app.
    }
    // #endregion
  }
}

