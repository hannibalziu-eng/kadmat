import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadmat/src/features/jobs/presentation/job_controller.dart';
import 'package:kadmat/src/features/jobs/data/job_repository.dart';
import 'package:kadmat/src/features/jobs/domain/job.dart';

// Generate mock (manual mock for now to save build_runner time in this demo)
class MockJobRepository extends Mock implements JobRepository {
  @override
  Future<Job> acceptJob(String? jobId) {
    return super.noSuchMethod(
          Invocation.method(#acceptJob, [jobId]),
          returnValue: Future.value(
            Job(
              id: '1',
              description: 'Mock Job',
              status: 'accepted',
              customerId: 'c1',
              serviceId: 's1',
              createdAt: DateTime.now(),
              lat: 0,
              lng: 0,
            ),
          ),
          returnValueForMissingStub: Future.value(
            Job(
              id: '1',
              description: 'Mock Job',
              status: 'accepted',
              customerId: 'c1',
              serviceId: 's1',
              createdAt: DateTime.now(),
              lat: 0,
              lng: 0,
            ),
          ),
        )
        as Future<Job>;
  }

  @override
  Future<Job?> createJob({
    required String serviceId,
    required double lat,
    required double lng,
    required String addressText,
    required double initialPrice,
    String? description,
    List<String>? images,
  }) {
    return super.noSuchMethod(
          Invocation.method(#createJob, [], {
            #serviceId: serviceId,
            #lat: lat,
            #lng: lng,
            #addressText: addressText,
            #initialPrice: initialPrice,
            #description: description,
            #images: images,
          }),
          returnValue: Future.value(
            Job(
              id: '1',
              description: 'New Job',
              status: 'pending',
              customerId: 'c1',
              serviceId: 's1',
              createdAt: DateTime.now(),
              lat: 10,
              lng: 10,
            ),
          ),
          returnValueForMissingStub: Future.value(
            Job(
              id: '1',
              description: 'New Job',
              status: 'pending',
              customerId: 'c1',
              serviceId: 's1',
              createdAt: DateTime.now(),
              lat: 10,
              lng: 10,
            ),
          ),
        )
        as Future<Job?>;
  }
}

void main() {
  late ProviderContainer container;
  late MockJobRepository mockJobRepository;

  setUp(() {
    mockJobRepository = MockJobRepository();
    container = ProviderContainer(
      overrides: [jobRepositoryProvider.overrideWithValue(mockJobRepository)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('JobController', () {
    test('initial state is AsyncData(null)', () {
      final controller = container.read(jobControllerProvider);
      expect(controller, const AsyncData<void>(null));
    });

    test('createJob calls repository and returns job', () async {
      // Arrange
      final newJob = Job(
        id: '1',
        description: 'New Job',
        status: 'pending',
        customerId: 'c1',
        serviceId: 's1',
        createdAt: DateTime.now(),
        lat: 10.0,
        lng: 10.0,
      );

      when(
        mockJobRepository.createJob(
          serviceId: 's1',
          lat: 10.0,
          lng: 10.0,
          addressText: 'Address',
          initialPrice: 100.0,
          description: 'New Job',
        ),
      ).thenAnswer((_) async => newJob);

      // Act
      final result = await container
          .read(jobControllerProvider.notifier)
          .createJob(
            serviceId: 's1',
            lat: 10.0,
            lng: 10.0,
            addressText: 'Address',
            initialPrice: 100.0,
            description: 'New Job',
          );

      // Assert
      expect(result, newJob);
      verify(
        mockJobRepository.createJob(
          serviceId: 's1',
          lat: 10.0,
          lng: 10.0,
          addressText: 'Address',
          initialPrice: 100.0,
          description: 'New Job',
        ),
      ).called(1);
    });

    test('acceptJob calls repository and returns accepted job', () async {
      // Arrange
      const jobId = '123';
      final acceptedJob = Job(
        id: jobId,
        description: 'Accepted Job',
        status: 'accepted',
        customerId: 'c1',
        serviceId: 's1',
        createdAt: DateTime.now(),
        lat: 24.0,
        lng: 46.0,
      );

      when(
        mockJobRepository.acceptJob(jobId),
      ).thenAnswer((_) async => acceptedJob);

      // Act
      final result = await container
          .read(jobControllerProvider.notifier)
          .acceptJob(jobId);

      // Assert
      expect(result, acceptedJob);
      verify(mockJobRepository.acceptJob(jobId)).called(1);
    });

    test('acceptJob handles errors', () async {
      // Arrange
      const jobId = 'error_job';
      when(
        mockJobRepository.acceptJob(jobId),
      ).thenThrow(Exception('Network Error'));

      // Act & Assert
      expect(
        () => container.read(jobControllerProvider.notifier).acceptJob(jobId),
        throwsException,
      );
    });
  });
}
