import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
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
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // Keep 2xx-only so 401 becomes an error and flows through onError refresh logic.
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );

  // Keep your existing platform config (IO vs web adapter specifics).
  configureDioForPlatform(dio);

  // HARD GUARANTEE (web): cookies must be included on XHR, otherwise refresh cookie never rides along.
  void ensureWebCredentials(Dio d) {
    if (!kIsWeb) return;

    final a = d.httpClientAdapter;
    if (a is BrowserHttpClientAdapter) {
      a.withCredentials = true;
    } else {
      d.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
    }
  }

  ensureWebCredentials(dio);

  // Single-flight refresh gate: multiple 401s will wait on the same refresh Future.
  Future<void>? refreshInFlight;

  bool isAuthEndpoint(RequestOptions o) {
    // Normalize the path (Dio can include full URL sometimes depending on usage)
    final path = o.path;

    // Strict allowlist: anything under /auth is auth.
    if (path.startsWith('/auth/')) return true;

    // If your backend is mounted under /v1, sometimes caller may pass /v1/auth/...
    if (path.startsWith('/v1/auth/')) return true;

    return false;
  }

  bool shouldClearTokensOnRefreshFailure(Object error) {
    // Only clear tokens when we are confident the session is invalid.
    // Network / timeouts should NOT force a logout.
    if (error is DioException) {
      final s = error.response?.statusCode;
      if (s == 401 || s == 403) return true;

      final msg = (error.message ?? '').toLowerCase();
      if (msg.contains('invalid') || msg.contains('unauthorized')) return true;

      return false;
    }
    return false;
  }

  Future<void> performRefresh() async {
    // Use the SAME Dio instance so web credentials/cookies are guaranteed to ride along.
    final refreshDio = dio;

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
      return;
    }

    // Non-web: refresh token may be stored and sent in body.
    final store = ref.read(tokenStoreProvider);
    await store.waitUntilLoaded();

    final refreshToken = store.refreshToken;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      throw Exception('Missing refresh token');
    }

    final res = await refreshDio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(headers: const {'x-token-transport': 'body'}),
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
      refreshToken: (newRefresh != null && newRefresh.isNotEmpty) ? newRefresh : refreshToken,
    );
  }

  // Clone & retry preserving the important RequestOptions fields.
  Future<Response<T>> retryRequest<T>(RequestOptions req, Map<String, dynamic> retryHeaders) {
    final options = Options(
      method: req.method,
      headers: retryHeaders,
      responseType: req.responseType,
      contentType: req.contentType,
      followRedirects: req.followRedirects,
      receiveDataWhenStatusError: req.receiveDataWhenStatusError,
      sendTimeout: req.sendTimeout,
      receiveTimeout: req.receiveTimeout,
      extra: Map<String, dynamic>.from(req.extra),
      validateStatus: req.validateStatus,
      requestEncoder: req.requestEncoder,
      responseDecoder: req.responseDecoder,
      listFormat: req.listFormat,
    );

    return dio.request<T>(
      req.path,
      data: req.data,
      queryParameters: req.queryParameters,
      options: options,
      cancelToken: req.cancelToken,
      onReceiveProgress: req.onReceiveProgress,
      onSendProgress: req.onSendProgress,
    );
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final store = ref.read(tokenStoreProvider);

        // Avoid firing protected calls before tokens are restored from storage.
        try {
          await store.waitUntilLoaded();
        } catch (_) {
          // Don't block forever.
        }

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

        if (status != 401 || isAuthEndpoint(req)) {
          handler.next(err);
          return;
        }

        if (req.extra['__retried_after_refresh'] == true) {
          handler.next(err);
          return;
        }

        try {
          // --- Single-flight refresh ---
          if (refreshInFlight != null) {
            await refreshInFlight!;
          } else {
            final completer = Completer<void>();
            refreshInFlight = completer.future;

            () async {
              try {
                await performRefresh();
                completer.complete();
              } catch (e, st) {
                completer.completeError(e, st);
              } finally {
                refreshInFlight = null;
              }
            }();

            await completer.future;
          }

          final newToken = ref.read(tokenStoreProvider).accessToken;

          // Retry original request with new token.
          final retryHeaders = Map<String, dynamic>.from(req.headers);
          retryHeaders.remove('Authorization');
          if (newToken != null && newToken.trim().isNotEmpty) {
            retryHeaders['Authorization'] = 'Bearer $newToken';
          }

          final extra = Map<String, dynamic>.from(req.extra);
          extra['__retried_after_refresh'] = true;

          final reqWithExtra = req.copyWith(extra: extra);

          final cloned = await retryRequest<dynamic>(reqWithExtra, retryHeaders);
          handler.resolve(cloned);
        } catch (refreshError) {
          if (shouldClearTokensOnRefreshFailure(refreshError)) {
            await ref.read(tokenStoreProvider).clearTokens();
          }

          // IMPORTANT: bubble the refresh failure, not just the original 401.
          // This stops you from chasing the wrong thing.
          if (refreshError is DioException) {
            handler.next(refreshError);
          } else {
            handler.next(
              DioException(
                requestOptions: req,
                type: DioExceptionType.unknown,
                error: refreshError,
                message: 'Refresh failed: $refreshError',
              ),
            );
          }
        }
      },
    ),
  );

  return dio;
});