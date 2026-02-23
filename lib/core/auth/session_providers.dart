import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import 'token_store.dart';

/// Auth lifecycle status:
/// - loading: tokens still being restored from storage
/// - authed: access token present
/// - unauthed: no access token
enum AuthStatus { loading, authed, unauthed }

/// Single source of truth for tokens/auth state.
/// NOTE: main.dart can override this provider with a preloaded TokenStore.
final tokenStoreProvider = ChangeNotifierProvider<TokenStore>((ref) {
  final store = TokenStore();

  // If main.dart didn't override, still try to load (non-blocking).
  // Never block app startup.
  store.load();

  return store;
});

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

/// Use this for routing/guards.
final authStatusProvider = Provider<AuthStatus>((ref) {
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
/// During Auth Stabilization (Mode B cookie refresh), we intentionally avoid
/// network-based verification checks here to prevent circular dependencies and
/// redirect loops. Server-side still enforces verification where required.
///
/// Once auth is stable, we can re-introduce a verified check via /v1/users/me
/// in a separate layer.
final emailVerifiedProvider = FutureProvider<bool>((ref) async {
  return true;
});