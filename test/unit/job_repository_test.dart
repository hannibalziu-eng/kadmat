import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/jobs/data/job_repository.dart';
import 'package:kadmat/src/features/jobs/domain/job.dart';
import 'package:kadmat/src/core/services/photo_upload_service.dart';
import 'package:kadmat/src/core/realtime/supabase_realtime_service.dart';
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:kadmat/src/core/services/offline/work_queue_service.dart';

@GenerateMocks([
  Dio,
  PhotoUploadService,
  SupabaseRealtimeService,
  WorkQueueService,
])
import 'job_repository_test.mocks.dart';

void main() {
  group('JobRepository Tests', () {
    late JobRepository repository;
    late MockDio mockDio;
    late MockPhotoUploadService mockPhotoService;
    late MockSupabaseRealtimeService mockRealtimeService;
    late MockWorkQueueService mockWorkQueue;

    setUp(() {
      mockDio = MockDio();
      mockPhotoService = MockPhotoUploadService();
      mockRealtimeService = MockSupabaseRealtimeService();
      mockWorkQueue = MockWorkQueueService();

      repository = JobRepository(
        mockDio,
        mockPhotoService,
        mockWorkQueue,
        mockRealtimeService,
      );
    });

    // ... (rest of tests)
    test('createJob should return job data on success', () async {
      // Arrange
      final mockResponse = {
        'id': 'job-123',
        'customer_id': 'customer-1',
        'service_id': 'service-1',
        'description': 'Test job',
        'status': 'pending',
        'lat': 24.7136,
        'lng': 46.6753,
        'initial_price': 100.0,
        'created_at': DateTime.now().toIso8601String(), // Use valid date
      };

      when(mockDio.post(any, data: anyNamed('data'))).thenAnswer(
        (_) async => Response(
          data: {'success': true, 'data': mockResponse},
          statusCode: 201,
          requestOptions: RequestOptions(path: '/jobs'),
        ),
      );

      // Act
      await repository.createJob(
        serviceId: 'service-1',
        description: 'Test job',
        lat: 24.7136,
        lng: 46.6753,
        addressText: 'Test Address',
        initialPrice: 100.0,
      );

      // Assert
      verify(mockDio.post(any, data: anyNamed('data'))).called(1);
    });

    test('getNearbyJobs should return list of jobs', () async {
      // Arrange
      final mockResponse = [
        {
          'id': 'job-1',
          'customer_id': 'customer-1',
          'service_id': 'service-1',
          'description': 'Job 1',
          'status': 'pending',
          'lat': 24.7136,
          'lng': 46.6753,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'job-2',
          'customer_id': 'customer-2',
          'service_id': 'service-2',
          'description': 'Job 2',
          'status': 'pending',
          'lat': 24.7236,
          'lng': 46.6853,
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      when(
        mockDio.get(any, queryParameters: anyNamed('queryParameters')),
      ).thenAnswer(
        (_) async => Response(
          data: {'success': true, 'data': mockResponse},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/jobs/nearby'),
        ),
      );

      // Act
      final result = await repository.getNearbyJobs(lat: 24.7136, lng: 46.6753);

      // Assert
      expect(result, isA<List<Job>>());
      expect(result.length, 2);
      verify(
        mockDio.get(any, queryParameters: anyNamed('queryParameters')),
      ).called(1);
    });
  });
}
