import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config.dart';
import '../net/platform_http_adapter.dart';
import 'auth_providers.dart';

/// Persistent flag that records "this device has had a successful login."
/// Set by `auth_controller.login` / `verifyLoginCode` on successful session
/// establishment, cleared by `auth_controller.logout`. The web bootstrap
/// reads this before firing `/auth/refresh` so a fresh-tab visitor on a
/// public route never produces a `401 Missing refresh token` console line.
const String kSessionHintPrefKey = 'aura_session_hint';

/// Companion timestamp of when the hint was last set. The web bootstrap
/// uses this to skip `/auth/refresh` when the hint is older than the
/// refresh-cookie max-age window — by then the cookie has expired and
/// retrying just produces a guaranteed 401. Stored as ISO-8601 millis.
const String kSessionHintAtPrefKey = 'aura_session_hint_at';

/// Refresh-cookie max-age set by the backend (`auth.controller.ts`):
/// 60 * 60 * 24 * 30 seconds = 30 days. We treat any hint older than this
/// as expired locally so the bootstrap stays silent.
const Duration kSessionHintMaxAge = Duration(days: 30);

Future<bool> _hasSessionHint() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final flag = prefs.getBool(kSessionHintPrefKey) ?? false;
    if (!flag) return false;
    // Honor the timestamp gate when present. Older entries (set before this
    // upgrade) carry no timestamp; treat them as valid so existing users do
    // not get logged out. The next successful login refreshes the timestamp.
    final at = prefs.getInt(kSessionHintAtPrefKey);
    if (at == null) return true;
    final age = DateTime.now().millisecondsSinceEpoch - at;
    if (age < 0 || age > kSessionHintMaxAge.inMilliseconds) return false;
    return true;
  } catch (_) {
    // SharedPreferences can throw in private-browsing mode; assume no hint.
    return false;
  }
}

Future<void> setSessionHint(bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(kSessionHintPrefKey, true);
      await prefs.setInt(
        kSessionHintAtPrefKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(kSessionHintPrefKey);
      await prefs.remove(kSessionHintAtPrefKey);
    }
  } catch (_) {
    // best-effort
  }
}

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

      if (kIsWeb) {
        // Public-route hygiene: skip the speculative refresh entirely when
        // there is no record of a prior successful sign-in on this device.
        // Without this, every fresh-tab landing on /, /public, /privacy etc.
        // produced a `POST /v1/auth/refresh 401 Missing refresh token`
        // console line because the HttpOnly cookie can't be read from Dart
        // and the bootstrap had to ask blindly. The hint flag closes that
        // gap for users who have never authenticated on this browser; users
        // who have signed in keep the cookie-based silent refresh.
        final hasHint = await _hasSessionHint();
        if (!hasHint) return;

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
