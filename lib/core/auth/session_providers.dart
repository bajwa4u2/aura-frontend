import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../net/dio_provider.dart';
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
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return true; // public routes should not be gated by verification

  final dio = ref.read(dioProvider);
  final res = await dio.get('/v1/auth/me');

  final user = _unwrapApiMap(res.data);
  return user['emailVerifiedAt'] != null || user['emailVerified'] == true;
});
