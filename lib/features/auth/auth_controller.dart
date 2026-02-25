import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/net/dio_provider.dart';

class AuthController {
  AuthController(this.ref);

  final WidgetRef ref;

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final m = Map<String, dynamic>.from(raw);

    dynamic data = m['data'];
    if (data is Map && data['data'] is Map) {
      data = data['data'];
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return m;
  }

  String? _errCode(dynamic raw) {
    if (raw is! Map) return null;
    final err = raw['error'];
    if (err is Map) {
      final c = err['code'];
      if (c is String && c.trim().isNotEmpty) return c.trim();
    }
    return null;
  }

  String _safeRedirect(String? redirectTo) {
    final r = (redirectTo ?? '').trim();
    if (r.isEmpty) return '/home';
    if (!r.startsWith('/')) return '/home';
    return r;
  }

  Future<bool> _isVerifiedByAuthMe(Dio dio) async {
    try {
      final meRes = await dio.get('/auth/me');
      final data = _unwrap(meRes.data);

      final v1 = data['emailVerifiedAt'];
      if (v1 != null && v1.toString().trim().isNotEmpty) return true;

      final user = data['user'];
      if (user is Map) {
        final v2 = user['emailVerifiedAt'];
        if (v2 != null && v2.toString().trim().isNotEmpty) return true;
      }

      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return false;
      final code = _errCode(e.response?.data);
      if (code == 'EMAIL_NOT_VERIFIED') return false;
      rethrow;
    }
  }

  Future<void> login(
    BuildContext context, {
    required String email,
    required String password,
    String? redirectTo,
  }) async {
    final dio = ref.read(dioProvider);

    try {
      final res = await dio.post(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final body = res.data;

      // Expect: { ok: true, data: { accessToken, refreshToken? } }
      if (body is! Map || body['ok'] != true) {
        throw Exception('Unexpected login response');
      }

      final payload = Map<String, dynamic>.from((body['data'] as Map?) ?? {});
      final accessToken = (payload['accessToken'] as String?)?.trim();

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Missing access token');
      }

      // Web cookie mode: refreshToken not expected here. Keep null.
      await ref.read(tokenStoreProvider).setSession(
            accessToken: accessToken,
            refreshToken: null,
          );

      // Hard gate: do NOT enter app until verified.
      final verified = await _isVerifiedByAuthMe(dio);
      if (!verified) {
        await ref.read(tokenStoreProvider).clear();
        ref.invalidate(isAuthedProvider);
        ref.invalidate(emailVerifiedProvider);

        final dest = _safeRedirect(redirectTo);
        context.go(
          '/verify-email?redirect=${Uri.encodeComponent(dest)}&email=${Uri.encodeComponent(email.trim())}',
        );
        return;
      }

      ref.invalidate(isAuthedProvider);
      ref.invalidate(emailVerifiedProvider);

      final dest = _safeRedirect(redirectTo);
      context.go(dest);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final code = _errCode(responseData);

      if (code == 'EMAIL_NOT_VERIFIED' || e.response?.statusCode == 403) {
        final dest = _safeRedirect(redirectTo);
        context.go(
          '/verify-email?redirect=${Uri.encodeComponent(dest)}&email=${Uri.encodeComponent(email.trim())}',
        );
        return;
      }

      String? message;
      if (responseData is Map) {
        final err = responseData['error'];
        if (err is Map && err['message'] != null) {
          message = err['message'].toString();
        } else if (responseData['message'] != null) {
          message = responseData['message'].toString();
        }
      }

      throw Exception(message ?? 'Login failed');
    }
  }

  Future<void> logout(BuildContext context) async {
    final dio = ref.read(dioProvider);

    try {
      await dio.post('/auth/logout');
    } catch (_) {}

    await ref.read(tokenStoreProvider).clear();

    ref.invalidate(isAuthedProvider);
    ref.invalidate(emailVerifiedProvider);

    context.go('/login');
  }
}