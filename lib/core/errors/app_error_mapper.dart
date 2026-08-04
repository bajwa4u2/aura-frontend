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

  static AppError from(
    Object error, {
    String? feature,
  }) {
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

  static AppError _fromDio(
    DioException error, {
    String? feature,
  }) {
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
