import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'endpoints.dart';

part 'api_client.g.dart';

@Riverpod(keepAlive: true)
Dio apiClient(ApiClientRef ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Endpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Add Interceptors
  dio.interceptors.add(TokenInterceptor(dio));

  return dio;
}

class TokenInterceptor extends Interceptor {
  final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  TokenInterceptor(this.dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add Auth Token to Header
    final token = await _storage.read(key: 'auth_token');

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 Unauthorized - Token Expired
    if (err.response?.statusCode == 401) {
      final refreshToken = await _storage.read(key: 'refresh_token');

      if (refreshToken != null) {
        try {
          // Attempt to refresh the token
          final response = await dio.post(
            '${Endpoints.baseUrl}/auth/refresh',
            data: {'refresh_token': refreshToken},
            options: Options(
              headers: {}, // Don't include Authorization header
            ),
          );

          if (response.statusCode == 200 && response.data['success'] == true) {
            // Save new tokens
            final newAccessToken = response.data['token'];
            final newRefreshToken = response.data['refresh_token'];

            await _storage.write(key: 'auth_token', value: newAccessToken);
            await _storage.write(key: 'refresh_token', value: newRefreshToken);

            // Retry the original request with new token
            final clonedRequest = err.requestOptions;
            clonedRequest.headers['Authorization'] = 'Bearer $newAccessToken';

            final retryResponse = await dio.fetch(clonedRequest);
            return handler.resolve(retryResponse);
          }
        } catch (e) {
          // Refresh token failed - logout user
          await _storage.delete(key: 'auth_token');
          await _storage.delete(key: 'refresh_token');

          // TODO: Navigate to login screen
          // You can use a navigation service or emit an event here
          print('Token refresh failed. User needs to re-login.');
        }
      } else {
        // No refresh token - user needs to login
        await _storage.delete(key: 'auth_token');
        print('No refresh token found. User needs to login.');
      }
    }

    handler.next(err);
  }
}
