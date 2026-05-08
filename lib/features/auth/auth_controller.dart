import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/auth/trusted_device_store.dart';
import '../../core/net/dio_provider.dart';
import '../devices/device_providers.dart';

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
      return Map<String, dynamic>.from(data);
    }

    return m;
  }

  String _readAccessToken(Map<String, dynamic> outer) {
    final t1 = (outer['accessToken'] ?? '').toString().trim();
    if (t1.isNotEmpty) return t1;

    final data = outer['data'];
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data);
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
      final inner = Map<String, dynamic>.from(data);
      final r2 = (inner['refreshToken'] ?? '').toString().trim();
      if (r2.isNotEmpty) return r2;
    }

    return null;
  }

  String _extractServerMessage(DioException e) {
    final data = e.response?.data;

    if (data is Map) {
      // Aura backend envelope: { ok:false, error: { code, message, details, ... } }
      final nested = data['error'];
      if (nested is Map) {
        final candidates = [
          nested['message'],
          nested['error'],
          nested['detail'],
          nested['title'],
        ];
        for (final c in candidates) {
          final s = c?.toString().trim() ?? '';
          if (s.isNotEmpty) return s;
        }
      }

      final candidates = [
        data['message'],
        data['error'],
        data['detail'],
        data['title'],
      ];

      for (final c in candidates) {
        final s = c?.toString().trim() ?? '';
        if (s.isNotEmpty) return s;
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return '';
  }

  /// Reads the structured `error.code` from the Aura backend envelope.
  String _extractServerCode(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        final c = err['code']?.toString().trim();
        if (c != null && c.isNotEmpty) return c;
      }
      final c = data['code']?.toString().trim();
      if (c != null && c.isNotEmpty) return c;
    }
    return '';
  }

  String _mapLoginError(DioException e) {
    final code = e.response?.statusCode;
    final backendCode = _extractServerCode(e).toUpperCase();
    final server = _extractServerMessage(e).toLowerCase();

    // Prefer structured backend error codes — robust against message-text drift.
    if (backendCode == 'EMAIL_NOT_VERIFIED') {
      return 'Please verify your email first, then try signing in again.';
    }

    if (code == 401 ||
        backendCode == 'UNAUTHORIZED' ||
        server.contains('invalid credentials') ||
        server.contains('invalid login') ||
        server.contains('wrong password') ||
        server.contains('incorrect password') ||
        server.contains('incorrect email') ||
        server.contains('incorrect email or password') ||
        server.contains('wrong email or password') ||
        server.contains('email or password is incorrect') ||
        server.contains('invalid email or password') ||
        server.contains('unauthorized')) {
      return 'The email or password does not look right.';
    }

    if (server.contains('email not verified') ||
        server.contains('verify your email') ||
        server.contains('email verification required') ||
        server.contains('unverified')) {
      return 'Please verify your email first, then try signing in again.';
    }

    if (code == 403 ||
        server.contains('account disabled') ||
        server.contains('account locked') ||
        server.contains('account suspended') ||
        server.contains('forbidden')) {
      return 'This account is not available right now.';
    }

    return 'We could not sign you in right now. Please try again.';
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
      ref.invalidate(authMeDataProvider);
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
  ///
  /// Returns either:
  ///  - { status: 'ok', ... }     — session issued, user is logged in
  ///  - { status: 'challenge', challengeId, maskedEmail } — email code required
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

    final deviceToken = await TrustedDeviceStore.load();

    late final Response res;
    try {
      res = await _dio().post(
        '/auth/login',
        data: {
          'email': e,
          'password': p,
          if (deviceToken != null) 'trustedDeviceToken': deviceToken,
        },
      );
    } on DioException catch (err) {
      throw Exception(_mapLoginError(err));
    }

    final outer = _asMap(res.data);

    // Email-code challenge path
    final requiresEmailCode = outer['requiresEmailCode'];
    if (requiresEmailCode == true) {
      // codeSent==false means the backend created the challenge but the email
      // service failed to deliver. Propagate so the UI can surface that
      // instead of telling the user to "check your inbox" for nothing.
      final codeSentRaw = outer['codeSent'];
      final codeSent = codeSentRaw is bool ? codeSentRaw : true;
      return {
        'status': 'challenge',
        'challengeId': (outer['challengeId'] ?? '').toString(),
        'maskedEmail': (outer['maskedEmail'] ?? '').toString(),
        'codeSent': codeSent,
      };
    }

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
    return {'status': 'ok', ..._unwrap(outer)};
  }

  /// Complete a login email-code challenge.
  /// On success, stores the session (and optionally a trusted device token) and
  /// invalidates auth providers.
  Future<Map<String, dynamic>> verifyLoginCode({
    required String challengeId,
    required String code,
    bool trustDevice = false,
    String? deviceName,
  }) async {
    late final Response res;
    try {
      res = await _dio().post(
        '/auth/login/verify-code',
        data: {
          'challengeId': challengeId.trim(),
          'code': code.trim(),
          if (trustDevice) 'trustDevice': true,
          if (deviceName != null && deviceName.trim().isNotEmpty)
            'deviceName': deviceName.trim(),
        },
      );
    } on DioException catch (err) {
      final server = (err.response?.data is Map
              ? (err.response!.data['message'] ?? err.response!.data['error'] ?? '')
              : '')
          .toString()
          .trim();
      final status = err.response?.statusCode ?? 0;

      if (status == 401 ||
          server.toLowerCase().contains('incorrect code') ||
          server.toLowerCase().contains('invalid')) {
        throw Exception('That code is incorrect. Please check and try again.');
      }
      if (server.toLowerCase().contains('expired')) {
        throw Exception('That code has expired. Please request a new one.');
      }
      if (server.toLowerCase().contains('already used') ||
          server.toLowerCase().contains('consumed')) {
        throw Exception('That code has already been used. Please request a new one.');
      }
      if (status == 429 || server.toLowerCase().contains('too many')) {
        throw Exception('Too many attempts. Please request a new code.');
      }
      throw Exception(server.isNotEmpty ? server : 'We could not verify the code. Please try again.');
    }

    final outer = _asMap(res.data);
    final access = _readAccessToken(outer);
    final refresh = _readRefreshToken(outer);

    if (access.isEmpty) {
      throw Exception('Verification response missing accessToken');
    }

    await _store().setSession(
      accessToken: access,
      refreshToken: (refresh != null && refresh.trim().isNotEmpty) ? refresh : null,
    );

    // Persist trusted device token if the server issued one
    final deviceToken = (outer['deviceToken'] ?? '').toString().trim();
    if (deviceToken.isNotEmpty) {
      await TrustedDeviceStore.save(deviceToken);
    }

    _invalidateAuth();
    return _unwrap(outer);
  }

  /// Request a new login code for an existing challenge.
  Future<Map<String, dynamic>> resendLoginCode(String challengeId) async {
    late final Response res;
    try {
      res = await _dio().post(
        '/auth/login/resend-code',
        data: {'challengeId': challengeId.trim()},
      );
    } on DioException catch (err) {
      final raw = err.response?.data;
      String server = '';
      if (raw is Map) {
        final inner = raw['error'];
        if (inner is Map) {
          server = (inner['message'] ?? '').toString().trim();
        }
        if (server.isEmpty) server = (raw['message'] ?? '').toString().trim();
      }
      if (err.response?.statusCode == 429 || server.toLowerCase().contains('please wait')) {
        throw Exception(server.isNotEmpty ? server : 'Please wait before requesting a new code.');
      }
      throw Exception(server.isNotEmpty ? server : 'We could not resend the code. Please try again.');
    }

    return _asMap(res.data);
  }

  /// logout(context) OR logout()
  Future<void> logout([BuildContext? _]) async {
    try {
      // Best-effort: revoke device before token is cleared; never blocks logout
      unawaited(ref.read(deviceServiceProvider).revokeCurrentDevice());
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
