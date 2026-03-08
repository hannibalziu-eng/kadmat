import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/services/notification_dedupe.dart';

void main() {
  group('NotificationDedupeStore', () {
    test('blocks duplicate key inside window and allows after expiry', () {
      final store = NotificationDedupeStore(
        window: const Duration(seconds: 30),
      );
      final base = DateTime(2026, 1, 1, 12, 0, 0);

      expect(store.registerIfFresh(['price_request:job_1'], now: base), isTrue);
      expect(
        store.registerIfFresh([
          'price_request:job_1',
        ], now: base.add(const Duration(seconds: 10))),
        isFalse,
      );
      expect(
        store.registerIfFresh([
          'price_request:job_1',
        ], now: base.add(const Duration(seconds: 31))),
        isTrue,
      );
    });

    test('treats any overlapping key as duplicate', () {
      final store = NotificationDedupeStore(
        window: const Duration(seconds: 30),
      );
      final base = DateTime(2026, 1, 1, 12, 0, 0);

      expect(
        store.registerIfFresh(['event:1', 'content:a'], now: base),
        isTrue,
      );
      expect(
        store.registerIfFresh([
          'content:a',
          'event:1:user-x',
        ], now: base.add(const Duration(seconds: 2))),
        isFalse,
      );
      expect(
        store.registerIfFresh([
          'event:2',
          'content:b',
        ], now: base.add(const Duration(seconds: 2))),
        isTrue,
      );
    });
  });

  group('dedupe key helpers', () {
    test('normalizes and de-duplicates keys', () {
      final keys = normalizeDedupeKeys(['  a  ', '', 'a', 'b  ']);
      expect(keys, hasLength(2));
      expect(keys, containsAll(<String>['a', 'b']));
    });

    test('builds stable content key with whitespace normalization', () {
      final first = buildNotificationContentDedupeKey(
        title: '  تم   اعتماد  عرضك  ',
        body: 'تحرك الآن',
        payload: '  /jobs/123 ',
      );
      final second = buildNotificationContentDedupeKey(
        title: 'تم اعتماد عرضك',
        body: 'تحرك الآن',
        payload: '/jobs/123',
      );
      expect(first, equals(second));
    });

    test('returns empty content key when fields are empty', () {
      final key = buildNotificationContentDedupeKey(
        title: '   ',
        body: null,
        payload: '\n',
      );
      expect(key, isEmpty);
    });

    test('shares keys between realtime and push for price request flow', () {
      final store = NotificationDedupeStore(
        window: const Duration(seconds: 30),
      );
      final base = DateTime(2026, 1, 1, 12, 0, 0);

      final realtimeKeys = buildLocalNotificationDedupeKeys(
        dedupeKey: 'price_pending:job-1:customer',
        title: 'عرض سعر جديد',
        body: 'أرسل الفني عرض سعر للخدمة. يرجى المراجعة.',
        payload: 'job-1',
        backendEventType: 'price_request',
        userId: 'user-1',
      );
      final pushKeys = buildPushForegroundDedupeKeys(
        data: <String, dynamic>{
          'event_type': 'price_request',
          'entity_id': 'job-1',
          'dedupe_key': 'price_request:job-1:user-1',
        },
        title: 'عرض سعر جديد',
        body: 'أرسل الفني عرض سعر للخدمة. يرجى المراجعة.',
        navigationPayload: 'job-1',
      );

      expect(store.registerIfFresh(realtimeKeys, now: base), isTrue);
      expect(
        store.registerIfFresh(
          pushKeys,
          now: base.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('allows push event when no overlap with previous local keys', () {
      final store = NotificationDedupeStore(
        window: const Duration(seconds: 30),
      );
      final base = DateTime(2026, 1, 1, 12, 0, 0);

      final localKeys = buildLocalNotificationDedupeKeys(
        dedupeKey: 'completion_request:job-1:customer',
        title: 'انتهى العمل',
        body: 'أنهى الفني العمل. يرجى تأكيد الإنجاز والدفع.',
        payload: 'job-1',
        backendEventType: 'completion_request',
        userId: 'user-1',
      );
      final unrelatedPushKeys = buildPushForegroundDedupeKeys(
        data: <String, dynamic>{
          'event_type': 'new_job_offer',
          'entity_id': 'job-2',
        },
        title: 'طلب خدمة جديد قريب منك',
        body: 'راجع الطلب الآن وقدّم عرض السعر المناسب.',
        navigationPayload: 'job-2',
      );

      expect(store.registerIfFresh(localKeys, now: base), isTrue);
      expect(
        store.registerIfFresh(
          unrelatedPushKeys,
          now: base.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('shares keys between cancellation realtime and push event', () {
      final store = NotificationDedupeStore(
        window: const Duration(seconds: 30),
      );
      final base = DateTime(2026, 1, 1, 12, 0, 0);

      final realtimeKeys = buildLocalNotificationDedupeKeys(
        dedupeKey: 'job_cancelled_by_technician:job-7:customer',
        title: 'تم إلغاء الطلب',
        body: 'قام الفني بإلغاء الطلب.',
        payload: 'job-7',
        backendEventType: 'job_cancelled_by_technician',
        userId: 'customer-1',
      );
      final pushKeys = buildPushForegroundDedupeKeys(
        data: <String, dynamic>{
          'event_type': 'job_cancelled_by_technician',
          'entity_id': 'job-7',
          'dedupe_key': 'job_cancelled_by_technician:job-7:customer-1',
        },
        title: 'تم إلغاء الطلب',
        body: 'قام الفني بإلغاء الطلب.',
        navigationPayload: 'job-7',
      );

      expect(store.registerIfFresh(realtimeKeys, now: base), isTrue);
      expect(
        store.registerIfFresh(
          pushKeys,
          now: base.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });
  });
}
