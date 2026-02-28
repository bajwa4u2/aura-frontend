import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../net/platform_http_adapter.dart';
import 'auth_providers.dart';

/// Auth lifecycle status:
/// - loading: tokens still being restored from storage / bootstrap in-flight
/// - authed: access token present
/// - unauthed: no access token
enum AuthStatus { loading, authed, unauthed }

/// Whether tokens have been loaded from storage.
final tokenStoreLoadedProvider = Provider<bool>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return store.isLoaded;
});

/// True only when tokens are loaded AND we have an access token.
final isAuthedProvider = Provider<bool>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return store.isLoaded && store.isAuthed;
});

/// Bootstrap auth once on app start:
/// - waits for TokenStore load
/// - if already authed -> done
/// - on web: tries cookie-based refresh to obtain a fresh access token
///
/// IMPORTANT:
/// authStatusProvider watches this provider so GoRouter won't redirect
/// while bootstrap is running (prevents logout-on-refresh loops).
final authBootstrapProvider = FutureProvider<void>((ref) async {
  final store = ref.read(tokenStoreProvider);

  // Ensure local storage / token cache has finished initializing.
  try {
    await store.waitUntilLoaded();
  } catch (_) {
    // If store load fails, just continue; routing will treat as unauthed.
    return;
  }

  // If we already have an access token, nothing to do.
  if (store.isAuthed) return;

  // Web: we rely on HttpOnly refresh cookie. Try to refresh on boot.
  // Non-web: refresh token may be stored; your dio_provider already handles
  // refresh on 401 using stored refresh token, so we don't force it here.
  if (!kIsWeb) return;

  final refreshDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // Keep it strict; anything outside 2xx throws.
      validateStatus: (c) => c != null && c >= 200 && c < 300,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  // Web needs cookies included for refresh.
  configureDioForPlatform(refreshDio);

  try {
    final res = await refreshDio.post('/auth/refresh');
    final raw = res.data;

    if (raw is! Map) return;

    final access = raw['accessToken']?.toString();
    if (access == null || access.trim().isEmpty) return;

    // On web we do NOT store refresh token in JS storage.
    await store.setSession(accessToken: access, refreshToken: null);
  } catch (_) {
    // If refresh cookie missing/expired, we simply remain unauthed.
    return;
  }
});

/// Use this for routing/guards.
///
/// KEY RULE:
/// If bootstrap is still running, return AuthStatus.loading so router does NOT redirect.
final authStatusProvider = Provider<AuthStatus>((ref) {
  // Watch bootstrap so router waits during refresh attempt.
  final boot = ref.watch(authBootstrapProvider);
  if (boot.isLoading) return AuthStatus.loading;

  final store = ref.watch(tokenStoreProvider);

  if (!store.isLoaded) return AuthStatus.loading;
  if (store.isAuthed) return AuthStatus.authed;
  return AuthStatus.unauthed;
});

/// Derived session values used by Dio and other layers.
class SessionState {
  SessionState({
    required this.baseUrl,
    this.accessToken,
    this.refreshToken,
  });

  final String baseUrl;
  final String? accessToken;
  final String? refreshToken;
}

final sessionStateProvider = Provider<SessionState>((ref) {
  final store = ref.watch(tokenStoreProvider);

  return SessionState(
    baseUrl: AppConfig.apiBaseUrl,
    accessToken: store.accessToken,
    refreshToken: store.refreshToken,
  );
});

/// A simple auth "event bus" for GoRouter refresh.
/// We trigger it whenever TokenStore notifies.
final authEventsProvider = StreamProvider<void>((ref) {
  final controller = StreamController<void>.broadcast();

  void emit() {
    if (!controller.isClosed) controller.add(null);
  }

  // Emit once on subscription so routers refresh on boot.
  emit();

  final store = ref.watch(tokenStoreProvider);

  void listener() => emit();
  store.addListener(listener);

  ref.onDispose(() {
    store.removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

/// True if the current user has verified their email.
///
/// During stabilization, keep this permissive to avoid redirect loops.
/// Once everything is stable, we can fetch /auth/me or /users/me here.
final emailVerifiedProvider = FutureProvider<bool>((ref) async {
  final status = ref.watch(authStatusProvider);

  // If not authed, verification shouldn't block anything.
  if (status != AuthStatus.authed) return true;

  // Stabilization posture: treat authed as verified for now.
  // (Backend still enforces verification where required.)
  return true;
});