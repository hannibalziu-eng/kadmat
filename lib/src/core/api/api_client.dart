import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

        // Add Auth Token from Supabase Session
        // This is more reliable than manual storage as Supabase SDK manages persistence/refresh
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          final token = session.accessToken;
          options.headers['Authorization'] = 'Bearer $token';
          print('✅ Token Added to Request: ${token.substring(0, 10)}...');
        } else {
          print('⚠️ No Supabase session found for request: ${options.path}');
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
          print('🔄 401 Detected. Attempting Supabase SDK refresh...');

          try {
            // Attempt to refresh the session using Supabase SDK
            // This checks for a locally stored refresh token and uses it
            final response = await Supabase.instance.client.auth
                .refreshSession();

            if (response.session != null) {
              print('✅ Supabase Session Refreshed!');

              // Retry the request with the new token
              final opts = err.requestOptions;
              opts.headers['Authorization'] =
                  'Bearer ${response.session!.accessToken}';

              // Use a fresh Dio for retry to avoid interceptor issues
              final retryDio = Dio(
                BaseOptions(baseUrl: Endpoints.baseUrl, headers: opts.headers),
              );

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
            } else {
              print('❌ Supabase Refresh Failed: No session returned.');
              return handler.next(err);
            }
          } catch (e) {
            print('❌ Supabase Refresh Exception: $e');
            return handler.next(err);
          }
        }

        return handler.next(err);
      },
    ),
  );

  return dio;
}
