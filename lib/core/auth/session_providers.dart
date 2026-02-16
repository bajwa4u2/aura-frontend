import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_store.dart';

/// Auth lifecycle status:
/// - loading: tokens still being restored from storage
/// - authed: access token present
/// - unauthed: no access token
enum AuthStatus { loading, authed, unauthed }

/// Single source of truth for auth state.
final tokenStoreProvider = ChangeNotifierProvider<TokenStore>((ref) {
  final store = TokenStore();

  // Load persisted tokens ASAP (non-blocking).
  // IMPORTANT: do NOT assume the result is available immediately.
  store.load();

  return store;
});

/// Whether tokens have been loaded from storage (SharedPreferences).
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
/// It prevents "false unauthed" during app startup.
final authStatusProvider = Provider<AuthStatus>((ref) {
  final store = ref.watch(tokenStoreProvider);

  if (!store.isLoaded) return AuthStatus.loading;
  if (store.isAuthed) return AuthStatus.authed;
  return AuthStatus.unauthed;
});
