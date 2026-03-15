import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/auth_providers.dart';
import '../auth/session_bootstrap.dart';
import '../auth/session_providers.dart';
import 'platform_http_adapter.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
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

  configureDioForPlatform(dio);

  const _bodyMethods = {'POST', 'PUT', 'PATCH'};

  bool _hasMeaningfulBody(dynamic data) {
    if (data == null) return false;
    if (data is String) return data.trim().isNotEmpty;
    if (data is List) return data.isNotEmpty;
    if (data is Map) return data.isNotEmpty;
    if (data is FormData) return true;
    return true;
  }

  void _normalizeContentTypeForRequest(RequestOptions options) {
    final method = options.method.toUpperCase();
    final hasBody = _hasMeaningfulBody(options.data);
    final hasExplicitContentType =
        options.contentType != null ||
        options.headers.keys.any(
          (key) => key.toString().toLowerCase() == 'content-type',
        );

    final isMultipart = options.data is FormData;

    if (isMultipart) {
      options.headers.remove('Content-Type');
      options.contentType = null;
      return;
    }

    if (_bodyMethods.contains(method) && hasBody) {
      if (!hasExplicitContentType) {
        options.contentType = Headers.jsonContentType;
        options.headers['Content-Type'] = Headers.jsonContentType;
      }
      return;
    }

    options.headers.remove('Content-Type');
    if (!hasExplicitContentType || !hasBody) {
      options.contentType = null;
    }
  }

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
      final inner = Map<String, dynamic>.from(data);
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
      final inner = Map<String, dynamic>.from(data);
      final r2 = (inner['refreshToken'] ?? '').toString().trim();
      if (r2.isNotEmpty) return r2;
    }

    return null;
  }

  bool _isUnauthorizedStatus(int? status) {
    return status == 401 || status == 403;
  }

  Future<void> _clearSessionState() async {
    await ref.read(tokenStoreProvider).clearTokens();

    ref.invalidate(sessionBootstrapProvider);
    ref.invalidate(authStatusProvider);
  }

  Future<void>? refreshInFlight;

  bool isAuthEndpoint(RequestOptions o) {
    final path = o.path;
    if (path.startsWith('/auth')) return true;
    if (path.startsWith('/v1/auth')) return true;
    return false;
  }

  bool canAttemptRefreshNow() {
    final store = ref.read(tokenStoreProvider);

    if (!store.isLoaded) return false;

    final boot = ref.read(sessionBootstrapProvider);
    if (boot.isLoading) return false;

    return true;
  }

  bool shouldClearTokensOnRefreshFailure(Object error) {
    if (error is DioException) {
      return _isUnauthorizedStatus(error.response?.statusCode);
    }

    return false;
  }

  Dio buildRefreshDio() {
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Accept': 'application/json',
        },
        validateStatus: (code) => code != null && code >= 200 && code < 500,
      ),
    );

    configureDioForPlatform(refreshDio);

    return refreshDio;
  }

  Future<void> performRefresh() async {
    final refreshDio = buildRefreshDio();

    try {
      if (kIsWeb) {
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

        if (_isUnauthorizedStatus(res.statusCode)) {
          throw DioException(
            requestOptions: res.requestOptions,
            response: res,
            type: DioExceptionType.badResponse,
            message: 'Web refresh unauthorized',
          );
        }

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

      if (_isUnauthorizedStatus(res.statusCode)) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
          message: 'Native refresh unauthorized',
        );
      }

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
    } finally {
      refreshDio.close(force: true);
    }
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

        _normalizeContentTypeForRequest(options);

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
            await _clearSessionState();
            handler.next(err);
            return;
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
