import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../net/dio_provider.dart';

/// Bootstraps session at app start:
/// - Web: attempts /auth/refresh using httpOnly cookie.
/// - Non-web: uses stored refreshToken if accessToken missing.
///
/// Goal: avoid "logged out on hard refresh" without creating refresh storms.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final store = ref.read(tokenStoreProvider);
  final dio = ref.read(dioProvider);

  try {
    await store.waitUntilLoaded();
  } catch (_) {}

  if (store.isAuthed) return;

  try {
    if (kIsWeb) {
      final res = await dio.post(
        '/auth/refresh',
        data: null,
        options: Options(
          contentType: Headers.textPlainContentType,
          headers: const {
            'Content-Type': 'text/plain',
            'Accept': 'application/json',
          },
        ),
      );

      if (res.statusCode == 204) return;

      final raw = res.data;
      if (raw is! Map) return;

      String access = (raw['accessToken'] ?? '').toString().trim();
      if (access.isEmpty && raw['data'] is Map) {
        access = ((raw['data'] as Map)['accessToken'] ?? '').toString().trim();
      }
      if (access.isEmpty) return;

      await store.setSession(accessToken: access);
      return;
    }

    final rt = store.refreshToken;
    if (rt == null || rt.trim().isEmpty) return;

    final res = await dio.post(
      '/auth/refresh',
      data: {'refreshToken': rt},
      options: Options(headers: const {'x-token-transport': 'body'}),
    );

    final raw = res.data;
    if (raw is! Map) return;

    String access = (raw['accessToken'] ?? '').toString().trim();
    if (access.isEmpty && raw['data'] is Map) {
      access = ((raw['data'] as Map)['accessToken'] ?? '').toString().trim();
    }
    if (access.isEmpty) return;

    String? newRefresh = (raw['refreshToken'] ?? '').toString().trim();
    if ((newRefresh.isEmpty) && raw['data'] is Map) {
      newRefresh = ((raw['data'] as Map)['refreshToken'] ?? '').toString().trim();
    }
    if (newRefresh.isEmpty) newRefresh = null;

    await store.setSession(
      accessToken: access,
      refreshToken: newRefresh ?? rt,
    );
  } catch (_) {
    return;
  }
});