import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/notifications/data/notification_repository.dart';
import 'package:mockito/mockito.dart';

import 'wallet_repository_test.mocks.dart';

void main() {
  group('NotificationRepository response parsing', () {
    late MockDio dio;
    late NotificationRepository repository;

    setUp(() {
      dio = MockDio();
      repository = NotificationRepository(dio);
    });

    test('parses notifications from new envelope shape', () async {
      when(
        dio.get(
          '/notifications',
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
          cancelToken: anyNamed('cancelToken'),
          onReceiveProgress: anyNamed('onReceiveProgress'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/notifications'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'notifications': [
                {
                  'id': 'n-1',
                  'type': 'new_offer',
                  'title': 'عرض جديد',
                  'body': 'تم استلام عرض',
                  'data': {'job_id': 'job-1'},
                  'audience_role': 'technician',
                  'category': 'offer',
                  'channels': ['in_app'],
                  'priority': 2,
                  'is_read': false,
                  'created_at': '2026-02-28T00:00:00.000Z',
                },
              ],
            },
          },
        ),
      );

      final items = await repository.getNotifications();
      expect(items, hasLength(1));
      expect(items.first.id, 'n-1');
      expect(items.first.category, 'offer');
    });

    test('parses unread count from new envelope shape', () async {
      when(
        dio.get(
          '/notifications/unread-count',
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
          cancelToken: anyNamed('cancelToken'),
          onReceiveProgress: anyNamed('onReceiveProgress'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/notifications/unread-count'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {'unread_count': 7},
          },
        ),
      );

      final count = await repository.getUnreadCount();
      expect(count, 7);
    });
  });
}
