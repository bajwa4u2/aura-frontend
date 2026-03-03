import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../net/dio_provider.dart';
import 'auth_providers.dart';
import 'session_bootstrap.dart';

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

/// Router/guards helper.
///
/// KEY RULE:
/// If bootstrap is still running, return AuthStatus.loading so router does NOT redirect.
final authStatusProvider = Provider<AuthStatus>((ref) {
  final boot = ref.watch(sessionBootstrapProvider);
  if (boot.isLoading) return AuthStatus.loading;

  final store = ref.watch(tokenStoreProvider);

  if (!store.isLoaded) return AuthStatus.loading;
  if (store.isAuthed) return AuthStatus.authed;
  return AuthStatus.unauthed;
});

/// Email verification status (authed-only).
///
/// Reads /auth/me and extracts:
/// - data.emailVerified (bool), OR
/// - data.user.emailVerifiedAt (presence)
///
/// IMPORTANT:
/// Some endpoints are double-wrapped: { ok:true, data:{ ok:true, data:{...} } }.
/// We unwrap up to 2 levels.
final emailVerifiedProvider = FutureProvider<bool>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return false;

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/auth/me');
  final raw = res.data;

  Map<String, dynamic> toMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, dynamic>{};
  }

  dynamic unwrapData(dynamic v) {
    final m = toMap(v);
    if (m.containsKey('data')) return m['data'];
    return m;
  }

  // unwrap once or twice (handles {data:{data:{...}}})
  final level1 = unwrapData(raw);
  final level2 = unwrapData(level1);

  final inner = toMap(level2);

  final direct = inner['emailVerified'];
  if (direct is bool) return direct;

  final user = inner['user'];
  if (user is Map) {
    final ev = (user as Map)['emailVerifiedAt'];
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