import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';

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
  /// Returns the "best" inner map, but never loses the outer map if needed.
  Map<String, dynamic> _unwrap(dynamic raw) {
    final m = _asMap(raw);

    final data = m['data'];
    if (data is Map) {
      return (data as Map).cast<String, dynamic>();
    }

    return m;
  }

  String _readToken(Map<String, dynamic> outer) {
    // Try token at top-level
    final t1 = (outer['accessToken'] ?? '').toString().trim();
    if (t1.isNotEmpty) return t1;

    // Try token inside {data:{...}}
    final data = outer['data'];
    if (data is Map) {
      final inner = (data as Map).cast<String, dynamic>();
      final t2 = (inner['accessToken'] ?? '').toString().trim();
      if (t2.isNotEmpty) return t2;
    }

    return '';
  }

  String? _readRefresh(Map<String, dynamic> outer) {
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
    // WidgetRef and Ref both support invalidate in riverpod 2+.
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
    final access = _readToken(outer);
    final refresh = _readRefresh(outer);

    if (access.isEmpty) {
      // Provide a useful error for debugging
      throw Exception('Login response missing accessToken (envelope mismatch)');
    }

    await _store().setSession(
      accessToken: access,
      refreshToken: (refresh != null && refresh.trim().isNotEmpty) ? refresh : null,
    );

    // Force UI/router to see the new auth state immediately.
    _invalidateAuth();

    // Return inner payload (most screens expect user/accessToken fields there)
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

  Future<Map<String, dynamic>> refresh() async {
    if (kIsWeb) {
      final res = await _dio().post('/auth/refresh');
      final outer = _asMap(res.data);

      final access = _readToken(outer);
      if (access.isEmpty) throw Exception('Refresh response missing accessToken');

      await _store().setSession(accessToken: access, refreshToken: null);
      _invalidateAuth();
      return _unwrap(outer);
    } else {
      final rt = _store().refreshToken;
      if (rt == null || rt.trim().isEmpty) throw Exception('Missing refresh token');

      final res = await _dio().post('/auth/refresh', data: {'refreshToken': rt});
      final outer = _asMap(res.data);

      final access = _readToken(outer);
      final newRt = _readRefresh(outer);

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