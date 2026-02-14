import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_store.dart';

/// Single source of truth for auth state.
final tokenStoreProvider = ChangeNotifierProvider<TokenStore>((ref) {
  return TokenStore();
});

final isAuthedProvider = Provider<bool>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return store.isAuthed;
});
