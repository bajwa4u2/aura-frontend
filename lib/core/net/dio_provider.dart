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
      // Treat ONLY 2xx as success. Everything else becomes a Dio error.
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );

  configureDioForPlatform(dio);

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

  // A dedicated Dio for refresh calls, intentionally WITHOUT interceptors.
  // This avoids recursion and reduces auth-state thrash.
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
      },
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );
  configureDioForPlatform(refreshDio);
  ensureWebCredentials(refreshDio);

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    throw Exception('Invalid response type');
  }

  String _readAccessToken(Map<String, dynamic> outer) {
    final t1 = (outer['accessToken'] ?? '').toString().trim();
    if (t1.isNotEmpty) return t1;

    final data = outer['data'];
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data as Map);
      final t2 = (inner['accessToken'] ?? '').toString().trim();
      if (t2.isNotEmpty) return t2;
    }
    return '';
  }

  String? _readRefreshToken(Map<String, dynamic> outer) {
    final r1 = (outer['refreshToken'] ?? '').toString().trim();
    if (r1.isNotEmpty) return r1;

    final data = outer['data'];
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data as Map);
      final r2 = (inner['refreshToken'] ?? '').toString().trim();
      if (r2.isNotEmpty) return r2;
    }
    return null;
  }

  Future<void>? refreshInFlight;

  String _normalizedPath(RequestOptions o) {
    // RequestOptions.path may be "/v1/auth/me" or "/auth/refresh" etc.
    // Normalize by removing an optional "/v1" prefix.
    var p = o.path.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) {
      // Best-effort parse if someone passed a full URL as path.
      final uri = Uri.tryParse(p);
      if (uri != null) p = uri.path;
    }
    if (p.startsWith('/v1/')) p = p.substring(3); // remove "/v1"
    return p; // now like "/auth/me", "/posts", etc.
  }

  bool isAuthEndpoint(RequestOptions o) {
    final p = _normalizedPath(o);

    // Any auth endpoint should NOT trigger interceptor refresh.
    if (p.startsWith('/auth')) return true;

    // Also exclude any token/session endpoints you might add later.
    return false;
  }

  bool _shouldAttemptRefreshNow() {
    // Critical: do NOT attempt refresh when app already considers itself unauthed/loading.
    // That causes redirect thrash and login overlay issues.
    final s = ref.read(authStatusProvider);
    if (s == AuthStatus.loading) return false;
    if (s == AuthStatus.unauthed) return false;
    return true; // only when authed
  }

  bool shouldClearTokensOnRefreshFailure(Object error) {
    // On web, a refresh failure is often just "no cookie" for logged-out users.
    // Clearing tokens here causes pointless state flips and router thrash.
    if (kIsWeb) return false;

    if (error is DioException) {
      final s = error.response?.statusCode;
      return s == 401 || s == 403;
    }
    return false;
  }

  Future<void> performRefresh() async {
    if (kIsWeb) {
      // Web refresh: cookie-based, NO JSON body.
      // Keep it minimal to reduce preflight and avoid browser oddities.
      final res = await refreshDio.post(
        '/auth/refresh',
        data: null,
        options: Options(
          contentType: Headers.textPlainContentType,
          headers: const {
            'Content-Type': 'text/plain',
            'Accept': 'application/json',
          },
        ),
      );

      // Backend may return 204 for "refreshed via cookie, nothing to return".
      if (res.statusCode == 204) return;

      final outer = _asMap(res.data);
      final access = _readAccessToken(outer);

      if (access.isEmpty) {
        throw Exception('No access token returned');
      }

      await ref.read(tokenStoreProvider).setSession(accessToken: access);
      return;
    }

    // Non-web: body-based refresh token
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

    final outer = _asMap(res.data);
    final access = _readAccessToken(outer);
    final newRefresh = _readRefreshToken(outer);

    if (access.isEmpty) {
      throw Exception('No access token returned');
    }

    await store.setSession(
      accessToken: access,
      refreshToken: (newRefresh != null && newRefresh.isNotEmpty)
          ? newRefresh
          : refreshToken,
    );
  }

  Future<Response<T>> retryRequest<T>(
    RequestOptions req,
    Map<String, dynamic> retryHeaders,
  ) {
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

        try {
          await store.waitUntilLoaded();
        } catch (_) {}

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

        // Only handle 401s, and never for auth endpoints themselves.
        if (status != 401 || isAuthEndpoint(req)) {
          handler.next(err);
          return;
        }

        // If we already retried this request after refresh, do not loop.
        if (req.extra['__retried_after_refresh'] == true) {
          handler.next(err);
          return;
        }

        // If auth is not in a state where refresh makes sense, do not attempt it.
        if (!_shouldAttemptRefreshNow()) {
          handler.next(err);
          return;
        }

        try {
          // Single-flight refresh: all 401s await the same refresh future.
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

          // Retry the original request once with the newest token.
          final newToken = ref.read(tokenStoreProvider).accessToken;

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
          // Only clear tokens where it is truly appropriate.
          if (shouldClearTokensOnRefreshFailure(refreshError)) {
            await ref.read(tokenStoreProvider).clearTokens();
          }

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