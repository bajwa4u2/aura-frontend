import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import 'auth_providers.dart';

class AuthController {
  AuthController(this.ref);

  final Ref ref;

  Dio get _dio => ref.read(dioProvider);

  Future<void> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });

    final payload = _asMap(res.data);
    final data = _unwrapData(payload);

    final accessToken =
        (data['accessToken'] ?? payload['accessToken'])?.toString();
    final refreshToken =
        (data['refreshToken'] ?? payload['refreshToken'])?.toString();

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Login failed: accessToken missing');
    }

    await ref.read(tokenStoreProvider).setSession(
          accessToken: accessToken,
          refreshToken: kIsWeb ? null : refreshToken,
        );
  }

  Future<void> logout(BuildContext context) async {
    try {
      if (kIsWeb) {
        await _dio.post('/auth/logout');
      } else {
        final rt = ref.read(tokenStoreProvider).refreshToken;
        await _dio.post('/auth/logout', data: {
          if (rt != null && rt.trim().isNotEmpty) 'refreshToken': rt.trim(),
        });
      }
    } catch (_) {
      // ignore; still clear local
    } finally {
      await ref.read(tokenStoreProvider).clearTokens();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? handle,
    String? displayName,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'email': email.trim().toLowerCase(),
      'password': password,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      if (handle != null && handle.trim().isNotEmpty) 'handle': handle.trim(),
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
    });

    final payload = _asMap(res.data);
    final data = _unwrapData(payload);

    final accessToken =
        (data['accessToken'] ?? payload['accessToken'])?.toString();
    final refreshToken =
        (data['refreshToken'] ?? payload['refreshToken'])?.toString();

    if (accessToken != null && accessToken.isNotEmpty) {
      await ref.read(tokenStoreProvider).setSession(
            accessToken: accessToken,
            refreshToken: kIsWeb ? null : refreshToken,
          );
    }
  }

  Future<void> resendVerification(String email) async {
    await _dio.post('/auth/resend-verification', data: {
      'email': email.trim().toLowerCase(),
    });
  }

  Future<void> verifyEmail(String token) async {
    await _dio.post('/auth/verify-email', data: {
      'token': token.trim(),
    });
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    throw Exception('Unexpected response shape (not a map)');
  }

  Map<String, dynamic> _unwrapData(Map<String, dynamic> payload) {
    final d = payload['data'];
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return d.map((k, val) => MapEntry(k.toString(), val));
    return payload;
  }
}