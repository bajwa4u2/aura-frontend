import 'dart:convert';

import 'package:dio/dio.dart';

import 'app_error.dart';

/// What the server said when it refused: its stable code and its own
/// sentence, read from either envelope shape the API produces —
/// `{ok:false, error:{code, message}}` or a flat `{code, message}`.
///
/// Both are null when the failure carried no body (a dropped connection, a
/// proxy's HTML page). Callers then say a plain sentence of their own; a raw
/// exception is never shown to a person.
class ServerRefusal {
  const ServerRefusal({this.code, this.message});

  final String? code;
  final String? message;

  bool get hasMessage => message != null && message!.isNotEmpty;

  static ServerRefusal of(Object error) {
    if (error is DioException) {
      final body = _decode(error.response?.data);
      if (body != null) {
        final nested = body['error'] is Map
            ? Map<String, dynamic>.from(body['error'] as Map)
            : null;
        final code = _text(nested?['code']) ?? _text(body['code']);
        // A 5xx body describes a fault on our side, not a refusal meant for
        // the person; its code is kept, its words are not shown.
        final status = error.response?.statusCode ?? 0;
        final message = status >= 500
            ? null
            : _text(nested?['message']) ?? _text(body['message']);
        if (code != null || message != null) {
          return ServerRefusal(code: code, message: message);
        }
      }
      // The interceptor maps every failure to an AppError; its code survives
      // even when the body was not a map we could read.
      final mapped = error.error;
      if (mapped is AppError) return ServerRefusal(code: mapped.code);
      return const ServerRefusal();
    }
    if (error is AppError) return ServerRefusal(code: error.code);
    return const ServerRefusal();
  }

  static Map<String, dynamic>? _decode(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final trimmed = data.trim();
      if (!trimmed.startsWith('{')) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static String? _text(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
