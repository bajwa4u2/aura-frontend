import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/session_providers.dart';

final dioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionStateProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: session.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
      // Keep Dio throwing on 401 so our interceptor can handle it.
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );

  // Prevent multiple refresh calls racing.
  final refreshLock = Lock();

  bool _isAuthEndpoint(RequestOptions o) {
    final p = o.path;
    // Adjust if your backend has slightly different routes,
    // but keep refresh here.
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
        // Always pull latest token from provider (no stale instance).
        final latest = ref.read(sessionStateProvider);
        final token = latest.accessToken;

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

        // Only treat 401 for non-auth endpoints.
        if (status != 401 || _isAuthEndpoint(req)) {
          handler.next(err);
          return;
        }

        final latestSession = ref.read(sessionStateProvider);
        final refreshToken = latestSession.refreshToken;

        // 🔥 Critical fix:
        // If we have NO refresh token, we must clear stale access token,
        // otherwise router thinks we're authed forever and we loop in 401.
        if (refreshToken == null || refreshToken.trim().isEmpty) {
          await ref.read(tokenStoreProvider).clearTokens();
          handler.next(err);
          return;
        }

        // Prevent infinite refresh retry loops on the same request.
        if (req.extra['__retried_after_refresh'] == true) {
          await ref.read(tokenStoreProvider).clearTokens();
          handler.next(err);
          return;
        }

        try {
          await refreshLock.synchronized(() async {
            // Another request may have refreshed while we waited.
            final now = ref.read(sessionStateProvider);
            final still401Token = now.accessToken;

            // If token changed since request was sent, retry without refreshing again.
            if (still401Token != null &&
                still401Token.trim().isNotEmpty &&
                still401Token != (req.headers['Authorization']?.toString().replaceFirst('Bearer ', ''))) {
              return;
            }

            final refreshDio = Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 30),
                headers: {'Content-Type': 'application/json'},
                validateStatus: (code) => code != null && code >= 200 && code < 300,
              ),
            );

            // IMPORTANT: keep refresh request simple and skip auth refresh on itself
            final res = await refreshDio.post(
              '/auth/refresh',
              data: {'refreshToken': refreshToken},
              options: Options(extra: {'skipAuthRefresh': true}),
            );

            // Envelope tolerant:
            // either { ok:true, data:{ accessToken, refreshToken? } }
            // or { accessToken, refreshToken? }
            dynamic raw = res.data;
            Map<String, dynamic>? m;
            if (raw is Map) m = Map<String, dynamic>.from(raw);

            if (m == null) throw Exception('Unexpected refresh response');

            Map<String, dynamic> payload = m;
            if (payload['ok'] == true && payload['data'] is Map) {
              payload = Map<String, dynamic>.from(payload['data'] as Map);
            }

            final newAccess = payload['accessToken']?.toString();
            final newRefresh = payload['refreshToken']?.toString();

            if (newAccess == null || newAccess.trim().isEmpty) {
              throw Exception('Refresh did not return accessToken');
            }

            // If backend does not rotate refresh token, keep the old one.
            final effectiveRefresh =
                (newRefresh != null && newRefresh.trim().isNotEmpty)
                    ? newRefresh
                    : refreshToken;

            await ref.read(tokenStoreProvider).setSession(
                  accessToken: newAccess,
                  refreshToken: effectiveRefresh,
                );
          });

          // Retry the original request once with the new token.
          final updated = ref.read(sessionStateProvider);
          final newToken = updated.accessToken;

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
          // If refresh fails, we must fall back to clean logged-out state.
          await ref.read(tokenStoreProvider).clearTokens();
          handler.next(err);
          return;
        }
      },
    ),
  );

  return dio;
});

/// Simple async lock (no extra package).
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