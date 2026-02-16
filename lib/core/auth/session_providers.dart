import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_store.dart';

/// Single source of truth for auth state.
final tokenStoreProvider = ChangeNotifierProvider<TokenStore>((ref) {
  final store = TokenStore();
  // Load persisted tokens ASAP (non-blocking). TokenStore will notifyListeners().
  store.load();
  return store;
});

/// Useful for gating UI / protected calls until tokens are loaded from storage.
final tokenStoreLoadedProvider = Provider<bool>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return store.isLoaded;
});

final isAuthedProvider = Provider<bool>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return store.isAuthed;
});
