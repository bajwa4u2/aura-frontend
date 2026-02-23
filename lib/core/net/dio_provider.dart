import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/session_providers.dart';
import '../auth/token_store.dart';

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

  // IMPORTANT (Mode B - HttpOnly refresh cookie):
  // Web must send cookies cross-site (api.aura.* <-> aura.*)
  if (kIsWeb) {
    try {
      final adapter = dio.httpClientAdapter;
      (adapter as dynamic).withCredentials = true;
    } catch (_) {
      // If adapter doesn't support withCredentials on this platform, ignore safely.
    }
  }

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

  // Single-flight refresh (prevents refresh storms + redirect loops)
  Future<String?>? refreshInFlight;

  Future<String?> refreshAccessToken() async {
    // If a refresh is already running, await it.
    if (refreshInFlight != null) return refreshInFlight;

    final completer = Completer<String?>();
    refreshInFlight = completer.future;

    try {
      // Mode B: refresh token is HttpOnly cookie, so request body is empty.
      final res = await dio.post('/auth/refresh');

      final data = res.data;
      if (data is Map) {
        final accessToken = (data['accessToken'] ?? '').toString().trim();

        if (accessToken.isNotEmpty) {
          // Persist only access token. Refresh token (if present) is ignored in cookie mode.
          await tokenStore.setTokens(accessToken: accessToken);
          completer.complete(accessToken);
        } else {
          completer.complete(null);
        }
      } else {
        completer.complete(null);
      }
    } catch (_) {
      completer.complete(null);
    } finally {
      // allow future refresh attempts
      refreshInFlight = null;
    }

    return completer.future;
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // do not send protected calls until tokens are loaded
        await tokenStore.waitUntilLoaded();

        final path = options.path;

        // Attach Authorization on protected routes only
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

        // Never attempt refresh if the failing request is itself refresh
        if (path.startsWith('/auth/refresh')) {
          return handler.next(err);
        }

        // If 401 on protected path, try cookie refresh once, then retry original request.
        if (status == 401 && !isPublicPath(path)) {
          final newAccessToken = await refreshAccessToken();

          if (newAccessToken != null && newAccessToken.trim().isNotEmpty) {
            try {
              final retry = await dio.request(
                err.requestOptions.path,
                data: err.requestOptions.data,
                queryParameters: err.requestOptions.queryParameters,
                options: Options(
                  method: err.requestOptions.method,
                  headers: {
                    ...err.requestOptions.headers,
                    'Authorization': 'Bearer $newAccessToken',
                  },
                ),
              );

              return handler.resolve(retry);
            } catch (_) {
              // fall through to original error
            }
          }
        }

        handler.next(err);
      },
    ),
  );

  return dio;
});