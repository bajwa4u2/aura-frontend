// lib/core/net/dio_provider.dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart'; // tokenStoreProvider lives here
import '../auth/token_store.dart';

final dioProvider = Provider<Dio>((ref) {
  ref.watch(tokenStoreProvider);

  final configured = const String.fromEnvironment('API_BASE_URL', defaultValue: '').trim();
  const prodDefault = 'https://api.aura.bajwadynesty.us';
  final baseRoot = configured.isNotEmpty ? configured : prodDefault;

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

  if (kIsWeb) {
    final adapter = dio.httpClientAdapter;
    if (adapter is BrowserHttpClientAdapter) {
      adapter.withCredentials = true;
    }
  }

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

  dio.interceptors.add(_AuthInterceptor(dio: dio, ref: ref));

  return dio;
});

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

Map<String, dynamic> _unwrapSuccessEnvelope(dynamic payload) {
  if (payload is! Map) throw Exception('Unexpected response');
  final m = Map<String, dynamic>.from(payload as Map);

  // Canonical: { success: true, data: ... }
  if (m['success'] == true) {
    final inner = m['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner as Map);
    throw Exception('Unexpected success envelope: data is not a map');
  }

  // Legacy: { data: ... }
  final inner = m['data'];
  if (inner is Map) return Map<String, dynamic>.from(inner as Map);

  return m;
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
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.path.startsWith('/v1/')) {
      options.path = options.path.substring(3);
    } else if (options.path == '/v1') {
      options.path = '/';
    }

    final store = _tokenStore;
    if (!store.isLoaded) {
      await store.waitUntilLoaded();
    }

    final token = (store.accessToken ?? '').trim();
    if (token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
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

    if (!tokenStore.isAuthed) {
      await tokenStore.clear();
      return handler.next(err);
    }

    final alreadyRetried = (req.extra['aura_retried'] == true);
    if (alreadyRetried) {
      await tokenStore.clear();
      return handler.next(err);
    }

    try {
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

    final map = _unwrapSuccessEnvelope(refreshRes.data);

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
