import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../auth/token_store.dart';

/// ✅ Canonical routing rule (LOCKED):
/// - Dio baseUrl ALWAYS includes `/v1`.
/// - All request paths across the app MUST be written WITHOUT `/v1`.
///   Example: dio.get('/users/me')  ✅
///   NOT:     dio.get('/users/me') ❌
///
/// Why: eliminates random 404s from mixed conventions.
final dioProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);

  // Explicit override (dev/local) via:
  // flutter run --dart-define=API_BASE_URL=http://localhost:3000
  final configured = const String.fromEnvironment('API_BASE_URL', defaultValue: '').trim();

  // Default for every mode (debug/release/web) unless explicitly overridden.
  const prodDefault = 'https://api.aura.bajwadynesty.us';

  final baseRoot = configured.isNotEmpty ? configured : prodDefault;

  // Base URL is ALWAYS .../v1
  final baseUrl = _normalizeApiV1BaseUrl(baseRoot);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (kIsWeb) {
    final adapter = dio.httpClientAdapter;
    if (adapter is BrowserHttpClientAdapter) {
      adapter.withCredentials = true;
    }
  }

  dio.interceptors.add(
    LogInterceptor(
      request: true,
      requestHeader: false,
      requestBody: false,
      responseHeader: false,
      responseBody: false,
      error: true,
      logPrint: (o) => debugPrint(o.toString()),
    ),
  );

  dio.interceptors.add(_AuthInterceptor(tokenStore: tokenStore));

  return dio;
});

/// Returns a clean API base that ALWAYS ends with `/v1`.
/// Accepts:
/// - https://host
/// - https://host/
/// - https://host/v1
/// - https://host/
/// and normalizes all to:
/// - https://host/v1
String _normalizeApiV1BaseUrl(String raw) {
  var u = raw.trim();
  if (u.isEmpty) return u;

  // Trim trailing slashes
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }

  // If user passed /v1 already, remove it (we’ll add back cleanly)
  if (u.endsWith('/v1')) {
    u = u.substring(0, u.length - 3);
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
  }

  return '$u/v1';
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({required this.tokenStore});

  final TokenStore tokenStore;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenStore.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    // With baseUrl = .../v1, request paths should be like `/auth/login`.
    if (status == 401 && !path.contains('/auth/login')) {
      await tokenStore.clear();
    }

    handler.next(err);
  }
}
