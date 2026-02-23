import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/auth_providers.dart';
import 'platform_http_adapter.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
      // We want to handle auth failures ourselves; don't auto-throw on 401.
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );

  // Web needs cookies (HttpOnly refresh cookie) to be included on requests.
  configureDioForPlatform(dio);

  // Single-flight refresh gate (no extra dependency):
  // multiple 401s will wait on the same refresh Future.
  Future<void>? _refreshInFlight;

  bool _isAuthEndpoint(RequestOptions o) {
    final p = o.path;
    return p.contains('/auth/login') ||
        p.contains('/auth/register') ||
        p.contains('/auth/verify-email') ||
        p.contains('/auth/resend-verification') ||
        p.contains('/auth/forgot-password') ||
        p.contains('/auth/reset-password') ||
        p.contains('/auth/refresh') ||
        p.contains('/auth/logout');
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final store = ref.read(tokenStoreProvider);

        // Attach access token if present.
        final token = store.accessToken;
        if (token != null && token.trim().isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          options.headers.remove('Authorization');
        }

        handler.next(options);
      },
      onError: (err, handler) async {
        final status = err.response?.statusCode;
        final req = err.requestOptions;

        if (status != 401 || _isAuthEndpoint(req)) {
          handler.next(err);
          return;
        }

        if (req.extra['__retried_after_refresh'] == true) {
          // Avoid loops.
          await ref.read(tokenStoreProvider).clearTokens();
          handler.next(err);
          return;
        }

        try {
          // --- Single-flight refresh (replaces Lock().synchronized) ---
          if (_refreshInFlight != null) {
            await _refreshInFlight!;
          } else {
            final completer = Completer<void>();
            _refreshInFlight = completer.future;

            () async {
              try {
                final refreshDio = Dio(
                  BaseOptions(
                    baseUrl: AppConfig.apiBaseUrl,
                    headers: {'Content-Type': 'application/json'},
                    validateStatus: (c) => c != null && c >= 200 && c < 300,
                  ),
                );

                // Make sure refresh call uses cookies on web.
                configureDioForPlatform(refreshDio);

                if (kIsWeb) {
                  // Web: refresh token is in HttpOnly cookie.
                  final res = await refreshDio.post('/auth/refresh');
                  final raw = res.data;

                  if (raw is! Map) throw Exception('Invalid refresh response');

                  final access = raw['accessToken']?.toString();
                  if (access == null || access.isEmpty) {
                    throw Exception('No access token returned');
                  }

                  // Do NOT store refresh token on web.
                  await ref.read(tokenStoreProvider).setSession(
                        accessToken: access,
                        refreshToken: null,
                      );
                } else {
                  // Non-web: refresh token may be stored and sent in body.
                  final store = ref.read(tokenStoreProvider);
                  final refreshToken = store.refreshToken;

                  if (refreshToken == null || refreshToken.trim().isEmpty) {
                    throw Exception('Missing refresh token');
                  }

                  final res = await refreshDio.post(
                    '/auth/refresh',
                    data: {'refreshToken': refreshToken},
                  );

                  final raw = res.data;
                  if (raw is! Map) throw Exception('Invalid refresh response');

                  final access = raw['accessToken']?.toString();
                  final newRefresh = raw['refreshToken']?.toString();

                  if (access == null || access.isEmpty) {
                    throw Exception('No access token returned');
                  }

                  await store.setSession(
                    accessToken: access,
                    refreshToken: (newRefresh != null && newRefresh.isNotEmpty)
                        ? newRefresh
                        : refreshToken,
                  );
                }

                completer.complete();
              } catch (e, st) {
                completer.completeError(e, st);
              } finally {
                _refreshInFlight = null;
              }
            }();

            await completer.future;
          }

          final newToken = ref.read(tokenStoreProvider).accessToken;

          // Retry original request with new token.
          final cloned = await dio.request<dynamic>(
            req.path,
            data: req.data,
            queryParameters: req.queryParameters,
            options: Options(
              method: req.method,
              headers: Map<String, dynamic>.from(req.headers)
                ..['Authorization'] = (newToken != null && newToken.trim().isNotEmpty)
                    ? 'Bearer $newToken'
                    : null,
              extra: Map<String, dynamic>.from(req.extra)
                ..['__retried_after_refresh'] = true,
            ),
          );

          handler.resolve(cloned);
        } catch (_) {
          // Refresh failed: clear and bubble up the original error.
          await ref.read(tokenStoreProvider).clearTokens();
          handler.next(err);
        }
      },
    ),
  );

  return dio;
});