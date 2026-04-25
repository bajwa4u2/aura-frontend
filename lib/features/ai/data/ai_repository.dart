import 'package:dio/dio.dart';

class AiRepositoryException implements Exception {
  const AiRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiRepository {
  AiRepository(this._dio);
  final Dio _dio;

  /// Legacy endpoint (kept for compatibility)
  Future<Map<String, dynamic>> claimAudit({
    required String text,
    String? locale,
  }) async {
    final payload = <String, dynamic>{
      'text': text,
      if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
    };

    final res = await _post('/ai/claim-audit', payload);

    final raw = res.data;

    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }

    if (raw is Map) {
      return Map<String, dynamic>.from(raw.cast<String, dynamic>());
    }

    return <String, dynamic>{'raw': raw};
  }

  /// New Aura Editor endpoint
  Future<Map<String, dynamic>> editorReview({
    required String text,
    String? locale,
  }) async {
    final payload = <String, dynamic>{
      'text': text,
      if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
    };

    final res = await _post('/ai/editor-review', payload);

    final raw = res.data;

    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }

    if (raw is Map) {
      return Map<String, dynamic>.from(raw.cast<String, dynamic>());
    }

    return <String, dynamic>{'raw': raw};
  }

  Future<Response<dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _dio.post(path, data: payload);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) rethrow;
      throw AiRepositoryException(_messageForDio(e));
    }
  }

  String _messageForDio(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    final backendCode =
        _readString(body, const ['error', 'code']) ??
        _readString(body, const ['code']);
    final backendMessage =
        _readString(body, const ['error', 'message']) ??
        _readString(body, const ['message']);

    if (backendCode == 'AI_POLICY_BLOCKED' || status == 422) {
      return backendMessage ??
          'Aura Editor could not review this text because a safety policy blocked the request.';
    }

    if (status == 401) {
      return 'Sign in to use Aura Editor.';
    }

    if (status == 403) {
      return backendMessage ?? 'Aura Editor is not available for this account.';
    }

    if (status == 429) {
      return 'Aura Editor is receiving too many requests. Try again shortly.';
    }

    if (status != null && status >= 500) {
      return 'Aura Editor is temporarily unavailable. Try again shortly.';
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Aura Editor took too long to respond. Try again.';
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return 'Aura Editor is unavailable while the connection is offline.';
      case DioExceptionType.cancel:
        return 'Aura Editor request was cancelled.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return backendMessage ?? 'Aura Editor could not run. Try again.';
    }
  }

  String? _readString(dynamic value, List<String> path) {
    dynamic current = value;
    for (final segment in path) {
      if (current is Map) {
        current = current[segment];
      } else {
        return null;
      }
    }
    final text = current?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
