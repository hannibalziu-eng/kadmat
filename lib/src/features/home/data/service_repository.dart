import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/response_utils.dart';
import '../../../core/utils/error_messages.dart';
import '../domain/service.dart';

part 'service_repository.g.dart';

class ServiceRepository {
  final Dio _client;

  ServiceRepository(this._client);

  String _friendlyServiceError(dynamic error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message =
            data['message'] ??
            (data['error'] is Map<String, dynamic>
                ? data['error']['message']
                : null);
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    }

    final resolved = ErrorMessages.fromException(error);
    return resolved == ErrorMessages.unknownError
        ? 'فشل جلب الخدمات'
        : resolved;
  }

  Future<List<Service>> getServices() async {
    try {
      final response = await _client.get(Endpoints.services);
      final List data = responseListField(response.data, 'services');
      return data.map((e) => Service.fromJson(e)).toList();
    } catch (e) {
      // Fallback to Supabase if API fails (e.g. 429 Rate Limit)
      try {
        final data = await Supabase.instance.client
            .from('services')
            .select()
            .order('name');
        return (data as List).map((e) => Service.fromJson(e)).toList();
      } catch (_) {
        throw Exception(_friendlyServiceError(e));
      }
    }
  }

  Future<Service> getServiceById(String id) async {
    try {
      final response = await _client.get(Endpoints.serviceById(id));
      final service = responseObjectField(response.data, 'service');
      if (service.isEmpty) {
        throw Exception('بيانات الخدمة غير متاحة');
      }
      return Service.fromJson(service);
    } catch (e) {
      throw Exception('فشل جلب بيانات الخدمة');
    }
  }
}

@Riverpod(keepAlive: true)
ServiceRepository serviceRepository(Ref ref) {
  final client = ref.watch(apiClientProvider);
  return ServiceRepository(client);
}

@riverpod
Future<List<Service>> allServices(Ref ref) {
  return ref.watch(serviceRepositoryProvider).getServices();
}
