import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/auth_providers.dart';

/// Bootstraps session at app start:
/// - Web: attempts /auth/refresh using httpOnly cookie.
/// - Non-web: uses stored refreshToken if accessToken missing.
///
/// Goal: avoid "logged out on hard refresh" without creating refresh storms.
///
/// IMPORTANT (permanent behavior):
/// - This bootstrap MUST run at most once per app load.
/// - Even if the provider is evaluated multiple times due to rebuilds,
///   it will coalesce into a single attempt and then become a no-op.
/// - To run again, user must hard refresh the page / restart app (or you
///   can explicitly invalidate it if you add a reset hook later).
///
/// ALSO IMPORTANT:
/// - Uses a dedicated Dio instance with NO interceptors.
/// - Never throws; settles quickly.
/// - On web, a 401 is normal on first visit (no cookie). We just return.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  // ---- One-shot gate (prevents refresh storms) ----
  //
  // Why global? Because if the provider gets re-created or re-listened to,
  // this still guarantees "one attempt per app load".
  if (_bootstrapDone) return;

  // If a bootstrap is already running, await it.
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

    // Dedicated Dio (no interceptors) to avoid recursion/thrash.
    final bootstrapDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Accept': 'application/json',
        },
        // IMPORTANT:
        // Allow non-2xx through without throwing so we can "return quietly"
        // on 401 (no cookie) instead of generating exceptions repeatedly.
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
        // Cookie-based refresh, minimal request.
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

        // 204 = nothing to do
        if (res.statusCode == 204) return;

        // 401/403 is normal when no cookie exists (logged out / first visit).
        if (res.statusCode == 401 || res.statusCode == 403) return;

        final access = readAccess(res.data);
        if (access.isEmpty) return;

        await store.setSession(accessToken: access);
        return;
      }

      // Non-web: body-based refresh token
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
    // Never throw from bootstrap
    return;
  } finally {
    // Mark done regardless of outcome: prevents repeated storms.
    _bootstrapDone = true;

    // Release anyone awaiting the in-flight attempt.
    final c = _bootstrapInFlight;
    _bootstrapInFlight = null;
    if (c != null && !c.isCompleted) c.complete();
  }
});

/// Global one-shot guard to prevent refresh storms.
/// (Intentionally survives provider re-evaluation / rebuild churn.)
bool _bootstrapDone = false;
Completer<void>? _bootstrapInFlight;