import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/response_utils.dart';
import '../../../core/utils/error_messages.dart';
import '../domain/service.dart';
import '../domain/service_catalog_item.dart';

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
      return data
          .whereType<Map>()
          .map((e) => Service.fromJson(
              e.map((key, value) => MapEntry(key.toString(), value))))
          .toList();
    } catch (e) {
      try {
        final data = await Supabase.instance.client
            .from('services')
            .select()
            .order('name');
        return (data as List)
            .whereType<Map>()
            .map((e) => Service.fromJson(
                e.map((key, value) => MapEntry(key.toString(), value))))
            .toList();
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
      try {
        final data = await Supabase.instance.client
            .from('services')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (data == null) {
          throw Exception('بيانات الخدمة غير متاحة');
        }
        return Service.fromJson(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
      } catch (_) {
        throw Exception('فشل جلب بيانات الخدمة');
      }
    }
  }

  Future<List<ServiceCatalogItem>> getServiceCatalogItems(String serviceId) async {
    try {
      final response = await _client.get(Endpoints.serviceCatalogItems(serviceId));
      final rawItems = responseListField(response.data, 'items');
      return rawItems
          .whereType<Map>()
          .map((item) => ServiceCatalogItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value))))
          .toList();
    } catch (_) {
      try {
        final fallback = await Supabase.instance.client
            .from('service_catalog_items')
            .select()
            .eq('service_id', serviceId)
            .eq('is_active', true)
            .order('sort_order', ascending: true)
            .order('name', ascending: true);

        return (fallback as List)
            .whereType<Map>()
            .map((item) => ServiceCatalogItem.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value))))
            .toList();
      } catch (_) {
        return const [];
      }
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
