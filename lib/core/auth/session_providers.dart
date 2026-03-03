import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../net/dio_provider.dart';
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

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
  return null;
}

String? _extractAccessToken(dynamic raw) {
  final m = _asMap(raw);
  if (m == null) return null;

  // 1) top-level accessToken
  final t1 = m['accessToken']?.toString().trim();
  if (t1 != null && t1.isNotEmpty) return t1;

  // 2) wrapped: { ok:true, data:{ accessToken:"..." } }
  final data = m['data'];
  final dm = _asMap(data);
  final t2 = dm?['accessToken']?.toString().trim();
  if (t2 != null && t2.isNotEmpty) return t2;

  return null;
}

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

  // IMPORTANT:
  // Use the shared Dio (dioProvider) because it is the one configured
  // for web cookies/credentials. Creating a new Dio here can drop cookies
  // and cause refresh to return 204/401.
  final dio = ref.read(dioProvider);

  try {
    final res = await dio.post('/auth/refresh');

    // If backend returns 204 (no content) we cannot bootstrap.
    if (res.statusCode == 204) return;

    final access = _extractAccessToken(res.data);
    if (access == null || access.isEmpty) return;

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

  final m = _asMap(raw);
  if (m == null) return false;

  final inner = (m['data'] is Map) ? (m['data'] as Map) : m;

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