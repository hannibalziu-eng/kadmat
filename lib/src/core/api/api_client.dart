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

  // Use QueuedInterceptorsWrapper to ensure requests are processed sequentially
  // This prevents "Future already completed" errors from async operations
  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        // Don't add token for refresh endpoint
        if (options.path.contains('/auth/refresh')) {
          return handler.next(options);
        }

        // Add Auth Token to Header
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'auth_token');

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        return handler.next(options);
      },
      onError: (err, handler) async {
        print(
          '🚨 Interceptor Error: ${err.message} | Path: ${err.requestOptions.path}',
        );

        // Don't intercept errors for refresh endpoint
        if (err.requestOptions.path.contains('/auth/refresh')) {
          return handler.next(err);
        }

        // Handle 401 Unauthorized - Token Expired
        if (err.response?.statusCode == 401) {
          print('🔄 401 Detected. Attempting refresh...');
          const storage = FlutterSecureStorage();
          final refreshToken = await storage.read(key: 'refresh_token');

          if (refreshToken != null) {
            try {
              // Create a new Dio instance to avoid interceptor loops
              final refreshDio = Dio(
                BaseOptions(
                  baseUrl: Endpoints.baseUrl,
                  headers: {'Content-Type': 'application/json'},
                ),
              );

              final response = await refreshDio.post(
                '/auth/refresh',
                data: {'refresh_token': refreshToken},
              );

              if (response.statusCode == 200 &&
                  response.data['success'] == true) {
                print('✅ Token Refreshed!');
                final newAccessToken = response.data['token'];
                final newRefreshToken = response.data['refresh_token'];

                await storage.write(key: 'auth_token', value: newAccessToken);
                await storage.write(
                  key: 'refresh_token',
                  value: newRefreshToken,
                );

                // Retry the original request with new token
                final opts = err.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccessToken';

                // Use a fresh Dio to retry
                final retryDio = Dio(
                  BaseOptions(
                    baseUrl: Endpoints.baseUrl,
                    headers: opts.headers,
                  ),
                );

                try {
                  final retryResponse = await retryDio.request(
                    opts.path,
                    data: opts.data,
                    queryParameters: opts.queryParameters,
                    options: Options(
                      method: opts.method,
                      contentType: opts.contentType,
                      responseType: opts.responseType,
                    ),
                  );
                  return handler.resolve(retryResponse);
                } catch (retryError) {
                  print('❌ Retry request failed: $retryError');
                  if (retryError is DioException) {
                    return handler.next(retryError);
                  }
                  return handler.next(err);
                }
              } else {
                print('❌ Token refresh response unsuccessful');
                await storage.delete(key: 'auth_token');
                await storage.delete(key: 'refresh_token');
                return handler.next(err);
              }
            } catch (e) {
              print('❌ Token refresh failed: $e');
              await storage.delete(key: 'auth_token');
              await storage.delete(key: 'refresh_token');
              return handler.next(err);
            }
          } else {
            print('❌ No refresh token found.');
            await storage.delete(key: 'auth_token');
            return handler.next(err);
          }
        }

        return handler.next(err);
      },
    ),
  );

  return dio;
}
