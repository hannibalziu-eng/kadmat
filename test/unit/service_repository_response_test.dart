import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/home/data/service_repository.dart';
import 'package:mockito/mockito.dart';

import 'wallet_repository_test.mocks.dart';

void main() {
  group('ServiceRepository response parsing', () {
    late MockDio dio;
    late ServiceRepository repository;

    setUp(() {
      dio = MockDio();
      repository = ServiceRepository(dio);
    });

    test('parses services from new envelope shape (data.services)', () async {
      when(
        dio.get(
          '/services',
          data: anyNamed('data'),
          queryParameters: anyNamed('queryParameters'),
          options: anyNamed('options'),
          cancelToken: anyNamed('cancelToken'),
          onReceiveProgress: anyNamed('onReceiveProgress'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/services'),
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'count': 1,
              'services': [
                {
                  'id': 'svc-1',
                  'name': 'Plumbing',
                  'base_price': 50,
                  'is_active': true,
                },
              ],
            },
          },
        ),
      );

      final result = await repository.getServices();
      expect(result, hasLength(1));
      expect(result.first.id, 'svc-1');
      expect(result.first.basePrice, 50);
    });

    test(
      'parses single service from new envelope shape (data.service)',
      () async {
        when(
          dio.get(
            '/services/svc-1',
            data: anyNamed('data'),
            queryParameters: anyNamed('queryParameters'),
            options: anyNamed('options'),
            cancelToken: anyNamed('cancelToken'),
            onReceiveProgress: anyNamed('onReceiveProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/services/svc-1'),
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'service': {
                  'id': 'svc-1',
                  'name': 'Plumbing',
                  'base_price': 50,
                  'is_active': true,
                },
              },
            },
          ),
        );

        final result = await repository.getServiceById('svc-1');
        expect(result.id, 'svc-1');
        expect(result.name, 'Plumbing');
      },
    );
  });
}
