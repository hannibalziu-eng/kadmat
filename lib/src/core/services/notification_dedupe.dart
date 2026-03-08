class NotificationDedupeStore {
  NotificationDedupeStore({this.window = const Duration(seconds: 30)});

  final Duration window;
  final Map<String, DateTime> _recentKeys = <String, DateTime>{};

  bool registerIfFresh(Iterable<String> keys, {DateTime? now}) {
    final normalizedKeys = normalizeDedupeKeys(keys);
    if (normalizedKeys.isEmpty) {
      return true;
    }

    final timestamp = now ?? DateTime.now();
    _recentKeys.removeWhere(
      (_, seenAt) => timestamp.difference(seenAt) > window,
    );

    for (final key in normalizedKeys) {
      final lastSeen = _recentKeys[key];
      if (lastSeen != null && timestamp.difference(lastSeen) <= window) {
        return false;
      }
    }

    for (final key in normalizedKeys) {
      _recentKeys[key] = timestamp;
    }
    return true;
  }

  void clear() => _recentKeys.clear();
}

String? _normalizeNullableString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _firstNonEmpty(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = _normalizeNullableString(data[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

Iterable<String> buildPushForegroundDedupeKeys({
  required Map<String, dynamic> data,
  String? title,
  String? body,
  String? navigationPayload,
}) {
  final keys = <String>{};

  void addRaw(Object? value) {
    final normalized = _normalizeNullableString(value);
    if (normalized == null) return;
    keys.add(normalized);
  }

  addRaw(_firstNonEmpty(data, const ['dedupe_key', 'dedupeKey']));
  addRaw(_firstNonEmpty(data, const ['notification_id', 'notificationId']));

  final eventType = _firstNonEmpty(data, const [
    'event_type',
    'eventType',
    'type',
  ]);
  final entityId = _firstNonEmpty(data, const [
    'entity_id',
    'entityId',
    'job_id',
    'jobId',
    'order_id',
  ]);
  if (eventType != null && entityId != null) {
    keys.add('$eventType:$entityId');
  }

  final contentKey = buildNotificationContentDedupeKey(
    title: title,
    body: body,
    payload: navigationPayload,
  );
  if (contentKey.isNotEmpty) {
    keys.add(contentKey);
  }

  return keys;
}

Iterable<String> buildLocalNotificationDedupeKeys({
  required String dedupeKey,
  required String title,
  required String body,
  String? payload,
  String? backendEventType,
  String? userId,
}) {
  final keys = <String>{dedupeKey};

  final contentKey = buildNotificationContentDedupeKey(
    title: title,
    body: body,
    payload: payload,
  );
  if (contentKey.isNotEmpty) {
    keys.add(contentKey);
  }

  final normalizedEventType = _normalizeNullableString(backendEventType);
  final normalizedPayload = _normalizeNullableString(payload);
  if (normalizedEventType != null && normalizedPayload != null) {
    keys.add('$normalizedEventType:$normalizedPayload');
    final normalizedUserId = _normalizeNullableString(userId);
    if (normalizedUserId != null) {
      keys.add('$normalizedEventType:$normalizedPayload:$normalizedUserId');
    }
  }

  return keys;
}

List<String> normalizeDedupeKeys(Iterable<String> keys) {
  final unique = <String>{};
  for (final key in keys) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) continue;
    unique.add(trimmed);
  }
  return unique.toList(growable: false);
}

String buildNotificationContentDedupeKey({
  String? title,
  String? body,
  String? payload,
}) {
  final normalizedTitle = _normalizeForFingerprint(title);
  final normalizedBody = _normalizeForFingerprint(body);
  final normalizedPayload = _normalizeForFingerprint(payload);
  if (normalizedTitle.isEmpty &&
      normalizedBody.isEmpty &&
      normalizedPayload.isEmpty) {
    return '';
  }

  return 'content:$normalizedPayload:$normalizedTitle:$normalizedBody';
}

String _normalizeForFingerprint(String? value) {
  if (value == null) {
    return '';
  }
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
