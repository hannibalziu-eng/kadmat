import 'dart:async';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'endpoints.dart';

part 'api_client.g.dart';

// Global completer to synchronize refresh requests across all Dio instances/interceptors
Completer<void>? _refreshCompleter;

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
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          // Check if token is expired or about to expire (within 60 seconds)
          if (session.isExpired) {
            print('⏰ Token expired/expiring. Refreshing BEFORE request...');
            try {
              final response = await Supabase.instance.client.auth
                  .refreshSession();
              if (response.session != null) {
                print('✅ Token refreshed proactively.');
                options.headers['Authorization'] =
                    'Bearer ${response.session!.accessToken}';
                return handler.next(options);
              }
            } catch (e) {
              print(
                '⚠️ Proactive refresh failed: $e. Proceeding with old token...',
              );
            }
          }

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

        if (err.requestOptions.path.contains('/auth/refresh')) {
          return handler.next(err);
        }

        if (err.response?.statusCode == 401) {
          final currentToken =
              err.requestOptions.headers['Authorization'] as String?;
          final session = Supabase.instance.client.auth.currentSession;

          // If no session exists, we can't refresh. Force logout/error.
          if (session == null) {
            print('❌ 401 received but no session exists. Cannot refresh.');
            return handler.next(err);
          }

          // 1. Check if token was already refreshed by another concurrent request
          if (currentToken != null &&
              'Bearer ${session.accessToken}' != currentToken) {
            print('🔄 Token already refreshed (Pre-lock check). Retrying...');
            return _retryRequest(
              dio,
              err.requestOptions,
              session.accessToken,
              handler,
            );
          }

          // 2. Refresh Lock
          if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
            print('⏳ Refresh in progress. Waiting for lock...');
            await _refreshCompleter!.future;

            final newSession = Supabase.instance.client.auth.currentSession;
            if (newSession != null) {
              print('✅ Lock released. Using new token.');
              return _retryRequest(
                dio,
                err.requestOptions,
                newSession.accessToken,
                handler,
              );
            } else {
              print('❌ Lock released but no session found.');
              return handler.next(err);
            }
          }

          // 3. Initiate Refresh
          _refreshCompleter = Completer<void>();
          print('🔄 401 Detected. Acquiring Lock & Refreshing Session...');

          try {
            final response = await Supabase.instance.client.auth
                .refreshSession();

            if (response.session != null) {
              print('✅ Supabase Session Refreshed!');
              _refreshCompleter?.complete();
              _refreshCompleter = null;

              return _retryRequest(
                dio,
                err.requestOptions,
                response.session!.accessToken,
                handler,
              );
            } else {
              print('❌ Supabase Refresh Failed: No session returned.');
              _refreshCompleter?.complete();
              _refreshCompleter = null;
              return handler.next(err);
            }
          } catch (e) {
            print('❌ Supabase Refresh Exception: $e');
            _refreshCompleter?.complete();
            _refreshCompleter = null;

            bool shouldForceLogout = false;
            final msg = e is AuthException
                ? e.message.toLowerCase()
                : e.toString().toLowerCase();

            if (msg.contains('invalid refresh token') ||
                msg.contains('refresh_token_already_used') ||
                msg.contains('session_not_found') ||
                msg.contains('session missing') ||
                e is AuthSessionMissingException) {
              shouldForceLogout = true;
            }

            if (shouldForceLogout) {
              print('🚨 Fatal Auth Error detected. Forcing Sign Out...');
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (_) {}
            }
            return handler.next(err);
          }
        }

        return handler.next(err);
      },
    ),
  );

  return dio;
}

Future<void> _retryRequest(
  Dio dio,
  RequestOptions requestOptions,
  String newToken,
  ErrorInterceptorHandler handler,
) async {
  final opts = requestOptions;
  opts.headers['Authorization'] = 'Bearer $newToken';

  // Use a fresh Dio for retry to avoid interceptor issues (infinite loops)
  final retryDio = Dio(
    BaseOptions(
      baseUrl: Endpoints.baseUrl,
      headers: opts.headers,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
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
  } catch (e) {
    // If retry fails, pass the error
    if (e is DioException) {
      return handler.next(e);
    }
    // Convert generic error to DioException if needed, or just reject
    return handler.reject(DioException(requestOptions: opts, error: e));
  }
}
