import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../auth/auth_providers.dart';

/// Bootstraps session at app start:
/// - Web: attempts /auth/refresh using httpOnly cookie.
/// - Non-web: uses stored refreshToken if accessToken missing.
///
/// Goal: avoid "logged out on hard refresh" without creating refresh storms.
///
/// IMPORTANT:
/// - Uses a dedicated Dio instance with NO interceptors.
/// - Never throws; settles quickly.
/// - On web, a 401 is normal on first visit (no cookie). We just return.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final store = ref.read(tokenStoreProvider);

  try {
    await store.waitUntilLoaded();
  } catch (_) {}

  // If already authed, nothing to do.
  if (store.isAuthed) return;

  // Dedicated Dio (no interceptors) to avoid recursion/thrash.
  final bootstrapDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
      },
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );

  if (kIsWeb) {
    final a = bootstrapDio.httpClientAdapter;
    if (a is BrowserHttpClientAdapter) {
      a.withCredentials = true;
    } else {
      bootstrapDio.httpClientAdapter = BrowserHttpClientAdapter()
        ..withCredentials = true;
    }
  }

  Map<String, dynamic> asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  String readAccess(dynamic raw) {
    final m = asMap(raw);

    var access = (m['accessToken'] ?? '').toString().trim();
    if (access.isNotEmpty) return access;

    final data = m['data'];
    if (data is Map) {
      access = (Map<String, dynamic>.from(data)['accessToken'] ?? '')
          .toString()
          .trim();
      if (access.isNotEmpty) return access;
    }

    return '';
  }

  String? readRefresh(dynamic raw) {
    final m = asMap(raw);

    var refresh = (m['refreshToken'] ?? '').toString().trim();
    if (refresh.isNotEmpty) return refresh;

    final data = m['data'];
    if (data is Map) {
      refresh = (Map<String, dynamic>.from(data)['refreshToken'] ?? '')
          .toString()
          .trim();
      if (refresh.isNotEmpty) return refresh;
    }

    return null;
  }

  try {
    if (kIsWeb) {
      // Cookie-based refresh, minimal request.
      final res = await bootstrapDio.post(
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

      // Some backends return 204 for "refreshed but nothing to return".
      if (res.statusCode == 204) return;

      final access = readAccess(res.data);
      if (access.isEmpty) return;

      await store.setSession(accessToken: access);
      return;
    }

    // Non-web: body-based refresh token
    final rt = store.refreshToken;
    if (rt == null || rt.trim().isEmpty) return;

    final res = await bootstrapDio.post(
      '/auth/refresh',
      data: {'refreshToken': rt},
      options: Options(headers: const {'x-token-transport': 'body'}),
    );

    final access = readAccess(res.data);
    if (access.isEmpty) return;

    final newRefresh = readRefresh(res.data);
    await store.setSession(
      accessToken: access,
      refreshToken: (newRefresh != null && newRefresh.trim().isNotEmpty)
          ? newRefresh
          : rt,
    );
  } on DioException catch (_) {
    // On web, 401 here is normal when no cookie exists (first visit / logged out).
    // On non-web, it just means refresh token is missing/expired.
    return;
  } catch (_) {
    return;
  } finally {
    bootstrapDio.close(force: true);
  }
});