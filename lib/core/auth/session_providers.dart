import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../net/dio_provider.dart';
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

/// Web-only: boot refresh using HttpOnly cookie to fetch a fresh access token.
final authBootstrapProvider = FutureProvider<void>((ref) async {
  final store = ref.read(tokenStoreProvider);

  try {
    await store.waitUntilLoaded();
  } catch (_) {
    return;
  }

  if (store.isAuthed) return;
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

  configureDioForPlatform(refreshDio);

  try {
    final res = await refreshDio.post('/auth/refresh');
    final raw = res.data;

    if (raw is! Map) return;

    final access = raw['accessToken']?.toString();
    if (access == null || access.trim().isEmpty) return;

    // IMPORTANT: on web do NOT pass refreshToken:null.
    await store.setSession(accessToken: access);
  } catch (_) {
    return;
  }
});

/// Router/guards helper.
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

/// Email verification status (authed-only).
///
/// Reads /auth/me and extracts emailVerified or emailVerifiedAt.
/// Returns false if unauthed or if response is unexpected.
final emailVerifiedProvider = FutureProvider<bool>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return false;

  final dio = ref.watch(dioProvider);

  final res = await dio.get('/auth/me');
  final raw = res.data;

  // API might be wrapped: { ok:true, data:{...} } or direct map
  Map<String, dynamic>? m;
  if (raw is Map<String, dynamic>) {
    m = raw;
  } else if (raw is Map) {
    m = raw.map((k, v) => MapEntry(k.toString(), v));
  } else {
    return false;
  }

  final inner = (m['data'] is Map) ? m['data'] as Map : m;

  // Preferred: explicit boolean
  final v = inner['emailVerified'];
  if (v is bool) return v;

  // Fallback: emailVerifiedAt presence
  final user = inner['user'];
  if (user is Map) {
    final ev = user['emailVerifiedAt'];
    if (ev != null) return true;
  }

  return false;
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