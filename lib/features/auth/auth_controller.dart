import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:aura/core/auth/auth_providers.dart';
import '../../core/net/dio_provider.dart';

class AuthController {
  AuthController(this.ref);

  /// IMPORTANT:
  /// Some screens pass WidgetRef, others may pass Ref.
  /// Using dynamic avoids WidgetRef vs Ref generic mismatch.
  final dynamic ref;

  Dio _dio() => ref.read(dioProvider);

  TokenStore _store() => ref.read(tokenStoreProvider);

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    throw Exception('Unexpected response type');
  }

  /// Supports:
  ///  - login(email: "a", password: "b")
  ///  - login({"email": "...", "password": "..."})
  ///  - login("email", "password")
  Future<Map<String, dynamic>> login([
    dynamic a,
    dynamic b, {
    String? email,
    String? password,
  }]) async {
    String e = '';
    String p = '';

    if (email != null || password != null) {
      e = (email ?? '').trim();
      p = (password ?? '').trim();
    } else if (a is String) {
      e = a.trim();
      p = (b?.toString() ?? '').trim();
    } else {
      final m = _asMap(a);
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

    if (access.isEmpty) {
      throw Exception('Login response missing accessToken');
    }

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
        // Web: refresh cookie is HttpOnly; backend can revoke based on cookie.
        await _dio().post('/auth/logout');
      } else {
        await _dio().post(
          '/auth/logout',
          data: (rt != null && rt.trim().isNotEmpty) ? {'refreshToken': rt} : {},
        );
      }
    } catch (_) {
      // Even if request fails, clear local tokens to avoid "half logged-in" state.
    } finally {
      await _store().clearTokens();
    }
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio().get('/auth/me');
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> refresh() async {
    // Usually Dio interceptor handles refresh on 401.
    // This exists if you trigger it manually.
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