import 'dart:async';

import 'package:dio/dio.dart';
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
      // Keep 2xx-only so 401 becomes an error and flows through onError refresh logic.
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );

  // Web needs cookies (HttpOnly refresh cookie) to be included on requests.
  configureDioForPlatform(dio);

  // Single-flight refresh gate:
  // multiple 401s will wait on the same refresh Future.
  Future<void>? refreshInFlight;

  bool isAuthEndpoint(RequestOptions o) {
    final p = o.path;
    return p.contains('/auth/login') ||
        p.contains('/auth/register') ||
        p.contains('/auth/verify-email') ||
        p.contains('/auth/resend-verification') ||
        p.contains('/auth/forgot-password') ||
        p.contains('/auth/reset-password') ||
        p.contains('/auth/refresh') ||
        p.contains('/auth/logout');
  }

  bool shouldClearTokensOnRefreshFailure(Object error) {
    // Only clear tokens when we are confident the session is invalid.
    // Network / timeouts should NOT force a logout.
    if (error is DioException) {
      final s = error.response?.statusCode;
      if (s == 401 || s == 403) return true;
      // If server explicitly says token invalid/expired in a structured way, treat as logout.
      final msg = error.message?.toLowerCase() ?? '';
      if (msg.contains('invalid') || msg.contains('unauthorized')) return true;
      return false;
    }
    return false;
  }

  Future<void> performRefresh() async {
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (c) => c != null && c >= 200 && c < 300,
      ),
    );

    configureDioForPlatform(refreshDio);

    if (kIsWeb) {
      // Web: refresh token is in HttpOnly cookie.
      final res = await refreshDio.post('/auth/refresh');
      final raw = res.data;

      if (raw is! Map) throw Exception('Invalid refresh response');

      final access = raw['accessToken']?.toString();
      if (access == null || access.isEmpty) {
        throw Exception('No access token returned');
      }

      // Do NOT store refresh token on web.
      await ref.read(tokenStoreProvider).setSession(
            accessToken: access,
            refreshToken: null,
          );
      return;
    }

    // Non-web: refresh token may be stored and sent in body.
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

    final raw = res.data;
    if (raw is! Map) throw Exception('Invalid refresh response');

    final access = raw['accessToken']?.toString();
    final newRefresh = raw['refreshToken']?.toString();

    if (access == null || access.isEmpty) {
      throw Exception('No access token returned');
    }

    await store.setSession(
      accessToken: access,
      refreshToken: (newRefresh != null && newRefresh.isNotEmpty) ? newRefresh : refreshToken,
    );
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final store = ref.read(tokenStoreProvider);

        // Avoid firing protected calls before tokens are restored from storage.
        try {
          await store.waitUntilLoaded();
        } catch (_) {
          // Don't block forever.
        }

        // Attach access token if present.
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

        if (req.extra['__retried_after_refresh'] == true) {
          // Avoid loops, but do not clear tokens here.
          handler.next(err);
          return;
        }

        try {
          // --- Single-flight refresh ---
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

          // Retry original request with new token.
          final retryHeaders = Map<String, dynamic>.from(req.headers);
          retryHeaders.remove('Authorization');
          if (newToken != null && newToken.trim().isNotEmpty) {
            retryHeaders['Authorization'] = 'Bearer $newToken';
          }

          final cloned = await dio.request<dynamic>(
            req.path,
            data: req.data,
            queryParameters: req.queryParameters,
            options: Options(
              method: req.method,
              headers: retryHeaders,
              extra: Map<String, dynamic>.from(req.extra)
                ..['__retried_after_refresh'] = true,
            ),
          );

          handler.resolve(cloned);
        } catch (e) {
          // Refresh failed:
          // - If it's an actual auth invalidation -> clear tokens (real logout)
          // - If it's network/transient -> keep tokens and bubble error (no forced logout)
          if (shouldClearTokensOnRefreshFailure(e)) {
            await ref.read(tokenStoreProvider).clearTokens();
          }
          handler.next(err);
        }
      },
    ),
  );

  return dio;
});