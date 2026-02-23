import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/token_store.dart';

final dioProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);

  String normalizeBaseUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) u = AppConfig.apiBaseUrl;

    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith('/v1')) {
      u = '$u/v1';
    }
    return u;
  }

  final baseUrl = normalizeBaseUrl(AppConfig.apiBaseUrl);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // Important for web cookie-based refresh sessions.
      extra: const {'withCredentials': true},
    ),
  );

  bool isPublicPath(String p) {
    return p.startsWith('/auth/login') ||
        p.startsWith('/auth/register') ||
        p.startsWith('/auth/refresh') ||
        p.startsWith('/auth/verify-email') ||
        p.startsWith('/auth/resend-verification') ||
        p.startsWith('/auth/resend-email-verification') ||
        p.startsWith('/auth/health') ||
        p.startsWith('/health');
  }

  // Single-flight refresh so we don't storm the API.
  Future<String?>? refreshInFlight;

  Future<String?> tryRefresh() async {
    // If we have a stored refresh token, backend MAY accept it.
    // If we do not, backend MAY use httpOnly cookie refresh.
    // We try both paths safely by calling refresh with:
    // - refreshToken if present
    // - otherwise empty body (cookie mode)
    final rt = tokenStore.refreshToken;

    final res = await dio.post(
      '/auth/refresh',
      data: (rt != null && rt.trim().isNotEmpty) ? {'refreshToken': rt} : {},
      options: Options(
        // Ensure cookies are sent (web).
        extra: const {'withCredentials': true},
      ),
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
        return accessToken;
      }
    }
    return null;
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        await tokenStore.waitUntilLoaded();

        final path = options.path;

        // Always send cookies on web where possible.
        options.extra = {
          ...options.extra,
          'withCredentials': true,
        };

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

        // If we got 401 on a protected endpoint, try refresh ONE TIME.
        if (status == 401 && !isPublicPath(path)) {
          try {
            refreshInFlight ??= tryRefresh();
            final newAccess = await refreshInFlight;
            refreshInFlight = null;

            if (newAccess != null && newAccess.trim().isNotEmpty) {
              // retry original request with new token
              final retry = await dio.request(
                err.requestOptions.path,
                data: err.requestOptions.data,
                queryParameters: err.requestOptions.queryParameters,
                options: Options(
                  method: err.requestOptions.method,
                  headers: {
                    ...err.requestOptions.headers,
                    'Authorization': 'Bearer $newAccess',
                  },
                  extra: {
                    ...err.requestOptions.extra,
                    'withCredentials': true,
                  },
                ),
              );
              return handler.resolve(retry);
            }
          } catch (_) {
            refreshInFlight = null;
          }

          // Hard rule: refresh failed or no new access token obtained.
          // That means we are NOT logged in. End the fake state.
          await tokenStore.clear();
        }

        handler.next(err);
      },
    ),
  );

  return dio;
});