import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../state/token_store.dart';
import 'platform_http_adapter.dart';

/// Simple no-dependency "single flight" gate:
/// If multiple requests hit 401 together, only one refresh runs.
/// Others await the same refresh Future.
class _SingleFlight {
  Future<void>? _inFlight;

  Future<void> run(Future<void> Function() fn) {
    final existing = _inFlight;
    if (existing != null) return existing;

    final completer = Completer<void>();
    _inFlight = completer.future;

    () async {
      try {
        await fn();
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        _inFlight = null;
      }
    }();

    return completer.future;
  }
}

final dioProvider = Provider<Dio>((ref) {
  final tokens = ref.watch(tokenStoreProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      // Important for web cookie refresh:
      extra: <String, dynamic>{
        if (kIsWeb) 'withCredentials': true,
      },
    ),
  );

  // Ensure BrowserHttpClientAdapter uses withCredentials on web.
  configurePlatformHttpAdapter(dio);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Attach access token if present.
        final access = tokens.accessToken;
        if (access != null && access.trim().isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $access';
        }
        handler.next(options);
      },
    ),
  );

  final singleFlight = _SingleFlight();

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (err, handler) async {
        final status = err.response?.statusCode;

        // Only attempt refresh on 401.
        if (status != 401) {
          handler.next(err);
          return;
        }

        // Avoid infinite loops: never refresh if the failing call is auth endpoints.
        final path = err.requestOptions.path;
        final isAuthCall = path.contains('/v1/auth/');
        if (isAuthCall) {
          handler.next(err);
          return;
        }

        try {
          await singleFlight.run(() async {
            // If another request already refreshed and we now have a token, skip refresh.
            final accessNow = tokens.accessToken;
            if (accessNow != null && accessNow.trim().isNotEmpty) return;

            await _refreshSession(ref);
          });

          // Retry original request with new token (or after cookie refresh).
          final opts = err.requestOptions;

          final retryDio = Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              headers: Map<String, dynamic>.from(opts.headers),
              extra: Map<String, dynamic>.from(opts.extra),
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

          configurePlatformHttpAdapter(retryDio);

          // Re-attach new access token if present
          final newAccess = ref.read(tokenStoreProvider).accessToken;
          if (newAccess != null && newAccess.trim().isNotEmpty) {
            retryDio.options.headers['Authorization'] = 'Bearer $newAccess';
          }

          final response = await retryDio.request<dynamic>(
            opts.path,
            data: opts.data,
            queryParameters: opts.queryParameters,
            options: Options(
              method: opts.method,
              headers: retryDio.options.headers,
              responseType: opts.responseType,
              contentType: opts.contentType,
              followRedirects: opts.followRedirects,
              receiveDataWhenStatusError: opts.receiveDataWhenStatusError,
              validateStatus: opts.validateStatus,
            ),
          );

          handler.resolve(response);
        } catch (_) {
          // Refresh failed: clear session and bubble the original 401.
          await ref.read(tokenStoreProvider.notifier).clear();
          handler.next(err);
        }
      },
    ),
  );

  return dio;
});

Future<void> _refreshSession(ProviderRef ref) async {
  final tokens = ref.read(tokenStoreProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      extra: <String, dynamic>{
        if (kIsWeb) 'withCredentials': true,
      },
    ),
  );

  configurePlatformHttpAdapter(dio);

  // Web: refresh token lives in HttpOnly cookie. Just call refresh with credentials.
  // Non-web: if refreshToken exists, send it as body fallback (backend now supports both).
  final body = <String, dynamic>{};
  if (!kIsWeb) {
    final refresh = tokens.refreshToken;
    if (refresh != null && refresh.trim().isNotEmpty) {
      body['refreshToken'] = refresh;
    }
  }

  final res = await dio.post('/v1/auth/refresh', data: body);

  // Expect at least accessToken. refreshToken may or may not be present depending on mode.
  final data = (res.data is Map) ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};

  final access = data['accessToken'] as String?;
  final refresh = data['refreshToken'] as String?;

  if (access == null || access.trim().isEmpty) {
    throw StateError('Refresh did not return accessToken');
  }

  // Save access always. Save refresh only if returned (mobile mode).
  await ref.read(tokenStoreProvider.notifier).setTokens(
        accessToken: access,
        refreshToken: refresh ?? tokens.refreshToken,
      );
}