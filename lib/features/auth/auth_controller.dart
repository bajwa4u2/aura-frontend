import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';
import 'auth_repository.dart';

/// Repo provider (single place to construct AuthRepository).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.read(dioProvider);
  return AuthRepository(dio);
});

/// Simple global loading flag for auth actions.
/// (Screens that do `ref.read(authLoadingProvider.notifier)` will work.)
final authLoadingProvider = StateProvider<bool>((ref) => false);

/// Canonical controller provider used across screens.
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

class AuthController {
  AuthController(this.ref);

  final Ref ref;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    ref.read(authLoadingProvider.notifier).state = true;

    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.login(email: email, password: password);

      final accessToken = res['accessToken']?.toString();
      final refreshToken = res['refreshToken']?.toString();

      if (accessToken == null || accessToken.isEmpty || refreshToken == null || refreshToken.isEmpty) {
        throw Exception('Login response missing tokens');
      }

      final store = ref.read(tokenStoreProvider);
      await store.setTokens(accessToken: accessToken, refreshToken: refreshToken);
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? handle,
    String? displayName,
  }) async {
    ref.read(authLoadingProvider.notifier).state = true;

    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.register(
        email: email,
        password: password,
        handle: handle,
        displayName: displayName,
      );

      final accessToken = res['accessToken']?.toString();
      final refreshToken = res['refreshToken']?.toString();

      // Some backends return tokens immediately on register, some don't.
      // If tokens exist, persist them; otherwise, just return.
      if (accessToken != null &&
          accessToken.isNotEmpty &&
          refreshToken != null &&
          refreshToken.isNotEmpty) {
        final store = ref.read(tokenStoreProvider);
        await store.setTokens(accessToken: accessToken, refreshToken: refreshToken);
      }
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  Future<void> logout() async {
    ref.read(authLoadingProvider.notifier).state = true;
    try {
      final store = ref.read(tokenStoreProvider);
      await store.clear();
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }
}
