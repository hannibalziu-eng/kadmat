import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../domain/service.dart';

part 'service_repository.g.dart';

class ServiceRepository {
  final Dio _client;

  ServiceRepository(this._client);

  Future<List<Service>> getServices() async {
    try {
      final response = await _client.get(Endpoints.services);
      final List data = response.data['services'];
      return data.map((e) => Service.fromJson(e)).toList();
    } catch (e) {
      if (e is DioException) {
        final message = e.response?.data['message'] ?? 'فشل جلب الخدمات';
        throw Exception(message);
      }
      throw Exception('فشل جلب الخدمات: $e');
    }
  }

  Future<Service> getServiceById(String id) async {
    try {
      final response = await _client.get(Endpoints.serviceById(id));
      return Service.fromJson(response.data['service']);
    } catch (e) {
      throw Exception('فشل جلب بيانات الخدمة');
    }
  }
}

@Riverpod(keepAlive: true)
ServiceRepository serviceRepository(ServiceRepositoryRef ref) {
  final client = ref.watch(apiClientProvider);
  return ServiceRepository(client);
}

@riverpod
Future<List<Service>> allServices(AllServicesRef ref) {
  return ref.watch(serviceRepositoryProvider).getServices();
}
