import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/auth_providers.dart';
import '../auth/session_bootstrap.dart';
import '../auth/session_providers.dart';
import '../errors/app_error_mapper.dart';
import 'platform_http_adapter.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );

  configureDioForPlatform(dio);

  const bodyMethods = {'POST', 'PUT', 'PATCH'};

  bool hasMeaningfulBody(dynamic data) {
    if (data == null) return false;
    if (data is String) return data.trim().isNotEmpty;
    if (data is List) return data.isNotEmpty;
    if (data is Map) return data.isNotEmpty;
    if (data is FormData) return true;
    return true;
  }

  String normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    var normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';

    final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    final basePath = baseUri?.path.trim() ?? '';
    final hasV1InBase = basePath == '/v1' || basePath.endsWith('/v1');

    if (hasV1InBase && normalized.startsWith('/v1/')) {
      normalized = normalized.substring(3);
      if (!normalized.startsWith('/')) {
        normalized = '/$normalized';
      }
    }

    while (normalized.contains('//')) {
      normalized = normalized.replaceAll('//', '/');
    }

    return normalized;
  }

  void normalizeContentTypeForRequest(RequestOptions options) {
    final method = options.method.toUpperCase();
    final hasBody = hasMeaningfulBody(options.data);
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

    if (bodyMethods.contains(method) && hasBody) {
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

  Map<String, dynamic> asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    throw Exception('Invalid response type');
  }

  String readAccessToken(Map<String, dynamic> outer) {
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

  String? readRefreshToken(Map<String, dynamic> outer) {
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

  bool isUnauthorizedStatus(int? status) {
    return status == 401 || status == 403;
  }

  bool isRateLimitedStatus(int? status) {
    return status == 429;
  }

  bool isSafeSessionResetStatus(int? status) {
    return status == 401 || status == 403;
  }

  bool isTransportRetryable(DioException err) {
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout;
  }

  Future<void> clearSessionState() async {
    await ref.read(tokenStoreProvider).clearTokens();
    ref.invalidate(sessionBootstrapProvider);
    ref.invalidate(authStatusProvider);
  }

  Future<void>? refreshInFlight;

  // Per-host rate-limit gate: populated on 429, cleared when expiry passes.
  final rateLimitedUntil = <String, DateTime>{};

  String? hostOf(RequestOptions req) {
    try {
      final base = Uri.tryParse(req.baseUrl);
      return (base != null && base.host.isNotEmpty) ? base.host : null;
    } catch (_) {
      return null;
    }
  }

  bool isAuthEndpoint(RequestOptions o) {
    final path = normalizePath(o.path);
    if (path.startsWith('/auth')) return true;
    if (path.startsWith('/v1/auth')) return true;
    return false;
  }

  bool shouldAttemptRefreshForRequest(RequestOptions req) {
    final method = req.method.toUpperCase();
    final path = normalizePath(req.path);

    if (method == 'GET') return true;

    if (path == '/auth/me' || path == '/me') return true;

    return false;
  }

  bool canAttemptRefreshNow() {
    final store = ref.read(tokenStoreProvider);

    if (!store.isLoaded) return false;

    final boot = ref.read(sessionBootstrapProvider);
    if (boot.isLoading) return false;

    final authStatus = ref.read(authStatusProvider);
    if (authStatus != AuthStatus.authed) return false;

    return true;
  }

  String? featureFromRequest(RequestOptions req) {
    final path = normalizePath(req.path).toLowerCase();
    if (path.contains('/translate') || path.contains('/translation')) {
      return 'translate this post';
    }
    if (path.contains('/repost')) {
      return 'repost this work';
    }
    if (path.contains('/save') || path.contains('/saved')) {
      return 'save this work';
    }
    if (path.contains('/follow')) {
      return 'follow this account';
    }
    if (path.contains('/compose')) {
      return 'continue';
    }
    return null;
  }

  DioException mapDioException(
    DioException err, {
    RequestOptions? requestOptions,
  }) {
    final req = requestOptions ?? err.requestOptions;
    final mapped = AppErrorMapper.from(err, feature: featureFromRequest(req));

    return DioException(
      requestOptions: req,
      response: err.response,
      type: err.type,
      error: mapped,
      message: mapped.message,
    );
  }

  Dio buildRefreshDio() {
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
        validateStatus: (code) => code != null && code < 500,
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

        if (isUnauthorizedStatus(res.statusCode)) {
          throw DioException(
            requestOptions: res.requestOptions,
            response: res,
            type: DioExceptionType.badResponse,
            message: 'Web refresh unauthorized',
          );
        }

        final outer = asMap(res.data);
        final access = readAccessToken(outer);

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

      if (isUnauthorizedStatus(res.statusCode)) {
        throw DioException(
          requestOptions: res.requestOptions,
          response: res,
          type: DioExceptionType.badResponse,
          message: 'Native refresh unauthorized',
        );
      }

      final outer = asMap(res.data);
      final access = readAccessToken(outer);
      final newRefresh = readRefreshToken(outer);

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

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Reject immediately if the host is still in a 429 back-off window.
        final host = hostOf(options);
        if (host != null) {
          final blockedUntil = rateLimitedUntil[host];
          if (blockedUntil != null) {
            if (DateTime.now().isBefore(blockedUntil)) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  message: 'Rate limited — retry after $blockedUntil',
                ),
              );
              return;
            } else {
              rateLimitedUntil.remove(host);
            }
          }
        }

        final store = ref.read(tokenStoreProvider);

        try {
          await store.waitUntilLoaded();
        } catch (_) {}

        options.path = normalizePath(options.path);
        normalizeContentTypeForRequest(options);

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

        if (isRateLimitedStatus(status)) {
          // Parse Retry-After header; default to 60s if absent.
          final retryAfterHeader =
              err.response?.headers.value('retry-after');
          int delaySecs = 60;
          if (retryAfterHeader != null) {
            final parsed = int.tryParse(retryAfterHeader.trim());
            if (parsed != null && parsed > 0) {
              delaySecs = parsed.clamp(10, 300);
            }
          }
          final host = hostOf(err.requestOptions);
          if (host != null) {
            rateLimitedUntil[host] =
                DateTime.now().add(Duration(seconds: delaySecs));
          }
          handler.reject(mapDioException(err));
          return;
        }

        if (isTransportRetryable(err) &&
            req.method.toUpperCase() == 'GET' &&
            req.extra['__retried_transport'] != true) {
          try {
            req.extra['__retried_transport'] = true;
            req.path = normalizePath(req.path);
            normalizeContentTypeForRequest(req);
            await Future<void>.delayed(const Duration(milliseconds: 250));
            final response = await dio.fetch<dynamic>(req);
            handler.resolve(response);
            return;
          } catch (_) {
            handler.reject(mapDioException(err));
            return;
          }
        }

        if (status != 401 || isAuthEndpoint(req)) {
          handler.reject(mapDioException(err));
          return;
        }

        if (!shouldAttemptRefreshForRequest(req)) {
          handler.reject(mapDioException(err));
          return;
        }

        if (!canAttemptRefreshNow()) {
          handler.reject(mapDioException(err));
          return;
        }

        if (req.extra['__retried_after_refresh'] == true) {
          handler.reject(mapDioException(err));
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
          if (newToken == null || newToken.trim().isEmpty) {
            throw Exception(
              'Refresh completed but no access token is available',
            );
          }

          req.extra['__retried_after_refresh'] = true;
          req.path = normalizePath(req.path);
          req.headers['Authorization'] = 'Bearer $newToken';

          normalizeContentTypeForRequest(req);

          final response = await dio.fetch<dynamic>(req);
          handler.resolve(response);
        } catch (refreshError) {
          final refreshStatus = refreshError is DioException
              ? refreshError.response?.statusCode
              : null;

          if (isSafeSessionResetStatus(refreshStatus)) {
            await clearSessionState();
            handler.reject(mapDioException(err));
            return;
          }

          handler.reject(mapDioException(err));
        }
      },
    ),
  );

  return dio;
});
