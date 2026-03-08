import 'package:flutter/foundation.dart';

Map<String, dynamic> _toStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

final Set<String> _legacyFallbackKeysLogged = <String>{};

void _logLegacyFallback(String key) {
  if (!kDebugMode) return;
  if (!_legacyFallbackKeysLogged.add(key)) return;
  debugPrint('⚠️ API response fallback used for legacy key: $key');
}

Map<String, dynamic> responseRootMap(dynamic responseData) {
  return _toStringMap(responseData);
}

Map<String, dynamic> responseDataMap(dynamic responseData) {
  final root = responseRootMap(responseData);
  return _toStringMap(root['data']);
}

bool responseSucceeded(dynamic responseData, {bool defaultValue = true}) {
  final root = responseRootMap(responseData);
  final success = root['success'];

  if (success is bool) return success;
  if (success is num) return success != 0;
  if (success is String) {
    final normalized = success.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'ok') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'error') {
      return false;
    }
  }

  return defaultValue;
}

Map<String, dynamic> responsePayloadMap(
  dynamic responseData, {
  String? fallbackKey,
}) {
  final root = responseRootMap(responseData);
  final data = _toStringMap(root['data']);
  if (data.isNotEmpty) return data;

  if (fallbackKey != null) {
    final keyed = _toStringMap(root[fallbackKey]);
    if (keyed.isNotEmpty) {
      _logLegacyFallback(fallbackKey);
      return keyed;
    }
  }

  // Legacy unwrapped payloads (no success/data envelope)
  final wrappedKeys = {'success', 'data', 'error', 'message', 'meta'};
  if (root.keys.any(wrappedKeys.contains)) {
    return const <String, dynamic>{};
  }

  return root;
}

List<dynamic> responsePayloadList(dynamic responseData, {String? fallbackKey}) {
  final root = responseRootMap(responseData);
  final data = root['data'];
  if (data is List) return data;

  if (fallbackKey != null) {
    final value = root[fallbackKey];
    if (value is List) {
      _logLegacyFallback(fallbackKey);
      return value;
    }
  }

  return const <dynamic>[];
}

dynamic responseField(dynamic responseData, String key) {
  final data = responseDataMap(responseData);
  if (data.containsKey(key)) return data[key];
  final root = responseRootMap(responseData);
  if (root.containsKey(key)) {
    _logLegacyFallback(key);
    return root[key];
  }
  return null;
}

Map<String, dynamic> responseObjectField(dynamic responseData, String key) {
  return _toStringMap(responseField(responseData, key));
}

List<dynamic> responseListField(dynamic responseData, String key) {
  final value = responseField(responseData, key);
  if (value is List) return value;
  return const <dynamic>[];
}
