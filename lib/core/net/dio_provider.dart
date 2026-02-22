import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../auth/token_store.dart';
import '../config.dart';

final dioProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);
  final session = ref.watch(sessionStateProvider);

  String normalizeBaseUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) u = AppConfig.apiBaseUrl;

    // strip trailing slashes
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }

    // ensure /v1 exactly once at the end
    if (!u.endsWith('/v1')) {
      u = '$u/v1';
    }

    return u;
  }

  final baseUrl = normalizeBaseUrl(session.baseUrl);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  bool isPublicPath(String p) {
    // Public endpoints that must NOT require auth header
    return p.startsWith('/auth/login') ||
        p.startsWith('/auth/register') ||
        p.startsWith('/auth/refresh') ||
        p.startsWith('/auth/verify-email') ||
        p.startsWith('/auth/resend-verification') ||
        p.startsWith('/auth/resend-email-verification') ||
        p.startsWith('/auth/health') ||
        p.startsWith('/health');
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // do not send protected calls until tokens are loaded
        await tokenStore.waitUntilLoaded();

        final path = options.path;

        if (!isPublicPath(path)) {
          final token = tokenStore.accessToken;
          if (token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }

        handler.next(options);
      },
      onError: (err, handler) async {
        final status = err.response?.statusCode;
        final path = err.requestOptions.path;

        // If 401 and we have a refresh token, attempt refresh once.
        if (status == 401 && !isPublicPath(path)) {
          final refreshToken = session.refreshToken;
          if (refreshToken != null && refreshToken.trim().isNotEmpty) {
            try {
              final res = await dio.post(
                '/auth/refresh',
                data: {'refreshToken': refreshToken},
              );

              final data = res.data;
              if (data is Map) {
                final accessToken = (data['accessToken'] ?? '').toString();
                final newRefresh = data['refreshToken']?.toString();

                if (accessToken.trim().isNotEmpty) {
                  await tokenStore.setTokens(
                    accessToken: accessToken,
                    refreshToken: newRefresh,
                  );

                  // retry original request
                  final retry = await dio.request(
                    err.requestOptions.path,
                    data: err.requestOptions.data,
                    queryParameters: err.requestOptions.queryParameters,
                    options: Options(
                      method: err.requestOptions.method,
                      headers: {
                        ...err.requestOptions.headers,
                        'Authorization': 'Bearer $accessToken',
                      },
                    ),
                  );

                  return handler.resolve(retry);
                }
              }
            } catch (_) {
              // fall through
            }
          }
        }

        handler.next(err);
      },
    ),
  );

  return dio;
});