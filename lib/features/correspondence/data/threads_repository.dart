import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

final threadsRepositoryProvider = Provider<ThreadsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ThreadsRepository(dio);
});

class ThreadsRepository {
  ThreadsRepository(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listThreads({
    required String spaceId,
  }) async {
    final res = await _dio.get('/spaces/$spaceId/threads');

    final payload = res.data;
    final items = _extractList(payload);

    return items.map(_asMap).toList();
  }

  Future<Map<String, dynamic>> getThread(String threadId) async {
    final res = await _dio.get('/threads/$threadId');
    return _unwrapData(res.data);
  }

  Future<Map<String, dynamic>> createThread({
    required String spaceId,
    required String title,
    String? kind,
    List<String> memberIds = const [],
  }) async {
    final body = <String, dynamic>{
      'title': title.trim(),
      if (_hasText(kind)) 'kind': kind!.trim(),
      if (memberIds.isNotEmpty) 'memberIds': memberIds,
    };

    final res = await _dio.post(
      '/spaces/$spaceId/threads',
      data: body,
    );

    return _unwrapData(res.data);
  }

  Future<Map<String, dynamic>> updateThread(
    String threadId, {
    String? title,
    String? kind,
    bool? archived,
  }) async {
    final body = <String, dynamic>{
      if (_hasText(title)) 'title': title!.trim(),
      if (_hasText(kind)) 'kind': kind!.trim(),
      if (archived != null) 'archived': archived,
    };

    final res = await _dio.patch(
      '/threads/$threadId',
      data: body,
    );

    return _unwrapData(res.data);
  }

  Future<Map<String, dynamic>> markThreadRead(String threadId) async {
    final res = await _dio.post('/threads/$threadId/read');
    return _unwrapData(res.data);
  }
}

List<dynamic> _extractList(dynamic raw) {
  if (raw is List) return raw;

  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);

    final data = map['data'];
    if (data is List) return data;

    for (final key in ['items', 'threads', 'results']) {
      final value = map[key];
      if (value is List) return value;
    }
  }

  return const [];
}

Map<String, dynamic> _unwrapData(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);

    final data = map['data'];

    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    return map;
  }

  return <String, dynamic>{};
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