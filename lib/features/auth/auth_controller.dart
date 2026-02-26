import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'auth_providers.dart';

class AuthController {
  AuthController(this.ref);

  /// IMPORTANT:
  /// auth_screen.dart passes WidgetRef, but other layers may pass Ref.
  /// Using dynamic avoids the WidgetRef vs Ref generic mismatch.
  final dynamic ref;

  Dio _dio() => ref.read(dioProvider);

  TokenStore _store() => ref.read(tokenStoreProvider);

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    throw Exception('Unexpected response type');
  }

  /// Supports BOTH call styles:
  ///  - login(dtoMapOrDto)
  ///  - login(email, password)
  Future<Map<String, dynamic>> login(dynamic a, [dynamic b]) async {
    String email = '';
    String password = '';

    if (a is String) {
      email = a.trim();
      password = (b?.toString() ?? '').trim();
    } else {
      final m = _asMap(a);
      email = (m['email'] ?? '').toString().trim();
      password = (m['password'] ?? '').toString().trim();
    }

    if (email.isEmpty) throw Exception('Email is required');
    if (password.isEmpty) throw Exception('Password is required');

    final res = await _dio().post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final raw = _asMap(res.data);
    final access = (raw['accessToken'] ?? '').toString().trim();
    final refresh = (raw['refreshToken'] ?? '').toString().trim();

    if (access.isEmpty) {
      throw Exception('Login response missing accessToken');
    }

    await _store().setSession(
      accessToken: access,
      refreshToken: (refresh.isNotEmpty) ? refresh : null,
    );

    return raw;
  }

  /// logout(context) OR logout()
  Future<void> logout([BuildContext? _]) async {
    try {
      // Web: refresh cookie is HttpOnly, backend can revoke based on cookie.
      // Non-web: if backend expects refreshToken in body, we send if we have it.
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
    // Normally Dio interceptor handles refresh automatically on 401.
    // This is here if you call it manually.
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