import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import '../auth/auth_providers.dart';

/// Bootstraps session at app start:
/// - Web: attempts /auth/refresh using httpOnly cookie.
/// - Non-web: uses stored refreshToken if accessToken missing.
///
/// This avoids "logged out on hard refresh" and reduces 401 churn.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final store = ref.read(tokenStoreProvider);
  final dio = ref.read(dioProvider);

  // Ensure persisted tokens are loaded before making decisions.
  try {
    await store.waitUntilLoaded();
  } catch (_) {
    // If store fails to load, don't block boot.
  }

  // If already have an access token, nothing to do.
  if (store.isAuthed) return;

  try {
    if (kIsWeb) {
      // Web refresh uses HttpOnly cookie; no body refreshToken needed.
      final res = await dio.post('/auth/refresh', data: {});
      final raw = res.data;

      if (raw is! Map) return;

      final access = raw['accessToken']?.toString() ?? '';
      if (access.isEmpty) return;

      // Web: keep refresh token null (cookie-managed).
      await store.setSession(accessToken: access, refreshToken: null);
      return;
    }

    // Non-web: send refreshToken in body.
    final rt = store.refreshToken;
    if (rt == null || rt.trim().isEmpty) return;

    final res = await dio.post(
      '/auth/refresh',
      data: {'refreshToken': rt},
      options: Options(headers: const {'x-token-transport': 'body'}),
    );

    final raw = res.data;
    if (raw is! Map) return;

    final access = raw['accessToken']?.toString() ?? '';
    if (access.isEmpty) return;

    final newRefresh = raw['refreshToken']?.toString();
    await store.setSession(
      accessToken: access,
      refreshToken: (newRefresh != null && newRefresh.isNotEmpty) ? newRefresh : rt,
    );
  } catch (_) {
    // Silent no-op: not logged in, or cookie missing/expired.
    return;
  }
});