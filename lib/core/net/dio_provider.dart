import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/auth_providers.dart';
import '../auth/session_bootstrap.dart';
import '../auth/session_providers.dart';
import '../client_identity/client_identity_provider.dart';
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

  /// Cookie-fallback for refresh-rotation responses. Mirrors the
  /// auth_controller / session_bootstrap helpers — see those files for
  /// rationale. The current backend rotates refresh tokens via
  /// `aura_refresh` Set-Cookie, never in the body. On desktop, the
  /// retry-after-refresh path here must pick the new token up or the
  /// next refresh round fails because we'd send the just-invalidated
  /// old token.
  String? readRefreshTokenFromCookies(Response res) {
    if (kIsWeb) return null;
    try {
      final raw = res.headers.map['set-cookie'];
      if (raw == null || raw.isEmpty) return null;
      // Some native HTTP transports collapse multiple Set-Cookie
      // headers into a single comma-joined string; without splitting
      // that back into individual cookies, we'd miss the rotated
      // `aura_refresh` whenever the backend also set another cookie
      // in the same response — and the next refresh round would then
      // send the just-invalidated old token and the user would be
      // ejected to /login. The regex splits only at a comma that is
      // immediately followed by a cookie-name=value boundary, which
      // never matches a value comma (e.g. dates inside Expires=).
      final boundary = RegExp(r',(?=\s*[A-Za-z_][\w-]*=)');
      final cookies = <String>[
        for (final line in raw) ...line.split(boundary),
      ];
      for (final cookie in cookies) {
        final firstPair = cookie.split(';').first.trim();
        final eq = firstPair.indexOf('=');
        if (eq <= 0) continue;
        if (firstPair.substring(0, eq).trim() != 'aura_refresh') continue;
        final value = firstPair.substring(eq + 1).trim();
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}
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

  // Two-strike guard on `clearSessionState()`. A single refresh 401/403
  // is treated as a transient failure (rotation collision, in-flight
  // refresh racing with another request, momentary backend hiccup) and
  // does NOT sign the user out — the request is rejected but the
  // session is held. Only a SECOND refresh 401/403 within the cooldown
  // window actually clears the session. Reset on any successful retry.
  // Captures the auto-signout pattern observed live where an idle
  // correspondence thread tab flipped authed → unauthed without any
  // user action.
  DateTime? lastRefreshFailureAt;
  const refreshFailureCooldown = Duration(seconds: 30);

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
    // 401 in this codebase is exclusively returned by JwtAuthGuard (Nest's
    // AuthGuard). It runs *before* the controller body, so the request never
    // produced any side effect — refreshing the token and retrying is always
    // safe regardless of HTTP method. The `__retried_after_refresh` flag in
    // the onError handler still prevents an infinite loop. Auth endpoints
    // (/auth/*) are excluded earlier by the caller, so we don't need to gate
    // them here.
    return !isAuthEndpoint(req);
  }

  /// Whether a refresh attempt has any chance of succeeding right now.
  ///
  /// IMPORTANT: do NOT gate on authStatus == authed. The whole point of
  /// refresh-on-401 is to recover when the access token has expired — and an
  /// expired access JWT flips `isAuthed` (and therefore authStatus) to
  /// unauthed. Gating here on authed would self-block the very recovery path
  /// we need.
  ///
  /// Refresh is plausible when we have a credential the backend can use to
  /// mint a new access token:
  /// - web: HttpOnly cookie (Dart can't see it; assume present unless
  ///   bootstrap already proved otherwise this load).
  /// - native: refresh token in storage.
  bool canAttemptRefreshNow() {
    final store = ref.read(tokenStoreProvider);
    if (!store.isLoaded) return false;

    if (kIsWeb) {
      // Cookie-based refresh. The interceptor will downgrade to a clean
      // session reset on 401/403 from /auth/refresh, so it is safe to try.
      return true;
    }

    final rt = store.refreshToken;
    return rt != null && rt.trim().isNotEmpty;
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
      // Body-first, cookie-fallback. See readRefreshTokenFromCookies
      // doc above — backend rotates refresh tokens via aura_refresh
      // Set-Cookie. The retry-after-refresh path here MUST pick that
      // rotated token up or the next refresh fails with the now-
      // invalidated old token.
      final newRefresh =
          readRefreshToken(outer) ?? readRefreshTokenFromCookies(res);

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

        // Wait for session bootstrap to settle so a request fired during the
        // /auth/refresh round-trip on app start does not race past it with no
        // Authorization header — that race is a primary cause of "Sign in to
        // use this feature" leaking into device registration and live-call
        // join while a valid cookie session is being restored.
        //
        // Auth endpoints themselves must not wait on bootstrap (bootstrap
        // performs an /auth/refresh through a separate Dio, and login/refresh
        // run independently of bootstrap).
        if (!isAuthEndpoint(options)) {
          try {
            await ref.read(sessionBootstrapProvider.future);
          } catch (_) {
            // Bootstrap is best-effort — a failure here must not block
            // the request (see the note above).
          }
        }

        options.path = normalizePath(options.path);
        normalizeContentTypeForRequest(options);

        // Canonical client identity headers (Phase 2 release governance).
        // Await the FutureProvider once at startup so even the very first
        // request carries the headers; later reads hit the cached value
        // synchronously. If bootstrap fails (e.g. package_info_plus throws
        // on an unsupported platform) we omit the headers and the backend
        // treats the request as a legacy client with safe defaults.
        try {
          await ref.read(clientIdentityProvider.future);
        } catch (_) {}
        final identity = ref.read(clientIdentitySnapshotProvider);
        if (identity != null) {
          identity.toHttpHeaders().forEach((key, value) {
            options.headers[key] = value;
          });
        }

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
          // Successful retry-after-refresh clears any prior strike so
          // a once-transient failure doesn't pre-arm the signout for
          // a totally unrelated future 401.
          lastRefreshFailureAt = null;
          handler.resolve(response);
        } catch (refreshError) {
          final refreshStatus = refreshError is DioException
              ? refreshError.response?.statusCode
              : null;

          if (isSafeSessionResetStatus(refreshStatus)) {
            final now = DateTime.now();
            final lastFail = lastRefreshFailureAt;
            lastRefreshFailureAt = now;
            if (lastFail != null &&
                now.difference(lastFail) <= refreshFailureCooldown) {
              // Second refresh 401/403 within the cooldown — treat
              // as a real session reset.
              debugPrint(
                '[auth] refresh $refreshStatus twice within '
                '${refreshFailureCooldown.inSeconds}s — clearing session',
              );
              lastRefreshFailureAt = null;
              await clearSessionState();
            } else {
              // First failure within window. Hold the session; the
              // request is still rejected, but the user keeps their
              // tokens and the next request gets another chance.
              debugPrint(
                '[auth] refresh $refreshStatus — first strike, '
                'session held',
              );
            }
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
