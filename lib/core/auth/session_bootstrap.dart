import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../net/platform_http_adapter.dart';
import 'auth_providers.dart';

/// Bootstraps session at app start.
///
/// Web:
/// - Attempts /auth/refresh once per app load using the HttpOnly cookie.
/// - Request transport is configured separately so browser credentials are sent.
/// - Skips refresh entirely when the app boots on clearly public/auth surfaces.
///
/// Non-web:
/// - Uses the stored refresh token only when access token is missing.
///
/// Important:
/// - Runs at most once per app load.
/// - Uses a dedicated Dio instance with no interceptors.
/// - Never throws. It always settles.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  if (_bootstrapDone) return;

  final inflight = _bootstrapInFlight;
  if (inflight != null) {
    await inflight.future;
    return;
  }

  final completer = Completer<void>();
  _bootstrapInFlight = completer;

  try {
    final store = ref.read(tokenStoreProvider);

    try {
      await store.waitUntilLoaded();
    } catch (_) {}

    if (store.isAuthed) return;

    if (kIsWeb && _shouldSkipWebBootstrapForPath(Uri.base.path)) {
      return;
    }

    final bootstrapDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Accept': 'application/json',
        },
        validateStatus: (code) => code != null && code >= 200 && code < 500,
      ),
    );

    configureDioForPlatform(bootstrapDio);

    try {
      Map<String, dynamic> asMap(dynamic v) {
        if (v is Map<String, dynamic>) return v;
        if (v is Map) return Map<String, dynamic>.from(v);
        return <String, dynamic>{};
      }

      String readAccess(dynamic raw) {
        final m = asMap(raw);

        var access = (m['accessToken'] ?? '').toString().trim();
        if (access.isNotEmpty) return access;

        final data = m['data'];
        if (data is Map) {
          access = (Map<String, dynamic>.from(data)['accessToken'] ?? '')
              .toString()
              .trim();
          if (access.isNotEmpty) return access;
        }

        return '';
      }

      String? readRefresh(dynamic raw) {
        final m = asMap(raw);

        var refresh = (m['refreshToken'] ?? '').toString().trim();
        if (refresh.isNotEmpty) return refresh;

        final data = m['data'];
        if (data is Map) {
          refresh = (Map<String, dynamic>.from(data)['refreshToken'] ?? '')
              .toString()
              .trim();
          if (refresh.isNotEmpty) return refresh;
        }

        return null;
      }

      if (kIsWeb) {
        final res = await bootstrapDio.post(
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
        if (res.statusCode == 401 || res.statusCode == 403) return;

        final access = readAccess(res.data);
        if (access.isEmpty) return;

        await store.setSession(accessToken: access);
        return;
      }

      final rt = store.refreshToken;
      if (rt == null || rt.trim().isEmpty) return;
      final res = await bootstrapDio.post(
        '/auth/refresh',
        data: {'refreshToken': rt},
        options: Options(headers: const {'x-token-transport': 'body'}),
      );

      if (res.statusCode == 401 || res.statusCode == 403) return;

      final access = readAccess(res.data);
      if (access.isEmpty) return;

      final newRefresh = readRefresh(res.data);
      await store.setSession(
        accessToken: access,
        refreshToken: (newRefresh != null && newRefresh.trim().isNotEmpty)
            ? newRefresh
            : rt,
      );
    } finally {
      bootstrapDio.close(force: true);
    }
  } catch (_) {
    return;
  } finally {
    _bootstrapDone = true;

    final c = _bootstrapInFlight;
    _bootstrapInFlight = null;
    if (c != null && !c.isCompleted) c.complete();
  }
});

bool _shouldSkipWebBootstrapForPath(String path) {
  const exactPublicPaths = <String>{
    '/',
    '/public',
    '/mission',
    '/privacy',
    '/terms',
    '/contact',
    '/investors',
    '/patrons',
    '/supporters',
    '/white-paper',
    '/founder',
    '/login',
    '/register',
    '/forgot-password',
    '/reset-password',
    '/verify-email',
    '/verify-pending',
    '/search',
    '/announcements',
  };

  if (exactPublicPaths.contains(path)) return true;
  if (path.startsWith('/institutions')) return true;
  if (path.startsWith('/announcements/')) return true;
  if (path.startsWith('/u/')) return true;

  return false;
}

bool _bootstrapDone = false;
Completer<void>? _bootstrapInFlight;
