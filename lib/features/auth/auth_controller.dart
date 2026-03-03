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
final authControllerProvider = Provider<AuthController>((ref) => AuthController(ref));

class AuthController {
  AuthController(this.ref);

  /// Some screens pass WidgetRef, other layers may pass Ref.
  /// dynamic avoids WidgetRef vs Ref generic mismatch.
  final dynamic ref;

  Dio _dio() => ref.read(dioProvider);
  TokenStore _store() => ref.read(tokenStoreProvider);

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

    final data = outer['data'];
    if (data is Map) {
      final inner = (data as Map).cast<String, dynamic>();
      final t2 = (inner['accessToken'] ?? '').toString().trim();
      if (t2.isNotEmpty) return t2;
    }

    return '';
  }

  String? _readRefreshToken(Map<String, dynamic> outer) {
    final r1 = (outer['refreshToken'] ?? '').toString().trim();
    if (r1.isNotEmpty) return r1;

    final data = outer['data'];
    if (data is Map) {
      final inner = (data as Map).cast<String, dynamic>();
      final r2 = (inner['refreshToken'] ?? '').toString().trim();
      if (r2.isNotEmpty) return r2;
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
      refreshToken: (refresh != null && refresh.trim().isNotEmpty) ? refresh : null,
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
          data: (rt != null && rt.trim().isNotEmpty) ? {'refreshToken': rt} : {},
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

      if (access.isEmpty) throw Exception('Refresh response missing accessToken');

      // IMPORTANT: do NOT pass refreshToken: null on web (cookie is HttpOnly).
      await _store().setSession(accessToken: access);
      _invalidateAuth();
      return _unwrap(outer);
    } else {
      final rt = _store().refreshToken;
      if (rt == null || rt.trim().isEmpty) throw Exception('Missing refresh token');

      final res = await _dio().post(
        '/auth/refresh',
        data: {'refreshToken': rt},
        options: Options(headers: const {'x-token-transport': 'body'}),
      );

      final outer = _asMap(res.data);
      final access = _readAccessToken(outer);
      final newRt = _readRefreshToken(outer);

      if (access.isEmpty) throw Exception('Refresh response missing accessToken');

      await _store().setSession(
        accessToken: access,
        refreshToken: (newRt != null && newRt.trim().isNotEmpty) ? newRt : rt,
      );

      _invalidateAuth();
      return _unwrap(outer);
    }
  }
}