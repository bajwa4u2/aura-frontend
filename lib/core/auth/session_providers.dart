import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
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

Map<String, dynamic> _unwrapApiMap(dynamic data) {
  if (data is Map) {
    final m = Map<String, dynamic>.from(data as Map);
    final inner = m['data'] ?? m['user'];
    if (inner is Map) return Map<String, dynamic>.from(inner as Map);
    return m;
  }
  throw Exception('Unexpected response');
}

/// True if the current user has verified their email.
/// Uses GET /v1/auth/me (JWT protected).
final emailVerifiedProvider = FutureProvider<bool>((ref) async {
  final isAuthed = ref.watch(isAuthedProvider);
  if (!isAuthed) return true; // no need to gate when not logged in

  final dio = ref.read(dioProvider);
  final res = await dio.get('/auth/me');

  final user = _unwrapApiMap(res.data);
  return user['emailVerifiedAt'] != null;
});
