import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import 'session_providers.dart';

/// Bootstraps session at app start:
/// - Web: attempts /auth/refresh using httpOnly cookie.
/// - Non-web: uses stored refreshToken if accessToken missing.
///
/// This avoids "logged out on hard refresh" and reduces 401 churn.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final store = ref.read(tokenStoreProvider);
  final dio = ref.read(dioProvider);

  // If already have an access token, nothing to do.
  if (store.isAuthed) return;

  try {
    if (kIsWeb) {
      final res = await dio.post('/v1/auth/refresh', data: {});
      final map = (res.data as Map).cast<String, dynamic>();
      final at = (map['accessToken'] as String?) ?? '';
      if (at.isNotEmpty) {
        await store.setTokens(accessToken: at);
      }
      return;
    }

    final rt = store.refreshToken;
    if (rt == null || rt.isEmpty) return;

    final res = await dio.post(
      '/v1/auth/refresh',
      data: {'refreshToken': rt},
      options: Options(headers: {'x-token-transport': 'body'}),
    );
    final map = (res.data as Map).cast<String, dynamic>();
    final at = (map['accessToken'] as String?) ?? '';
    if (at.isEmpty) return;
    final newRt = (map['refreshToken'] as String?);
    await store.setTokens(accessToken: at, refreshToken: newRt);
  } catch (_) {
    // Silent no-op: not logged in, or cookie missing/expired.
    return;
  }
});
