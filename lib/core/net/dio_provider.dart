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
        if (session.accessToken != null) 'Authorization': 'Bearer ${session.accessToken}',
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

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = ref.read(sessionStateProvider);
    if (session.accessToken != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final status = err.response?.statusCode;
    final path = req.path;

    // If backend blocks unverified users, bubble a distinct error so the UI can redirect.
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

    // Only handle 401 refresh here
    if (status != 401) {
      handler.next(err);
      return;
    }

    // Don't attempt refresh for auth endpoints
    if (path.startsWith('/v1/auth/login') ||
        path.startsWith('/v1/auth/register') ||
        path.startsWith('/v1/auth/refresh') ||
        path.startsWith('/v1/auth/logout') ||
        path.startsWith('/v1/auth/verify-email') ||
        path.startsWith('/v1/auth/resend-verification')) {
      handler.next(err);
      return;
    }

    final session = ref.read(sessionStateProvider);
    final refreshToken = session.refreshToken;
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

    // retry original request with new token
    final updated = ref.read(sessionStateProvider);
    final newRes = await _retry(req, updated.accessToken);
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

    // TokenStore is the source of truth.
    final store = ref.read(tokenStoreProvider);
    await store.setTokens(accessToken: accessToken, refreshToken: newRefreshToken);
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions, String? accessToken) {
    final opts = Options(
      method: requestOptions.method,
      headers: Map<String, dynamic>.from(requestOptions.headers),
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      followRedirects: requestOptions.followRedirects,
      validateStatus: requestOptions.validateStatus,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
    );

    if (accessToken != null && accessToken.isNotEmpty) {
      opts.headers ??= {};
      opts.headers!['Authorization'] = 'Bearer $accessToken';
    }

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
