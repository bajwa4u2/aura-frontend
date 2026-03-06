import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/auth_providers.dart';

bool _isPublicLikeStartupPath(String path) {
  if (path.isEmpty || path == '/' || path == '/public') return true;

  const exact = <String>{
    '/mission',
    '/white-paper',
    '/founder',
    '/privacy',
    '/contact',
    '/investors',
    '/institutions',
    '/institution/sign-in',
    '/institution/request-verification',
    '/patrons',
    '/supporters',
    '/login',
    '/register',
    '/forgot-password',
    '/reset-password',
    '/verify-email',
    '/verify-pending',
    '/auth',
  };

  if (exact.contains(path)) return true;

  if (path == '/announcements' || path.startsWith('/announcements/')) return true;

  return false;
}

/// Bootstraps session at app start:
/// - Web: attempts /auth/refresh using httpOnly cookie, BUT only for protected/member routes.
/// - Non-web: uses stored refreshToken if accessToken missing.
///
/// Goal:
/// - avoid "logged out on hard refresh" on protected routes
/// - avoid noisy /auth/refresh 401 calls on clearly public startup routes
///
/// IMPORTANT:
/// - Runs at most once per app load.
/// - Uses a dedicated Dio instance with NO interceptors.
/// - Never throws; settles quickly.
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
    } catch (_) {
      // ignore
    }

    // If already authed, nothing to do.
    if (store.isAuthed) return;

    // WEB-SPECIFIC EARLY EXIT:
    // If the user opens a clearly public/auth route, do not fire refresh on startup.
    // This removes the ugly "Missing refresh token" noise on /public and other public pages.
    if (kIsWeb) {
      final startupPath = Uri.base.path.trim();
      if (_isPublicLikeStartupPath(startupPath)) {
        return;
      }
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

    try {
      if (kIsWeb) {
        final a = bootstrapDio.httpClientAdapter;
        if (a is BrowserHttpClientAdapter) {
          a.withCredentials = true;
        } else {
          bootstrapDio.httpClientAdapter = BrowserHttpClientAdapter()
            ..withCredentials = true;
        }
      }

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

bool _bootstrapDone = false;
Completer<void>? _bootstrapInFlight;