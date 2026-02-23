import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/auth_providers.dart';

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
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );

  final refreshLock = Lock();

  bool _isAuthEndpoint(RequestOptions o) {
    final p = o.path;
    return p.contains('/auth/login') ||
        p.contains('/auth/register') ||
        p.contains('/auth/refresh') ||
        p.contains('/auth/forgot') ||
        p.contains('/auth/reset') ||
        p.contains('/auth/resend');
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final store = ref.read(tokenStoreProvider);
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

        final store = ref.read(tokenStoreProvider);
        final refreshToken = store.refreshToken;

        if (refreshToken == null || refreshToken.trim().isEmpty) {
          await store.clearTokens();
          handler.next(err);
          return;
        }

        if (req.extra['__retried_after_refresh'] == true) {
          await store.clearTokens();
          handler.next(err);
          return;
        }

        try {
          await refreshLock.synchronized(() async {
            final refreshDio = Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                headers: {'Content-Type': 'application/json'},
                validateStatus: (c) => c != null && c >= 200 && c < 300,
              ),
            );

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
              refreshToken:
                  (newRefresh != null && newRefresh.isNotEmpty)
                      ? newRefresh
                      : refreshToken,
            );
          });

          final newToken = ref.read(tokenStoreProvider).accessToken;

          final cloned = await dio.request<dynamic>(
            req.path,
            data: req.data,
            queryParameters: req.queryParameters,
            options: Options(
              method: req.method,
              headers: Map<String, dynamic>.from(req.headers)
                ..['Authorization'] = 'Bearer $newToken',
              extra: Map<String, dynamic>.from(req.extra)
                ..['__retried_after_refresh'] = true,
            ),
          );

          handler.resolve(cloned);
          return;
        } catch (_) {
          await store.clearTokens();
          handler.next(err);
          return;
        }
      },
    ),
  );

  return dio;
});

class Lock {
  Future<void> _tail = Future.value();

  Future<T> synchronized<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}