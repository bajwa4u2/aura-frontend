import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';

/// A thin controller around the auth endpoints.
///
/// IMPORTANT: This file intentionally owns the provider so screens can just:
///   final auth = ref.read(authControllerProvider);
final authControllerProvider =
    Provider<AuthController>((ref) => AuthController(ref));

class AuthController {
  AuthController(this.ref);

  /// Some screens pass WidgetRef, other layers may pass Ref.
  /// dynamic avoids WidgetRef vs Ref generic mismatch.
  final dynamic ref;

  Dio _dio() => ref.read(dioProvider);
  TokenStore _store() => ref.read(tokenStoreProvider);

  static const List<String> _linkedinStartPathCandidates = <String>[
    '/auth/linkedin/start',
    '/auth/linkedin',
  ];

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    throw Exception('Unexpected response type');
  }

  /// Unwrap common API envelopes:
  /// - { ok: true, data: {...} }
  /// - { data: {...} }
  Map<String, dynamic> _unwrap(dynamic raw) {
    final m = _asMap(raw);

    final data = m['data'];
    if (data is Map) {
      return (data as Map).cast<String, dynamic>();
    }

    return m;
  }

  String _readAccessToken(Map<String, dynamic> outer) {
    final t1 = (outer['accessToken'] ?? '').toString().trim();
    if (t1.isNotEmpty) return t1;

    final t1b = (outer['access_token'] ?? '').toString().trim();
    if (t1b.isNotEmpty) return t1b;

    final t1c = (outer['token'] ?? '').toString().trim();
    if (t1c.isNotEmpty) return t1c;

    final data = outer['data'];
    if (data is Map) {
      final inner = (data as Map).cast<String, dynamic>();

      final t2 = (inner['accessToken'] ?? '').toString().trim();
      if (t2.isNotEmpty) return t2;

      final t2b = (inner['access_token'] ?? '').toString().trim();
      if (t2b.isNotEmpty) return t2b;

      final t2c = (inner['token'] ?? '').toString().trim();
      if (t2c.isNotEmpty) return t2c;
    }

    return '';
  }

  String? _readRefreshToken(Map<String, dynamic> outer) {
    final r1 = (outer['refreshToken'] ?? '').toString().trim();
    if (r1.isNotEmpty) return r1;

    final r1b = (outer['refresh_token'] ?? '').toString().trim();
    if (r1b.isNotEmpty) return r1b;

    final data = outer['data'];
    if (data is Map) {
      final inner = (data as Map).cast<String, dynamic>();

      final r2 = (inner['refreshToken'] ?? '').toString().trim();
      if (r2.isNotEmpty) return r2;

      final r2b = (inner['refresh_token'] ?? '').toString().trim();
      if (r2b.isNotEmpty) return r2b;
    }

    return null;
  }

  void _invalidateAuth() {
    try {
      ref.invalidate(tokenStoreLoadedProvider);
    } catch (_) {}
    try {
      ref.invalidate(isAuthedProvider);
    } catch (_) {}
    try {
      ref.invalidate(authStatusProvider);
    } catch (_) {}
    try {
      ref.invalidate(emailVerifiedProvider);
    } catch (_) {}
    try {
      ref.invalidate(authEventsProvider);
    } catch (_) {}
  }

  String _safeRedirectPath(String? raw, {String fallback = '/home'}) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return fallback;
    if (!v.startsWith('/')) return fallback;
    if (v == '/') return fallback;
    if (v == '/_boot') return fallback;
    return v;
  }

  Uri _appLinkedInCallbackUri({String? redirectTo}) {
    final base = Uri.base;
    final desiredRedirect = _safeRedirectPath(redirectTo, fallback: '/home');

    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/auth/linkedin/callback',
      queryParameters: <String, String>{
        'redirect': desiredRedirect,
      },
    );
  }

  Uri buildLinkedInStartUri({String? redirectTo}) {
    final dio = _dio();
    final baseUri = Uri.parse(dio.options.baseUrl);
    final callbackUri = _appLinkedInCallbackUri(redirectTo: redirectTo);
    final callback = callbackUri.toString();

    final candidatePath = _linkedinStartPathCandidates.first;

    return baseUri.resolveUri(
      Uri(
        path: candidatePath,
        queryParameters: <String, String>{
          // Multiple common parameter names to maximize backend compatibility.
          'redirect': callback,
          'redirect_uri': callback,
          'redirectUri': callback,
          'callback_url': callback,
          'callbackUrl': callback,
          'frontend_redirect': callback,
          'frontendRedirect': callback,
          'return_to': callback,
          'returnTo': callback,
        },
      ),
    );
  }

  Future<Uri> startLinkedInAuth({String? redirectTo}) async {
    return buildLinkedInStartUri(redirectTo: redirectTo);
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final s = (value ?? '').trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _readCallbackToken(Uri uri) {
    final q = uri.queryParameters;

    final fragmentParams = uri.fragment.isEmpty
        ? const <String, String>{}
        : Uri.splitQueryString(uri.fragment);

    return _firstNonEmpty([
      q['accessToken'],
      q['access_token'],
      q['token'],
      fragmentParams['accessToken'],
      fragmentParams['access_token'],
      fragmentParams['token'],
    ]);
  }

  String? _readCallbackRefreshToken(Uri uri) {
    final q = uri.queryParameters;

    final fragmentParams = uri.fragment.isEmpty
        ? const <String, String>{}
        : Uri.splitQueryString(uri.fragment);

    final value = _firstNonEmpty([
      q['refreshToken'],
      q['refresh_token'],
      fragmentParams['refreshToken'],
      fragmentParams['refresh_token'],
    ]);

    return value.isEmpty ? null : value;
  }

  String _humanizeOAuthCallbackError(Uri uri) {
    final q = uri.queryParameters;

    final raw = _firstNonEmpty([
      q['error_description'],
      q['errorDescription'],
      q['message'],
      q['detail'],
      q['error'],
    ]).toLowerCase();

    if (raw.isEmpty) {
      return 'LinkedIn sign-in could not be completed.';
    }

    if (raw.contains('access_denied') ||
        raw.contains('user denied') ||
        raw.contains('cancel')) {
      return 'LinkedIn sign-in was cancelled.';
    }

    if (raw.contains('state')) {
      return 'LinkedIn sign-in could not be verified safely. Please try again.';
    }

    if (raw.contains('expired') || raw.contains('invalid code')) {
      return 'That LinkedIn sign-in attempt is no longer valid. Please try again.';
    }

    return 'LinkedIn sign-in could not be completed.';
  }

  Future<String> consumeLinkedInCallback(Uri uri) async {
    final redirect =
        _safeRedirectPath(uri.queryParameters['redirect'], fallback: '/home');

    final callbackError = _firstNonEmpty([
      uri.queryParameters['error'],
      uri.queryParameters['error_description'],
      uri.queryParameters['errorDescription'],
      uri.queryParameters['message'],
      uri.queryParameters['detail'],
    ]);

    if (callbackError.isNotEmpty &&
        _readCallbackToken(uri).isEmpty &&
        (uri.queryParameters['success'] ?? '').trim() != '1') {
      throw Exception(_humanizeOAuthCallbackError(uri));
    }

    final directAccess = _readCallbackToken(uri);
    final directRefresh = _readCallbackRefreshToken(uri);

    if (directAccess.isNotEmpty) {
      await _store().setSession(
        accessToken: directAccess,
        refreshToken: (!kIsWeb &&
                directRefresh != null &&
                directRefresh.trim().isNotEmpty)
            ? directRefresh
            : null,
      );
      _invalidateAuth();
      return redirect;
    }

    await refresh();
    return redirect;
  }

  /// Supports BOTH:
  ///  - login(email: ..., password: ...)
  ///  - login(dto: map) where map contains email/password
  Future<Map<String, dynamic>> login({
    String? email,
    String? password,
    dynamic dto,
  }) async {
    String e = (email ?? '').trim();
    String p = (password ?? '').trim();

    if ((e.isEmpty || p.isEmpty) && dto != null) {
      final m = _asMap(dto);
      e = (m['email'] ?? '').toString().trim();
      p = (m['password'] ?? '').toString().trim();
    }

    if (e.isEmpty) throw Exception('Email is required');
    if (p.isEmpty) throw Exception('Password is required');

    final res = await _dio().post(
      '/auth/login',
      data: {'email': e, 'password': p},
    );

    final outer = _asMap(res.data);
    final access = _readAccessToken(outer);
    final refresh = _readRefreshToken(outer);

    if (access.isEmpty) {
      throw Exception('Login response missing accessToken (envelope mismatch)');
    }

    await _store().setSession(
      accessToken: access,
      refreshToken:
          (refresh != null && refresh.trim().isNotEmpty) ? refresh : null,
    );

    _invalidateAuth();
    return _unwrap(outer);
  }

  /// logout(context) OR logout()
  Future<void> logout([BuildContext? _]) async {
    try {
      final rt = _store().refreshToken;

      if (kIsWeb) {
        await _dio().post('/auth/logout');
      } else {
        await _dio().post(
          '/auth/logout',
          data:
              (rt != null && rt.trim().isNotEmpty) ? {'refreshToken': rt} : {},
        );
      }
    } catch (_) {
      // ignore
    } finally {
      await _store().clearTokens();
      _invalidateAuth();
    }
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio().get('/auth/me');
    final outer = _asMap(res.data);
    return _unwrap(outer);
  }

  /// Manual refresh. Prefer relying on Dio interceptor for normal API traffic.
  Future<Map<String, dynamic>> refresh() async {
    if (kIsWeb) {
      // Web refresh: cookie-based.
      // Use text/plain + no body to reduce preflight noise.
      final res = await _dio().post(
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

      if (res.statusCode == 204) throw Exception('No session (204)');

      final outer = _asMap(res.data);
      final access = _readAccessToken(outer);

      if (access.isEmpty) {
        throw Exception('Refresh response missing accessToken');
      }

      // IMPORTANT: do NOT pass refreshToken: null on web (cookie is HttpOnly).
      await _store().setSession(accessToken: access);
      _invalidateAuth();
      return _unwrap(outer);
    } else {
      final rt = _store().refreshToken;
      if (rt == null || rt.trim().isEmpty) {
        throw Exception('Missing refresh token');
      }

      final res = await _dio().post(
        '/auth/refresh',
        data: {'refreshToken': rt},
        options: Options(headers: const {'x-token-transport': 'body'}),
      );

      final outer = _asMap(res.data);
      final access = _readAccessToken(outer);
      final newRt = _readRefreshToken(outer);

      if (access.isEmpty) {
        throw Exception('Refresh response missing accessToken');
      }

      await _store().setSession(
        accessToken: access,
        refreshToken: (newRt != null && newRt.trim().isNotEmpty) ? newRt : rt,
      );

      _invalidateAuth();
      return _unwrap(outer);
    }
  }
}