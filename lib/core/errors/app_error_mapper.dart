import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'app_error.dart';

/// The single canonical translator from "anything a Dio call can throw"
/// to a UI-safe [AppError].
///
/// This is the only place that should ever read the Aura error envelope
/// (`{ ok:false, error:{ code, message, details, requestId, timestamp, path } }`)
/// off a response body. Feature code must call [AppErrorMapper.from] and
/// render `.message` (plus `.issues` when present) — it must never
/// interpolate a caught error object directly into user-facing text.
class AppErrorMapper {
  const AppErrorMapper._();

  static AppError from(Object error, {String? feature}) {
    if (error is AppError) return error;

    if (error is DioException) {
      return _fromDio(error, feature: feature);
    }

    if (error is SocketException) {
      return const AppError(
        type: AppErrorType.network,
        message: 'Connection was interrupted. Try again.',
      );
    }

    final raw = error.toString().trim();

    return AppError(
      type: AppErrorType.unknown,
      message: 'Something went wrong. Try again.',
      debugMessage: raw.isEmpty ? null : raw,
    );
  }

  static AppError _fromDio(DioException error, {String? feature}) {
    final status = error.response?.statusCode;
    final envelope = _decodeEnvelope(error.response?.data);
    final backendCode = _readBackendCode(envelope);
    final backendMessage = _readBackendMessage(envelope);
    final requestId = _readRequestId(envelope);
    final issues = _readIssues(envelope);

    if (_isAuthRequired(status, backendCode)) {
      return AppError(
        type: AppErrorType.authRequired,
        message: _authMessageForFeature(feature),
        action: AppError.signInAction,
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
        code: backendCode,
        requestId: requestId,
      );
    }

    if (status == 403) {
      return AppError(
        type: AppErrorType.forbidden,
        message: backendMessage?.trim().isNotEmpty == true
            ? backendMessage!.trim()
            : 'You do not have access to this.',
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
        code: backendCode,
        requestId: requestId,
        // Eligibility refusals are 403s that a person may be able to clear
        // themselves — by adding a date of birth, or confirming where they
        // are. The flag is what separates those from the ones only time can
        // lift, so it has to survive the mapping or the UI cannot tell them
        // apart. See `EligibilityRefusal`.
        resolvable: _readResolvable(envelope),
      );
    }

    if (status == 404) {
      return AppError(
        type: AppErrorType.notFound,
        message: 'This could not be found.',
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
        code: backendCode,
        requestId: requestId,
      );
    }

    if (status == 400 || status == 422) {
      return AppError(
        type: AppErrorType.validation,
        message: backendMessage?.trim().isNotEmpty == true
            ? backendMessage!.trim()
            : 'Some information needs attention.',
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
        code: backendCode,
        requestId: requestId,
        issues: issues,
      );
    }

    if (status == 409) {
      return AppError(
        type: AppErrorType.validation,
        message: backendMessage?.trim().isNotEmpty == true
            ? backendMessage!.trim()
            : 'This could not be completed because something changed. Try again.',
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
        code: backendCode,
        requestId: requestId,
      );
    }

    if (status != null && status >= 500) {
      return AppError(
        type: AppErrorType.server,
        message: 'Something went wrong on our side. Try again.',
        debugMessage: backendMessage ?? error.message,
        statusCode: status,
        code: backendCode,
        requestId: requestId,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppError(
          type: AppErrorType.timeout,
          message: 'The request took too long. Try again.',
          debugMessage: backendMessage ?? error.message,
          statusCode: status,
          code: backendCode,
          requestId: requestId,
        );
      case DioExceptionType.connectionError:
        return AppError(
          type: AppErrorType.network,
          message: 'Connection was interrupted. Try again.',
          debugMessage: backendMessage ?? error.message,
          statusCode: status,
          code: backendCode,
          requestId: requestId,
        );
      case DioExceptionType.cancel:
        return AppError(
          type: AppErrorType.cancelled,
          message: 'This request was cancelled.',
          debugMessage: backendMessage ?? error.message,
          statusCode: status,
          code: backendCode,
          requestId: requestId,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    // If the backend envelope was present but didn't match a known status
    // bucket above, still prefer its message over a generic fallback.
    if (backendMessage != null && backendMessage.trim().isNotEmpty) {
      return AppError(
        type: AppErrorType.unknown,
        message: backendMessage.trim(),
        debugMessage: backendMessage,
        statusCode: status,
        code: backendCode,
        requestId: requestId,
        issues: issues,
      );
    }

    return AppError(
      type: AppErrorType.unknown,
      message: 'Something went wrong. Try again.',
      debugMessage: backendMessage ?? error.message,
      statusCode: status,
      code: backendCode,
      requestId: requestId,
    );
  }

  static bool _isAuthRequired(int? status, String? backendCode) {
    if (status == 401) return true;
    if (backendCode == null) return false;
    const authCodes = {
      'UNAUTHORIZED',
      'AUTH_REQUIRED',
      'INVALID_TOKEN',
      'TOKEN_EXPIRED',
      'MISSING_REFRESH_TOKEN',
    };
    return authCodes.contains(backendCode.toUpperCase());
  }

  static String _authMessageForFeature(String? feature) {
    final cleaned = feature?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      return 'Sign in to use this feature.';
    }
    return 'Sign in to $cleaned.';
  }

  /// Normalizes whatever Dio handed back into a `Map<String, dynamic>?`.
  ///
  /// Handles every shape the backend (or an intermediary proxy) can produce:
  /// - a decoded JSON object (the common case),
  /// - a JSON object serialized as a raw string (some error paths / proxies
  ///   return `content-type: text/plain` with a JSON body),
  /// - a JSON array (never a valid envelope — returns null so callers fall
  ///   back to a generic message rather than crash),
  /// - non-JSON plain text or an HTML error page (reverse proxy 502/504,
  ///   gateway timeouts) — returns null; the raw text is never shown to the
  ///   user, only reachable via `error.message`/`debugMessage` upstream.
  static Map<String, dynamic>? _decodeEnvelope(dynamic data) {
    if (data == null) return null;

    if (data is Map) return _asMap(data);

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      // Cheap pre-check avoids paying jsonDecode's exception cost on
      // obviously non-JSON bodies (HTML error pages, plain text).
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) return _asMap(decoded);
      } catch (_) {
        // Not JSON (HTML/plain text) — treated as no structured envelope.
      }
      return null;
    }

    // Lists and any other shape carry no extractable envelope.
    return null;
  }

  static String? _readBackendCode(Map<String, dynamic>? outer) {
    if (outer == null) return null;

    final error = _asMap(outer['error']);
    final code = error?['code']?.toString().trim();
    if (code != null && code.isNotEmpty) return code;

    final direct = outer['code']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    return null;
  }

  static String? _readBackendMessage(Map<String, dynamic>? outer) {
    if (outer == null) return null;

    final error = _asMap(outer['error']);
    final message = error?['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;

    final direct = outer['message']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    return null;
  }

  static String? _readRequestId(Map<String, dynamic>? outer) {
    if (outer == null) return null;

    final error = _asMap(outer['error']);
    final nested = error?['requestId']?.toString().trim();
    if (nested != null && nested.isNotEmpty) return nested;

    final direct = outer['requestId']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    return null;
  }

  /// `error.details.resolvable`, strictly as a boolean.
  ///
  /// Anything that is not literally `true` or `false` is reported as unknown
  /// rather than coerced. A string "false" coerced by truthiness would tell
  /// the UI to offer a retry precisely when the backend said not to.
  static bool? _readResolvable(Map<String, dynamic>? envelope) {
    final error = _asMap(envelope?['error']) ?? envelope;
    final details = _asMap(error?['details']);
    final value = details?['resolvable'];
    return value is bool ? value : null;
  }

  static List<String>? _readIssues(Map<String, dynamic>? outer) {
    if (outer == null) return null;

    final error = _asMap(outer['error']);
    final details = _asMap(error?['details']);
    final rawIssues = details?['issues'];
    if (rawIssues is! List) return null;

    final issues = rawIssues
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    return issues.isEmpty ? null : issues;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

/// The account operations whose failures have their own wording.
enum AuthOperation {
  /// Signing in from the sign-in form (the session controller's path).
  signIn,
  register,
  resendVerification,
  verifyEmail,
  forgotPassword,
  verifyCode,
  resendCode,
  resetPassword,

  /// Session, device and password management: the caller's own fallback.
  account,
}

/// The sentence to show when an account operation fails. One place for every
/// account message (they were spread over four mappers in three files, and
/// the defect lived between two of them). The wording is unchanged from the
/// mappers it replaces.
String authErrorMessage(
  Object error,
  AuthOperation operation, {
  String? fallback,
}) {
  if (error is! DioException) {
    return fallback ?? _AuthMessages.fallbackFor(operation);
  }
  return _AuthMessages.forDio(error, operation, fallback: fallback);
}

class _AuthMessages {
  const _AuthMessages._();

  static const _signInFallback =
      'We could not sign you in right now. Please try again.';

  static String fallbackFor(AuthOperation op) {
    switch (op) {
      case AuthOperation.signIn:
        return _signInFallback;
      case AuthOperation.register:
        return 'We could not create your account right now. Please try again.';
      case AuthOperation.resendVerification:
        return 'We could not resend the verification email right now. Please try again.';
      case AuthOperation.verifyEmail:
        return 'We could not verify your email right now. Please try again.';
      case AuthOperation.forgotPassword:
        return 'We could not send the reset email right now. Please try again.';
      case AuthOperation.verifyCode:
        return 'We could not verify the code right now. Please try again.';
      case AuthOperation.resendCode:
        return 'We could not resend the code right now. Please try again.';
      case AuthOperation.resetPassword:
        return 'We could not reset your password right now. Please try again.';
      case AuthOperation.account:
        return 'Something went wrong. Please try again.';
    }
  }

  static String forDio(DioException e, AuthOperation op, {String? fallback}) {
    if (op == AuthOperation.signIn) return _signIn(e);
    final base = fallback ?? fallbackFor(op);
    final common = _commonInfra(e);
    if (common != null) return common;
    switch (op) {
      case AuthOperation.register:
        return _register(e, base);
      case AuthOperation.resendVerification:
        return _resendVerification(e, base);
      case AuthOperation.verifyEmail:
        return _verifyEmail(e, base);
      case AuthOperation.forgotPassword:
        return _forgotPassword(e, base);
      case AuthOperation.verifyCode:
        return _verifyCode(e, base);
      case AuthOperation.resendCode:
        return _resendCode(e, base);
      case AuthOperation.resetPassword:
        return _resetPassword(e, base);
      case AuthOperation.account:
      case AuthOperation.signIn:
        return base;
    }
  }

  static String serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final nestedError = data['error'];
      if (nestedError is Map) {
        for (final c in [
          nestedError['message'],
          nestedError['error'],
          nestedError['detail'],
          nestedError['title'],
        ]) {
          final s = c?.toString().trim() ?? '';
          if (s.isNotEmpty) return s;
        }
      }
      for (final c in [
        data['message'],
        data['error'],
        data['detail'],
        data['title'],
      ]) {
        final s = c?.toString().trim() ?? '';
        if (s.isNotEmpty) return s;
      }
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return '';
  }

  static String serverCode(DioException e) {
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

  static bool _looksLikeNetwork(DioException e) {
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

  /// The shared network, rate-limit and server answers, or null.
  static String? _commonInfra(DioException e) {
    if (_looksLikeNetwork(e)) {
      return 'We could not reach the server. Check your connection and try again.';
    }
    final code = e.response?.statusCode;
    final server = serverMessage(e).toLowerCase();
    if (code == 429 || server.contains('too many requests')) {
      return 'Too many attempts in a short time. Please wait a little and try again.';
    }
    if (code != null && code >= 500) {
      return 'Something went wrong on our side. Please try again in a moment.';
    }
    return null;
  }

  static String _signIn(DioException e) {
    final code = e.response?.statusCode;
    final backendCode = serverCode(e).toUpperCase();
    final server = serverMessage(e).toLowerCase();

    // No answer at all: the device could not reach Aura (21 Oct 2026).
    if (e.response == null &&
        (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.unknown)) {
      return 'Aura could not be reached. Check that this device is connected to the internet, then try again.';
    }

    // Too many attempts from this connection: say so, and for how long.
    if (code == 429 || backendCode == 'RATE_LIMITED') {
      final data = e.response?.data;
      final details = data is Map && data['error'] is Map
          ? (data['error'] as Map)['details']
          : null;
      final wait = details is Map
          ? int.tryParse('${details['retryAfterSeconds']}')
          : null;
      final when = wait == null || wait <= 0
          ? 'in a few minutes'
          : wait < 90
          ? 'in about $wait seconds'
          : 'in about ${(wait / 60).ceil()} minutes';
      return 'Too many sign-in attempts from this connection. Please try again $when.';
    }

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

    return _signInFallback;
  }

  static String _register(DioException e, String base) {
    final code = e.response?.statusCode;
    final backendCode = serverCode(e).toUpperCase();
    final server = serverMessage(e).toLowerCase();

    // An age refusal is final and said once: the server's sentence, no retry.
    if (backendCode == 'ACCOUNT_AGE_INELIGIBLE') {
      final message = serverMessage(e).trim();
      return message.isEmpty
          ? 'You are not old enough to have an Aura account.'
          : message;
    }
    if (backendCode == 'DOB_REQUIRED') {
      return 'Enter your date of birth to create an account.';
    }
    if (backendCode == 'JURISDICTION_REQUIRED') {
      return 'Select where you are to create an account.';
    }
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
    return base;
  }

  static String _resendVerification(DioException e, String base) {
    final code = e.response?.statusCode;
    final server = serverMessage(e).toLowerCase();
    if (code == 400 || server.contains('already verified')) {
      return 'This email is already verified.';
    }
    if (code == 404 || server.contains('not found')) {
      return 'We could not find an account with that email.';
    }
    return base;
  }

  static String _verifyEmail(DioException e, String base) {
    final code = e.response?.statusCode;
    final server = serverMessage(e).toLowerCase();
    if (code == 400 ||
        server.contains('invalid token') ||
        server.contains('expired token') ||
        server.contains('token expired')) {
      return 'That verification link is no longer valid. Please request a new one.';
    }
    if (server.contains('already verified')) {
      return 'Your email is already verified. You can sign in now.';
    }
    return base;
  }

  static String _forgotPassword(DioException e, String base) {
    final code = e.response?.statusCode;
    final server = serverMessage(e).toLowerCase();
    if (code == 404 || server.contains('not found')) {
      return 'We could not find an account with that email.';
    }
    return base;
  }

  static String _verifyCode(DioException e, String base) {
    final code = e.response?.statusCode;
    final server = serverMessage(e).toLowerCase();
    if (code == 401 ||
        server.contains('incorrect code') ||
        server.contains('invalid code')) {
      return 'That code is incorrect. Please check and try again.';
    }
    if (server.contains('expired')) {
      return 'That code has expired. Please request a new one.';
    }
    if (server.contains('already used') || server.contains('consumed')) {
      return 'That code has already been used. Please request a new one.';
    }
    if (code == 429 || server.contains('too many')) {
      return 'Too many attempts. Please request a new code.';
    }
    return base;
  }

  static String _resendCode(DioException e, String base) {
    final server = serverMessage(e).toLowerCase();
    if (server.contains('please wait') || e.response?.statusCode == 429) {
      final msg = serverMessage(e);
      return msg.isNotEmpty ? msg : 'Please wait before requesting a new code.';
    }
    if (server.contains('expired')) {
      return 'This sign-in session has expired. Please start again.';
    }
    return base;
  }

  static String _resetPassword(DioException e, String base) {
    final code = e.response?.statusCode;
    final server = serverMessage(e).toLowerCase();
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
    return base;
  }
}
