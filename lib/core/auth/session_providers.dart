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

/// Email verification status (authed-only).
///
/// Reads /auth/me and extracts:
/// - data.emailVerified (bool), OR
/// - data.user.emailVerifiedAt (presence)
///
/// IMPORTANT:
/// Some endpoints are double-wrapped: { ok:true, data:{ ok:true, data:{...} } }.
/// We unwrap up to 2 levels.
///
/// Critical behavior:
/// - NEVER throw from this provider. If it throws, router can get stuck in error states
///   and the app starts "playing" with screens.
/// - If /auth/me returns 401/403, treat as not authed and settle to false.
final emailVerifiedProvider = FutureProvider<bool>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return false;

  final dio = ref.watch(dioProvider);

  try {
    final res = await dio.get('/auth/me');
    final raw = res.data;

    // unwrap once or twice (handles {data:{data:{...}}})
    final level1 = _unwrapData(raw);
    final level2 = _unwrapData(level1);

    final inner = _toMap(level2);

    final direct = inner['emailVerified'];
    if (direct is bool) return direct;

    final user = inner['user'];
    if (user is Map) {
      final ev = (user as Map)['emailVerifiedAt'];
      if (ev != null) return true;
    }

    return false;
  } on DioException catch (e) {
    final code = e.response?.statusCode;

    // If /auth/me says 401/403, it means current access token is not valid.
    // Do NOT throw. Return false so router doesn't oscillate between states.
    if (code == 401 || code == 403) {
      // On non-web, clearing tokens helps converge the app to UNAUTHED cleanly.
      // On web, refresh might still be cookie-driven; clearing aggressively can cause thrash.
      if (!kIsWeb) {
        try {
          await ref.read(tokenStoreProvider).clearTokens();
        } catch (_) {}
      }
      return false;
    }

    // For any other error (network hiccup, 5xx), be conservative and return false.
    // This avoids "hasError" loops causing UI overlays and redirect thrash.
    return false;
  } catch (_) {
    // Same rule: never throw.
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