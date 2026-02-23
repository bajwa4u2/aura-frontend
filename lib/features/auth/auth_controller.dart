import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';

class AuthController {
  AuthController(this.ref);

  final Ref ref;

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

      if (body is! Map || body['ok'] != true) {
        throw Exception('Unexpected login response');
      }

      final payload = Map<String, dynamic>.from((body['data'] as Map?) ?? {});
      final accessToken = (payload['accessToken'] as String?)?.trim();

      // Cookie mode: refresh token will NOT be present in JSON.
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Missing access token');
      }

      // Save access token (refresh handled via HttpOnly cookie on web)
      await ref.read(tokenStoreProvider).setSession(
            accessToken: accessToken,
            refreshToken: null,
          );

      ref.invalidate(isAuthedProvider);
      ref.invalidate(emailVerifiedProvider);

      // You asked: verified users should land in Me.
      // We'll do that in Step 2 (router rule), after auth actually works.
      final dest = (redirectTo != null && redirectTo.startsWith('/'))
          ? redirectTo
          : '/home';

      context.go(dest);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String? code;

      if (responseData is Map) {
        code = responseData['error']?['code'] as String?;
      }

      if (code == 'EMAIL_NOT_VERIFIED') {
        final dest = (redirectTo != null && redirectTo.startsWith('/'))
            ? redirectTo
            : '/home';

        context.go('/verify-email?redirect=${Uri.encodeComponent(dest)}');
        return;
      }

      final message =
          responseData is Map ? responseData['error']?['message'] : null;

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