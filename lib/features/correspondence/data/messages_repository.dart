import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MessagesRepository(dio);
});

class MessagesRepository {
  MessagesRepository(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listMessages({
    required String threadId,
    int limit = 50,
    String? cursor,
  }) async {
    final res = await _dio.get(
      '/threads/$threadId/messages',
      queryParameters: {
        'limit': limit,
        if (_hasText(cursor)) 'cursor': cursor,
      },
    );

    final items = _extractList(res.data);
    return items.map(_asMap).toList();
  }

  Future<Map<String, dynamic>> sendMessage({
    required String threadId,
    String? body,
    List<Map<String, dynamic>> attachments = const [],
    String? sourceLanguage,
    Map<String, dynamic>? composition,
    Map<String, dynamic>? translation,
  }) async {
    final payload = <String, dynamic>{
      if (_hasText(body)) 'body': body!.trim(),
      if (attachments.isNotEmpty) 'attachments': attachments,
      if (_hasText(sourceLanguage)) 'sourceLanguage': sourceLanguage!.trim(),
      if (composition != null && composition.isNotEmpty) 'composition': composition,
      if (translation != null && translation.isNotEmpty) 'translation': translation,
    };

    final res = await _dio.post(
      '/threads/$threadId/messages',
      data: payload,
    );

    return _unwrapMap(res.data);
  }

  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String body,
    String? sourceLanguage,
    Map<String, dynamic>? composition,
    Map<String, dynamic>? translation,
  }) async {
    final payload = <String, dynamic>{
      'body': body.trim(),
      if (_hasText(sourceLanguage)) 'sourceLanguage': sourceLanguage!.trim(),
      if (composition != null && composition.isNotEmpty) 'composition': composition,
      if (translation != null && translation.isNotEmpty) 'translation': translation,
    };

    final res = await _dio.patch(
      '/messages/$messageId',
      data: payload,
    );

    return _unwrapMap(res.data);
  }

  Future<void> deleteMessage(String messageId) async {
    await _dio.delete('/messages/$messageId');
  }

  Future<Map<String, dynamic>> previewTranslation({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final payload = <String, dynamic>{
      'text': text.trim(),
      'targetLanguage': targetLanguage.trim(),
      if (_hasText(sourceLanguage)) 'sourceLanguage': sourceLanguage!.trim(),
    };

    try {
      final res = await _dio.post('/composition/translate', data: payload);
      final map = _unwrapMap(res.data);
      return {
        'translatedText': _pickString(
          map,
          const ['translatedText', 'text', 'translation', 'translated_text'],
        ),
        'targetLanguage': _pickString(
          map,
          const ['targetLanguage', 'language', 'target_language'],
        ).isEmpty
            ? targetLanguage.trim()
            : _pickString(
                map,
                const ['targetLanguage', 'language', 'target_language'],
              ),
        'sourceLanguage': _pickString(
          map,
          const ['sourceLanguage', 'source_language'],
        ).isEmpty
            ? (sourceLanguage ?? '')
            : _pickString(map, const ['sourceLanguage', 'source_language']),
        'raw': map,
      };
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> reviewDraft({
    required String text,
    required String surface,
  }) async {
    final payload = <String, dynamic>{
      'text': text,
      'surface': surface,
    };

    try {
      final res = await _dio.post('/composition/review', data: payload);
      return _unwrapMap(res.data);
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> applyDraftSuggestion({
    required String sessionId,
    required String findingId,
    required String currentText,
  }) async {
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'findingId': findingId,
      'currentText': currentText,
    };

    try {
      final res = await _dio.post('/composition/apply', data: payload);
      return _unwrapMap(res.data);
    } on DioException {
      rethrow;
    }
  }
}

List<dynamic> _extractList(dynamic raw) {
  if (raw is List) return raw;

  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);

    for (final key in ['items', 'messages', 'results']) {
      final value = map[key];
      if (value is List) return value;
    }

    final data = map['data'];
    if (data is List) return data;

    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);

      for (final key in ['items', 'messages', 'results']) {
        final value = dataMap[key];
        if (value is List) return value;
      }
    }
  }

  return const [];
}

Map<String, dynamic> _unwrapMap(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);

    final data = map['data'];

    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    return map;
  }

  return <String, dynamic>{};
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
