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

    final payload = _unwrapData(res.data);
    final items = _readListFromCommonKeys(
      payload,
      keys: const ['items', 'messages', 'results', 'data'],
    );

    return items.map(_asMap).toList();
  }

  Future<Map<String, dynamic>> sendMessage({
    required String threadId,
    required String body,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final payload = <String, dynamic>{
      'body': body.trim(),
      if (attachments.isNotEmpty) 'attachments': attachments,
    };

    final res = await _dio.post('/threads/$threadId/messages', data: payload);
    return _unwrapData(res.data);
  }

  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String body,
  }) async {
    final res = await _dio.patch(
      '/messages/$messageId',
      data: {'body': body.trim()},
    );
    return _unwrapData(res.data);
  }

  Future<void> deleteMessage(String messageId) async {
    await _dio.delete('/messages/$messageId');
  }
}

Map<String, dynamic> _unwrapData(dynamic raw) {
  final root = _asMap(raw);
  final data = root['data'];

  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);

  return root;
}

List<dynamic> _readListFromCommonKeys(
  Map<String, dynamic> map, {
  required List<String> keys,
}) {
  for (final key in keys) {
    final value = map[key];
    if (value is List) return value;
  }

  return const [];
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;