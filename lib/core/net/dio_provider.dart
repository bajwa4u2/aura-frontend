// lib/core/net/dio_provider.dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart'; // tokenStoreProvider lives here
import '../auth/token_store.dart';

/// ✅ Canonical routing rule (LOCKED):
/// - Dio baseUrl ALWAYS includes `/v1`.
/// - All request paths across the app MUST be written WITHOUT `/v1`.
///   Example: dio.get('/users/me')  ✅
///   NOT:     dio.get('/v1/users/me') ❌
///
/// This file also includes a safety guard: if any caller accidentally includes `/v1`,
/// we strip it to prevent `/v1/v1/...` 404s.
final dioProvider = Provider<Dio>((ref) {
  // IMPORTANT:
  // We still "watch" here so when the token store changes, this provider can rebuild
  // if needed. But the interceptor itself must NOT capture a stale instance.
  ref.watch(tokenStoreProvider);

  // Explicit override (dev/local) via:
  // flutter run --dart-define=API_BASE_URL=http://localhost:3000
  final configured = const String.fromEnvironment('API_BASE_URL', defaultValue: '').trim();

  // Default for every mode (debug/release/web) unless explicitly overridden.
  const prodDefault = 'https://api.aura.bajwadynesty.us';

  final baseRoot = configured.isNotEmpty ? configured : prodDefault;

  // Base URL is ALWAYS .../v1
  final baseUrl = _normalizeApiV1BaseUrl(baseRoot);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Web: allow refresh cookie to be sent/received.
  if (kIsWeb) {
    final adapter = dio.httpClientAdapter;
    if (adapter is BrowserHttpClientAdapter) {
      adapter.withCredentials = true;
    }
  }

  // Debug logging:
  // For the 401 issue, requestHeader=true is very useful to confirm Authorization is present.
  dio.interceptors.add(
    LogInterceptor(
      request: true,
      requestHeader: kDebugMode,
      requestBody: false,
      responseHeader: false,
      responseBody: false,
      error: true,
      logPrint: (o) => debugPrint(o.toString()),
    ),
  );

  // ✅ Critical change: pass ref, NOT a captured TokenStore instance.
  dio.interceptors.add(_AuthInterceptor(dio: dio, ref: ref));

  return dio;
});

/// Returns a clean API base that ALWAYS ends with `/v1`.
/// Accepts:
/// - https://host
/// - https://host/
/// - https://host/v1
/// and normalizes all to:
/// - https://host/v1
String _normalizeApiV1BaseUrl(String raw) {
  var u = raw.trim();
  if (u.isEmpty) return u;

  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }

  if (u.endsWith('/v1')) {
    u = u.substring(0, u.length - 3);
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
  }

  return '$u/v1';
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({required this.dio, required this.ref});

  final Dio dio;
  final Ref ref;

  Completer<void>? _refreshCompleter;

  TokenStore get _tokenStore => ref.read(tokenStoreProvider);

  bool _isAuthPath(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/forgot-password') ||
        path.contains('/auth/reset-password') ||
        path.contains('/auth/verify-email') ||
        path.contains('/auth/resend-verification');
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // ✅ SAFETY: Prevent /v1/v1/... if a caller accidentally includes /v1 in the path.
    if (options.path.startsWith('/v1/')) {
      options.path = options.path.substring(3); // "/v1" is 3 chars
    } else if (options.path == '/v1') {
      options.path = '/';
    }

    final token = (_tokenStore.accessToken ?? '').trim();
    if (token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      // Avoid leaving a stale Authorization header around
      options.headers.remove('Authorization');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final req = err.requestOptions;
    final path = req.path;

    if (status != 401 || _isAuthPath(path)) {
      return handler.next(err);
    }

    final tokenStore = _tokenStore;

    // If not authed, clear and continue.
    if (!tokenStore.isAuthed) {
      await tokenStore.clear();
      return handler.next(err);
    }

    // Prevent infinite retry loops
    final alreadyRetried = (req.extra['aura_retried'] == true);
    if (alreadyRetried) {
      await tokenStore.clear();
      return handler.next(err);
    }

    try {
      // If refresh is already running, wait for it.
      if (_refreshCompleter != null) {
        await _refreshCompleter!.future;

        final afterWaitStore = _tokenStore;
        if (!afterWaitStore.isAuthed) {
          await afterWaitStore.clear();
          return handler.next(err);
        }

        final access = (afterWaitStore.accessToken ?? '').trim();
        if (access.isEmpty) {
          await afterWaitStore.clear();
          return handler.next(err);
        }

        final retryRes = await _retryWithAccessToken(req, access);
        return handler.resolve(retryRes);
      }

      _refreshCompleter = Completer<void>();

      final newAccess = await _performRefresh();

      _refreshCompleter?.complete();
      _refreshCompleter = null;

      final retryRes = await _retryWithAccessToken(req, newAccess);
      return handler.resolve(retryRes);
    } catch (_) {
      if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete();
      }
      _refreshCompleter = null;

      await _tokenStore.clear();
      return handler.next(err);
    }
  }

  Future<String> _performRefresh() async {
    final tokenStore = _tokenStore;

    final refreshHeaders = <String, dynamic>{};
    dynamic refreshBody = <String, dynamic>{};

    // Web uses HttpOnly cookie refresh; mobile uses refreshToken in body.
    if (!kIsWeb) {
      final rt = (tokenStore.refreshToken ?? '').trim();
      if (rt.isEmpty) throw const UnauthorizedException('Missing refresh token (non-web)');
      refreshHeaders['x-token-transport'] = 'body';
      refreshBody = {'refreshToken': rt};
    }

    final refreshRes = await dio.post(
      '/auth/refresh',
      data: refreshBody,
      options: refreshHeaders.isEmpty ? null : Options(headers: refreshHeaders),
    );

    final payload = refreshRes.data;
    if (payload is! Map) throw Exception('Unexpected refresh response');

    final map = Map<String, dynamic>.from(payload as Map);

    final newAccess = (map['accessToken'] ?? '').toString().trim();
    if (newAccess.isEmpty) throw Exception('Missing accessToken from refresh');

    final newRefreshRaw = map['refreshToken'];
    final newRefresh = newRefreshRaw == null ? null : newRefreshRaw.toString().trim();

    await tokenStore.setTokens(
      accessToken: newAccess,
      refreshToken: (!kIsWeb && (newRefresh ?? '').isNotEmpty) ? newRefresh : null,
    );

    return newAccess;
  }

  Future<Response<dynamic>> _retryWithAccessToken(RequestOptions req, String accessToken) async {
    final retryOptions = Options(
      method: req.method,
      headers: Map<String, dynamic>.from(req.headers),
      responseType: req.responseType,
      contentType: req.contentType,
      followRedirects: req.followRedirects,
      validateStatus: req.validateStatus,
      receiveDataWhenStatusError: req.receiveDataWhenStatusError,
      extra: Map<String, dynamic>.from(req.extra)..['aura_retried'] = true,
    );

    retryOptions.headers?['Authorization'] = 'Bearer $accessToken';

    return dio.request<dynamic>(
      req.path,
      data: req.data,
      queryParameters: req.queryParameters,
      options: retryOptions,
      cancelToken: req.cancelToken,
      onReceiveProgress: req.onReceiveProgress,
      onSendProgress: req.onSendProgress,
    );
  }
}

class UnauthorizedException implements Exception {
  const UnauthorizedException(this.message);
  final String message;
  @override
  String toString() => message;
}
