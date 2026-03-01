import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/auth_providers.dart';
import '../net/platform_http_adapter.dart';

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

void _ensureWebCredentials(Dio d) {
  if (!kIsWeb) return;

  final a = d.httpClientAdapter;
  if (a is BrowserHttpClientAdapter) {
    a.withCredentials = true;
  } else {
    d.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
  }
}

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

  // Only web needs a proactive refresh-on-boot because refresh token is HttpOnly cookie.
  if (!kIsWeb) return;

  final refreshDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (c) => c != null && c >= 200 && c < 300,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  // Keep existing adapter config, then HARD guarantee cookies ride along.
  configureDioForPlatform(refreshDio);
  _ensureWebCredentials(refreshDio);

  try {
    final res = await refreshDio.post('/auth/refresh');
    final raw = res.data;

    if (raw is! Map) return;

    final access = raw['accessToken']?.toString();
    if (access == null || access.trim().isEmpty) return;

    // IMPORTANT:
    // On web, NEVER pass refreshToken: null into your store.
    // Refresh token is in HttpOnly cookie; JS cannot read it.
    await store.setSession(accessToken: access);
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