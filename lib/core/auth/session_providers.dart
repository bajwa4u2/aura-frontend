import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../net/dio_provider.dart';
import 'auth_providers.dart';

/// Auth lifecycle status:
/// - loading: boot/refresh check in progress (DO NOT redirect yet)
/// - authed: access token present / session confirmed
/// - unauthed: session not available
enum AuthStatus { loading, authed, unauthed }

/// Boot controller:
/// Ensures we attempt cookie refresh ONCE on web before declaring unauthed.
/// Prevents the "refresh logs me out" loop.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthStatus>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AuthStatus> {
  AuthController(this._ref) : super(AuthStatus.loading) {
    _boot();
  }

  final Ref _ref;
  bool _booted = false;

  Future<void> _boot() async {
    if (_booted) return;
    _booted = true;

    final store = _ref.read(tokenStoreProvider);

    // 1) Wait for tokens to restore (storage, etc.)
    try {
      await store.waitUntilLoaded();
    } catch (_) {
      // Even if storage restore fails, we still proceed to refresh attempt.
    }

    // 2) If already authed, we're done.
    if (store.isAuthed) {
      state = AuthStatus.authed;
      return;
    }

    // 3) Not authed yet: try a single refresh attempt.
    final ok = await _tryRefreshOnce();

    // 4) Re-evaluate
    final now = _ref.read(tokenStoreProvider);
    if (ok && now.isAuthed) {
      state = AuthStatus.authed;
    } else {
      state = AuthStatus.unauthed;
    }
  }

  Future<bool> _tryRefreshOnce() async {
    try {
      final dio = _ref.read(dioProvider);
      final store = _ref.read(tokenStoreProvider);

      // We intentionally call refresh directly (not relying on 401 interceptor).
      // Web: refresh cookie is HttpOnly and should be sent via withCredentials.
      // Mobile: refresh token may be stored locally and sent in body if backend requires it.
      Response res;

      if (kIsWeb) {
        res = await dio.post('/auth/refresh');
      } else {
        final rt = store.refreshToken;
        if (rt == null || rt.trim().isEmpty) return false;
        res = await dio.post('/auth/refresh', data: {'refreshToken': rt});
      }

      final raw = res.data;
      if (raw is! Map) return false;

      final access = raw['accessToken']?.toString();
      final newRefresh = raw['refreshToken']?.toString();

      if (access == null || access.trim().isEmpty) return false;

      await store.setSession(
        accessToken: access,
        refreshToken: kIsWeb
            ? null
            : ((newRefresh != null && newRefresh.trim().isNotEmpty)
                ? newRefresh
                : store.refreshToken),
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> forceRecheck() async {
    state = AuthStatus.loading;
    _booted = false;
    await _boot();
  }
}

/// Whether tokens have been loaded from storage.
final tokenStoreLoadedProvider = Provider<bool>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return store.isLoaded;
});

/// True only when auth controller confirms authed.
final isAuthedProvider = Provider<bool>((ref) {
  final status = ref.watch(authControllerProvider);
  return status == AuthStatus.authed;
});

/// Use this for routing/guards.
final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authControllerProvider);
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
/// We trigger it whenever TokenStore notifies AND once on subscription.
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
  return true;
});