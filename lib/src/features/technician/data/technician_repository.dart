import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

part 'technician_repository.g.dart';

class TechnicianRepository {
  final Dio _client;

  TechnicianRepository(this._client);

  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      await _client.post(
        Endpoints.technicianLocation,
        data: {'latitude': latitude, 'longitude': longitude},
      );
    } catch (e) {
      // Silently fail for location updates to avoid spamming errors
      // or log it to a monitoring service
      print('Failed to update location: $e');
    }
  }

  Future<void> toggleStatus(bool isOnline) async {
    await _client.post(
      Endpoints.technicianStatus,
      data: {'isOnline': isOnline},
    );
  }
}

@riverpod
TechnicianRepository technicianRepository(TechnicianRepositoryRef ref) {
  return TechnicianRepository(ref.watch(apiClientProvider));
}
