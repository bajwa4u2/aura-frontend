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

  bool isAuthEndpoint(RequestOptions o) {
    final path = o.path;

    // Any auth path should NOT trigger interceptor refresh.
    if (path.startsWith('/auth')) return true;
    if (path.startsWith('/v1/auth')) return true;

    return false;
  }

  bool shouldClearTokensOnRefreshFailure(Object error) {
    if (error is DioException) {
      final s = error.response?.statusCode;
      return s == 401 || s == 403;
    }
    return false;
  }

  /// Avoid refresh storms:
  /// - If token store isn’t loaded yet, don’t attempt refresh via interceptor.
  /// - Router/bootstrap owns “first refresh attempt” on app start.
  bool canAttemptRefreshNow() {
    final store = ref.read(tokenStoreProvider);
    return store.isLoaded;
  }

  Future<void> performRefresh() async {
    final refreshDio = dio;

    if (kIsWeb) {
      // Web refresh: cookie-based, NO JSON body.
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

      if (res.statusCode == 204) return;

      final outer = _asMap(res.data);
      final access = _readAccessToken(outer);

      if (access.isEmpty) {
        throw Exception('No access token returned');
      }

      await ref.read(tokenStoreProvider).setSession(accessToken: access);
      return;
    }

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
      refreshToken:
          (newRefresh != null && newRefresh.isNotEmpty) ? newRefresh : refreshToken,
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

        if (status != 401 || isAuthEndpoint(req)) {
          handler.next(err);
          return;
        }

        if (!canAttemptRefreshNow()) {
          handler.next(err);
          return;
        }

        if (req.extra['__retried_after_refresh'] == true) {
          handler.next(err);
          return;
        }

        try {
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