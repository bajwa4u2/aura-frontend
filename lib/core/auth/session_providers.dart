import 'dart:async';

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

Map<String, dynamic> _toMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

dynamic _unwrapData(dynamic v) {
  final m = _toMap(v);
  if (m.containsKey('data')) return m['data'];
  return m;
}

/// Fetches and caches the /auth/me response payload.
///
/// Watches tokenStoreProvider directly (not just isAuthedProvider) so it
/// re-fires on ANY token swap — including institution re-login while a
/// personal session is already active.
///
/// Never throws; returns {} on any error. Consumed by emailVerifiedProvider
/// and institutionAccessProvider so /auth/me is called only once per session.
final authMeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final store = ref.watch(tokenStoreProvider);
  if (!store.isAuthed) return {};

  final dio = ref.watch(dioProvider);

  try {
    final res = await dio.get('/auth/me');
    final raw = res.data;

    // unwrap once or twice (handles {data:{data:{...}}})
    final level1 = _unwrapData(raw);
    final level2 = _unwrapData(level1);
    return _toMap(level2);
  } catch (_) {
    return {};
  }
});

/// Email verification / auth validity check.
///
/// Institution accounts (accountType: INSTITUTION) are considered verified —
/// they authenticate via a separate institution login flow and are not subject
/// to the member email verification requirement.
///
/// Critical behavior:
/// - NEVER throw from this provider. If it throws, router can get stuck in
///   error states and the app starts cycling between screens.
final emailVerifiedProvider = FutureProvider<bool>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return false;

  try {
    final inner = await ref.watch(authMeDataProvider.future);

    // Institution accounts bypass email verification entirely.
    final accountType = (inner['accountType'] ?? '').toString().toUpperCase();
    if (accountType == 'INSTITUTION') return true;

    final direct = inner['emailVerified'];
    if (direct is bool) return direct;

    final user = inner['user'];
    if (user is Map) {
      final ev = user['emailVerifiedAt'];
      if (ev != null) return true;
    }

    return false;
  } catch (_) {
    return false;
  }
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
