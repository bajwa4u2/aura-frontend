import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/session_providers.dart';

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
    ),
  );

  // Web: ensure cookies are included (needed for HttpOnly refresh cookie).
  if (kIsWeb) {
    try {
      final adapter = dio.httpClientAdapter;
      (adapter as dynamic).withCredentials = true;
    } catch (_) {
      // ignore if adapter doesn't expose withCredentials
    }
  }

  bool isPublicPath(String p) {
    return p.startsWith('/auth/login') ||
        p.startsWith('/auth/register') ||
        p.startsWith('/auth/refresh') ||
        p.startsWith('/auth/verify-email') ||
        p.startsWith('/auth/resend-verification') ||
        p.startsWith('/auth/resend-email-verification') ||
        p.startsWith('/auth/forgot-password') ||
        p.startsWith('/auth/reset-password') ||
        p.startsWith('/auth/logout') ||
        p.startsWith('/auth/health') ||
        p.startsWith('/health');
  }

  // Single-flight refresh so we don't storm the API.
  Future<String?>? refreshInFlight;

  String? _extractAccessToken(dynamic data) {
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);

    // Common refresh response: { accessToken: '...' }
    final direct = (m['accessToken'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    // Some backends may wrap: { ok:true, data:{ accessToken:'...' } }
    if (m['ok'] == true && m['data'] is Map) {
      final inner = Map<String, dynamic>.from(m['data'] as Map);
      final innerToken = (inner['accessToken'] ?? '').toString().trim();
      if (innerToken.isNotEmpty) return innerToken;
    }

    return null;
  }

  Future<String?> tryRefresh() async {
    // Mode B: refresh token is HttpOnly cookie (web).
    // Still allow body refreshToken if it exists (mobile/legacy).
    final rt = tokenStore.refreshToken;

    final res = await dio.post(
      '/auth/refresh',
      data: (rt != null && rt.trim().isNotEmpty) ? {'refreshToken': rt} : {},
      options: Options(
        extra: const {'withCredentials': true},
      ),
    );

    final newAccess = _extractAccessToken(res.data);
    if (newAccess != null && newAccess.isNotEmpty) {
      await tokenStore.setTokens(accessToken: newAccess, refreshToken: null);
      return newAccess;
    }

    return null;
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        await tokenStore.waitUntilLoaded();

        final path = options.path;

        // Ensure web cookies are sent.
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

        // Never try to refresh when refresh itself failed.
        if (path.startsWith('/auth/refresh')) {
          return handler.next(err);
        }

        if (status == 401 && !isPublicPath(path)) {
          try {
            refreshInFlight ??= tryRefresh();
            final newAccess = await refreshInFlight;
            refreshInFlight = null;

            if (newAccess != null && newAccess.trim().isNotEmpty) {
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

          // Hard rule: refresh failed => we are NOT logged in.
          // End the “pretend signed in” state.
          await tokenStore.clear();
        }

        handler.next(err);
      },
    ),
  );

  return dio;
});