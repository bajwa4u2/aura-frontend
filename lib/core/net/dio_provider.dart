import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';

class EmailNotVerifiedException implements Exception {
  EmailNotVerifiedException([this.message = 'Email not verified']);
  final String message;
  @override
  String toString() => 'EmailNotVerifiedException: $message';
}

final dioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionStateProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: session.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(_AuthInterceptor(ref, dio));
  return dio;
});

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this.ref, this.dio);

  final Ref ref;
  final Dio dio;

  Future<void>? _refreshing;

  bool _isAuthPath(String path) {
    return path.startsWith('/v1/auth/login') ||
        path.startsWith('/v1/auth/register') ||
        path.startsWith('/v1/auth/refresh') ||
        path.startsWith('/v1/auth/logout') ||
        path.startsWith('/v1/auth/verify-email') ||
        path.startsWith('/v1/auth/resend-verification') ||
        path.startsWith('/v1/auth/resend-email-verification');
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // TokenStore is source of truth. Always wait until it is loaded on web.
    final store = ref.read(tokenStoreProvider);
    await store.waitUntilLoaded();

    final accessToken = store.accessToken;
    if (accessToken != null && accessToken.trim().isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${accessToken.trim()}';
    } else {
      options.headers.remove('Authorization');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final status = err.response?.statusCode;
    final path = req.path;

    // Bubble a distinct error so the UI can redirect if backend blocks unverified.
    if (status == 403) {
      final data = err.response?.data;
      if (data is Map && data['code'] == 'EMAIL_NOT_VERIFIED') {
        handler.reject(
          DioException(
            requestOptions: req,
            response: err.response,
            type: err.type,
            error: EmailNotVerifiedException(data['message']?.toString() ?? 'Email not verified'),
          ),
        );
        return;
      }
    }

    // Only handle 401 refresh here.
    if (status != 401) {
      handler.next(err);
      return;
    }

    // Don't attempt refresh for auth endpoints.
    if (_isAuthPath(path)) {
      handler.next(err);
      return;
    }

    // TokenStore is the source of truth.
    final store = ref.read(tokenStoreProvider);
    await store.waitUntilLoaded();

    final refreshToken = store.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      handler.next(err);
      return;
    }

    _refreshing ??= _doRefresh(refreshToken);

    try {
      await _refreshing;
    } catch (_) {
      _refreshing = null;
      handler.next(err);
      return;
    }

    _refreshing = null;

    // Retry original request with the new token.
    final updatedStore = ref.read(tokenStoreProvider);
    await updatedStore.waitUntilLoaded();

    final newRes = await _retry(req, updatedStore.accessToken);
    handler.resolve(newRes);
  }

  Future<void> _doRefresh(String refreshToken) async {
    final res = await dio.post('/v1/auth/refresh', data: {'refreshToken': refreshToken});
    final data = res.data;

    if (data is! Map) throw Exception('Unexpected refresh response');

    final accessToken = data['accessToken']?.toString();
    final newRefreshToken = data['refreshToken']?.toString();

    if (accessToken == null || accessToken.isEmpty || newRefreshToken == null || newRefreshToken.isEmpty) {
      throw Exception('Invalid refresh response');
    }

    final store = ref.read(tokenStoreProvider);
    await store.setTokens(accessToken: accessToken, refreshToken: newRefreshToken);
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions, String? accessToken) {
    final headers = Map<String, dynamic>.from(requestOptions.headers);

    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    } else {
      headers.remove('Authorization');
    }

    final opts = Options(
      method: requestOptions.method,
      headers: headers,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      followRedirects: requestOptions.followRedirects,
      validateStatus: requestOptions.validateStatus,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
    );

    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: opts,
      cancelToken: requestOptions.cancelToken,
      onSendProgress: requestOptions.onSendProgress,
      onReceiveProgress: requestOptions.onReceiveProgress,
    );
  }
}