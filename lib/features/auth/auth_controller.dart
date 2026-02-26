import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:aura/core/auth/auth_providers.dart';
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

  /// Supports BOTH:
  ///  - login(email: ..., password: ...)
  ///  - login(mapOrDto) where map contains email/password
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

    final raw = _asMap(res.data);
    final access = (raw['accessToken'] ?? '').toString().trim();
    final refresh = (raw['refreshToken'] ?? '').toString().trim();

    if (access.isEmpty) throw Exception('Login response missing accessToken');

    await _store().setSession(
      accessToken: access,
      refreshToken: refresh.isNotEmpty ? refresh : null,
    );

    return raw;
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
    }
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio().get('/auth/me');
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> refresh() async {
    if (kIsWeb) {
      final res = await _dio().post('/auth/refresh');
      final raw = _asMap(res.data);

      final access = (raw['accessToken'] ?? '').toString().trim();
      if (access.isEmpty) throw Exception('Refresh response missing accessToken');

      await _store().setSession(accessToken: access, refreshToken: null);
      return raw;
    } else {
      final rt = _store().refreshToken;
      if (rt == null || rt.trim().isEmpty) throw Exception('Missing refresh token');

      final res = await _dio().post('/auth/refresh', data: {'refreshToken': rt});
      final raw = _asMap(res.data);

      final access = (raw['accessToken'] ?? '').toString().trim();
      final newRt = (raw['refreshToken'] ?? '').toString().trim();
      if (access.isEmpty) throw Exception('Refresh response missing accessToken');

      await _store().setSession(
        accessToken: access,
        refreshToken: newRt.isNotEmpty ? newRt : rt,
      );

      return raw;
    }
  }
}