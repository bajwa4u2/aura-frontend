import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

/// Whether we consider the current session authenticated.
/// This is derived from TokenStore (source of truth) in session_providers.dart.
final authStateProvider = Provider<bool>((ref) {
  return ref.watch(isAuthedProvider);
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

class AuthController {
  final Ref ref;
  AuthController(this.ref);

  Future<void> register({required String handle, String? displayName}) async {
    final repo = ref.read(authRepositoryProvider);
    final tokens = await repo.register(handle: handle, displayName: displayName);

    await ref.read(tokenStoreProvider).setSession(
          userId: tokens.userId,
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );

    ref.read(isAuthedProvider.notifier).state = true;
  }

  Future<void> login({required String handle, String? deviceId}) async {
    final repo = ref.read(authRepositoryProvider);
    final tokens = await repo.login(handle: handle, deviceId: deviceId);

    await ref.read(tokenStoreProvider).setSession(
          userId: tokens.userId,
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );

    ref.read(isAuthedProvider.notifier).state = true;
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    ref.read(isAuthedProvider.notifier).state = false;
  }
}
