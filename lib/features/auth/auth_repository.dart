import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String handle,
    required String displayName,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          'handle': handle.trim(),
          'displayName': displayName.trim(),
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
        },
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(_mapRegisterError(e));
    } catch (_) {
      throw const AuthException(
        'We could not create your account right now. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(_mapLoginError(e));
    } catch (_) {
      throw const AuthException(
        'We could not sign you in right now. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> resendVerificationEmail({
    required String email,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/resend-verification',
        data: {'email': email.trim()},
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(_mapResendVerificationError(e));
    } catch (_) {
      throw const AuthException(
        'We could not resend the verification email right now. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String token,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/verify-email',
        data: {'token': token},
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(_mapVerifyEmailError(e));
    } catch (_) {
      throw const AuthException(
        'We could not verify your email right now. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/forgot-password',
        data: {'email': email.trim()},
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(_mapForgotPasswordError(e));
    } catch (_) {
      throw const AuthException(
        'We could not send the reset email right now. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> verifyLoginCode({
    required String challengeId,
    required String code,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/login/verify-code',
        data: {'challengeId': challengeId.trim(), 'code': code.trim()},
      );
      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(_mapVerifyCodeError(e));
    } catch (_) {
      throw const AuthException('We could not verify the code right now. Please try again.');
    }
  }

  Future<Map<String, dynamic>> resendLoginCode({
    required String challengeId,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/login/resend-code',
        data: {'challengeId': challengeId.trim()},
      );
      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(_mapResendCodeError(e));
    } catch (_) {
      throw const AuthException('We could not resend the code right now. Please try again.');
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/reset-password',
        data: {
          'token': token,
          'password': newPassword,
        },
      );

      return _unwrap(res);
    } on DioException catch (e) {
      throw AuthException(_mapResetPasswordError(e));
    } catch (_) {
      throw const AuthException(
        'We could not reset your password right now. Please try again.',
      );
    }
  }

  Map<String, dynamic> _unwrap(Response res) {
    final body = res.data;

    if (body is Map && body.containsKey('data')) {
      return Map<String, dynamic>.from(body['data'] ?? {});
    }

    if (body is Map<String, dynamic>) {
      return body;
    }

    return {};
  }

  String _extractServerMessage(DioException e) {
    final data = e.response?.data;

    if (data is Map) {
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

      final nestedError = data['error'];
      if (nestedError is Map) {
        final candidates = [
          nestedError['message'],
          nestedError['error'],
          nestedError['detail'],
          nestedError['title'],
        ];
        for (final c in candidates) {
          final s = c?.toString().trim() ?? '';
          if (s.isNotEmpty) return s;
        }
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return '';
  }

  bool _looksLikeNetworkError(DioException e) {
    final msg = (e.message ?? '').toLowerCase();

    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('network');
  }

  String _mapCommonInfraError(
    DioException e, {
    required String fallback,
  }) {
    if (_looksLikeNetworkError(e)) {
      return 'We could not reach the server. Check your connection and try again.';
    }

    final code = e.response?.statusCode;
    final server = _extractServerMessage(e).toLowerCase();

    if (code == 429 || server.contains('too many requests')) {
      return 'Too many attempts in a short time. Please wait a little and try again.';
    }

    if (code != null && code >= 500) {
      return 'Something went wrong on our side. Please try again in a moment.';
    }

    return fallback;
  }

  String _mapRegisterError(DioException e) {
    final common = _mapCommonInfraError(
      e,
      fallback: 'We could not create your account right now. Please try again.',
    );

    if (common !=
        'We could not create your account right now. Please try again.') {
      return common;
    }

    final code = e.response?.statusCode;
    final server = _extractServerMessage(e).toLowerCase();

    if (server.contains('email already') ||
        server.contains('email is already') ||
        (server.contains('already exists') && server.contains('email')) ||
        (server.contains('duplicate') && server.contains('email')) ||
        (server.contains('unique') && server.contains('email'))) {
      return 'That email is already in use. Try signing in instead.';
    }

    if (server.contains('handle already') ||
        server.contains('username already') ||
        (server.contains('duplicate') && server.contains('handle')) ||
        (server.contains('unique') && server.contains('handle')) ||
        (server.contains('unique') && server.contains('username'))) {
      return 'That handle is already taken. Please choose another one.';
    }

    if (server.contains('invalid email') ||
        server.contains('email is invalid') ||
        server.contains('must be a valid email')) {
      return 'Please enter a valid email address.';
    }

    if (server.contains('password') && server.contains('weak')) {
      return 'Please choose a stronger password.';
    }

    if (server.contains('password') && server.contains('at least 8')) {
      return 'Password must be at least 8 characters.';
    }

    if (code == 400 || code == 422) {
      return 'Some details need another look. Please review the form and try again.';
    }

    return 'We could not create your account right now. Please try again.';
  }

  String _mapLoginError(DioException e) {
    final common = _mapCommonInfraError(
      e,
      fallback: 'We could not sign you in right now. Please try again.',
    );

    if (common != 'We could not sign you in right now. Please try again.') {
      return common;
    }

    final code = e.response?.statusCode;
    final server = _extractServerMessage(e).toLowerCase();

    if (code == 401 ||
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

  String _mapResendVerificationError(DioException e) {
    final common = _mapCommonInfraError(
      e,
      fallback:
          'We could not resend the verification email right now. Please try again.',
    );

    if (common !=
        'We could not resend the verification email right now. Please try again.') {
      return common;
    }

    final code = e.response?.statusCode;
    final server = _extractServerMessage(e).toLowerCase();

    if (code == 400 || server.contains('already verified')) {
      return 'This email is already verified.';
    }

    if (code == 404 || server.contains('not found')) {
      return 'We could not find an account with that email.';
    }

    return 'We could not resend the verification email right now. Please try again.';
  }

  String _mapVerifyEmailError(DioException e) {
    final common = _mapCommonInfraError(
      e,
      fallback: 'We could not verify your email right now. Please try again.',
    );

    if (common !=
        'We could not verify your email right now. Please try again.') {
      return common;
    }

    final code = e.response?.statusCode;
    final server = _extractServerMessage(e).toLowerCase();

    if (code == 400 ||
        server.contains('invalid token') ||
        server.contains('expired token') ||
        server.contains('token expired')) {
      return 'That verification link is no longer valid. Please request a new one.';
    }

    if (server.contains('already verified')) {
      return 'Your email is already verified. You can sign in now.';
    }

    return 'We could not verify your email right now. Please try again.';
  }

  String _mapForgotPasswordError(DioException e) {
    final common = _mapCommonInfraError(
      e,
      fallback: 'We could not send the reset email right now. Please try again.',
    );

    if (common !=
        'We could not send the reset email right now. Please try again.') {
      return common;
    }

    final code = e.response?.statusCode;
    final server = _extractServerMessage(e).toLowerCase();

    if (code == 404 || server.contains('not found')) {
      return 'We could not find an account with that email.';
    }

    return 'We could not send the reset email right now. Please try again.';
  }

  String _mapVerifyCodeError(DioException e) {
    final common = _mapCommonInfraError(
      e,
      fallback: 'We could not verify the code right now. Please try again.',
    );
    if (common != 'We could not verify the code right now. Please try again.') return common;

    final code = e.response?.statusCode;
    final server = _extractServerMessage(e).toLowerCase();

    if (code == 401 || server.contains('incorrect code') || server.contains('invalid code')) {
      return 'That code is incorrect. Please check and try again.';
    }
    if (server.contains('expired')) return 'That code has expired. Please request a new one.';
    if (server.contains('already used') || server.contains('consumed')) {
      return 'That code has already been used. Please request a new one.';
    }
    if (code == 429 || server.contains('too many')) {
      return 'Too many attempts. Please request a new code.';
    }
    return 'We could not verify the code right now. Please try again.';
  }

  String _mapResendCodeError(DioException e) {
    final common = _mapCommonInfraError(
      e,
      fallback: 'We could not resend the code right now. Please try again.',
    );
    if (common != 'We could not resend the code right now. Please try again.') return common;

    final server = _extractServerMessage(e).toLowerCase();

    if (server.contains('please wait') || e.response?.statusCode == 429) {
      final msg = _extractServerMessage(e);
      return msg.isNotEmpty ? msg : 'Please wait before requesting a new code.';
    }
    if (server.contains('expired')) return 'This sign-in session has expired. Please start again.';
    return 'We could not resend the code right now. Please try again.';
  }

  String _mapResetPasswordError(DioException e) {
    final common = _mapCommonInfraError(
      e,
      fallback: 'We could not reset your password right now. Please try again.',
    );

    if (common !=
        'We could not reset your password right now. Please try again.') {
      return common;
    }

    final code = e.response?.statusCode;
    final server = _extractServerMessage(e).toLowerCase();

    if (code == 400 ||
        server.contains('invalid token') ||
        server.contains('expired token') ||
        server.contains('token expired')) {
      return 'That reset link is no longer valid. Please request a new one.';
    }

    if (server.contains('password') && server.contains('at least 8')) {
      return 'Password must be at least 8 characters.';
    }

    if (server.contains('password') && server.contains('weak')) {
      return 'Please choose a stronger password.';
    }

    return 'We could not reset your password right now. Please try again.';
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});