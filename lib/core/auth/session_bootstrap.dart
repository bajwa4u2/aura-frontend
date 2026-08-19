import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../net/platform_http_adapter.dart';
import 'auth_providers.dart';
import 'session_hint.dart';
import 'web_session_restore.dart';

// Session-hint primitives now live in session_hint.dart so BOTH the token
// store (the universal session choke point) and this bootstrap can depend
// on them without an import cycle — see that library for the RC1/F065
// doctrine. Re-exported so existing importers keep working unchanged.
export 'session_hint.dart';

/// Bootstraps session at app start.
///
/// Web:
/// - Always attempts /auth/refresh once per app load using the HttpOnly cookie.
/// - Request transport is configured separately so browser credentials are sent.
///
/// Non-web:
/// - Uses the stored refresh token only when access token is missing/expired.
///
/// Important:
/// - Runs at most once per app load — see the RC9 note below for what
///   "once" actually means now.
/// - Uses a dedicated Dio instance with no interceptors.
/// - Never throws. It always settles.
///
/// RC9 — ONCE PER APP LOAD IS NOT ONCE FOR ALL TIME.
///
/// `_bootstrapDone` is module state, so it survived provider invalidation.
/// A sibling tab signing in published a login event, this tab invalidated
/// `sessionBootstrapProvider` in response — and the rebuilt provider returned
/// on its first line because the flag was still set. The invalidation was a
/// NO-OP, and the comment at the call site ("the bootstrap on the next
/// provider read will pick it up") described something that could not happen.
///
/// The guard is still right for what it was for: one speculative
/// `/auth/refresh` per app load, not one per widget rebuild. What it must not
/// do is outlive an AUTHORITATIVE session change. `resetSessionBootstrap()`
/// separates the two — initialisation stays once, reconstruction stays
/// repeatable — and the cross-tab handler calls it before invalidating.
///
/// The event is a TRIGGER, never the authority: resetting only permits the
/// question to be asked again. The answer still comes from `/auth/refresh`
/// and the canonical session authorities.
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

    // Web: always attempt one /auth/refresh per app load. Skipping it on
    // "public" paths used to seem cheap, but it left a logged-in user landing
    // on /, /u/<handle>, /institutions, /announcements, etc. with no session
    // restored — so the public header rendered "Join | Sign in" and any
    // protected call from those pages (e.g. an authed user opening a profile
    // link from email) failed unauth'd. The request itself is one HTTP round
    // trip and fast-fails with 204/401 when no cookie is present.

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

      /// Cookie-fallback: the current backend returns refresh tokens
      /// ONLY via the `aura_refresh` HttpOnly cookie (Set-Cookie header).
      /// Web auto-persists; desktop Dio does not. Read it here so the
      /// rotated refresh token from a successful bootstrap refresh is
      /// captured into TokenStore. See auth_controller.dart for the
      /// parallel implementation; this duplicate exists because the
      /// bootstrap intentionally runs on a dedicated Dio with no
      /// interceptors and no access to AuthController.
      String? readRefreshFromCookies(Response res) {
        if (kIsWeb) return null;
        try {
          final raw = res.headers.map['set-cookie'];
          if (raw == null || raw.isEmpty) return null;
          for (final line in raw) {
            final firstPair = line.split(';').first.trim();
            final eq = firstPair.indexOf('=');
            if (eq <= 0) continue;
            if (firstPair.substring(0, eq).trim() != 'aura_refresh') continue;
            final value = firstPair.substring(eq + 1).trim();
            if (value.isNotEmpty) return value;
          }
        } catch (_) {}
        return null;
      }

      if (kIsWeb) {
        // RC1 — REFRESH IS NOT NAVIGATION. The hint remains a hygiene
        // optimisation for the one case it was added for (a fresh tab
        // landing on a public page, where asking blindly produces nothing
        // but `401 Missing refresh token` in the console). Everywhere else
        // — a member destination, an unclassified route, an identity
        // ceremony, or a device whose storage cannot be read at all — Aura
        // asks, because skipping states the false premise "not
        // authenticated" and the router then correctly discards a
        // destination the person had every right to keep.
        //
        // `Uri.base` is the address bar: on a reload it is the destination
        // being reconstructed, which is exactly what the decision needs.
        final decision = decideWebSessionRestore(
          status: await readSessionHintStatus(),
          landingPath: Uri.base.path,
        );
        if (!decision.attempt) return;

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
        if (res.statusCode == 401 || res.statusCode == 403) {
          // The cookie is gone (logged out elsewhere, expired, cleared by
          // the user). Forget the hint so a subsequent reload stays silent
          // until the user explicitly signs in again.
          await setSessionHint(false);
          return;
        }

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

      // Body-first, cookie-fallback. The current backend rotates the
      // refresh token via aura_refresh Set-Cookie on a successful
      // refresh; without picking it up, the desktop client keeps using
      // the now-invalidated old refresh token and the NEXT refresh
      // fails 24 hours later — a slow-burn version of the same bug.
      final newRefresh =
          readRefresh(res.data) ?? readRefreshFromCookies(res);
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

/// RC9 — allow session reconstruction to run again after an authoritative
/// session change (a sibling tab signing in or out, a revocation).
///
/// Idempotent, and safe to call while a bootstrap is in flight: the in-flight
/// completer is left alone so concurrent readers still coalesce onto the run
/// already happening, and only the "already done" latch is released. It does
/// NOT itself perform a refresh — the next read of the provider decides that,
/// through the same RC1 rules as any other cold load.
void resetSessionBootstrap() {
  _bootstrapDone = false;
}

/// Test seam: whether a further reconstruction would be attempted at all.
bool debugSessionBootstrapWouldRun() => !_bootstrapDone;

/// Test seam: restore the module latch, so one test cannot leak into another.
void debugSetSessionBootstrapDone(bool value) {
  _bootstrapDone = value;
}
