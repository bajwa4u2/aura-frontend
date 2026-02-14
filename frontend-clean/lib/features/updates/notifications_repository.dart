import 'package:dio/dio.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  /// List notifications (AUTH REQUIRED)
  Future<List<Map<String, dynamic>>> list({int limit = 20}) async {
    final res = await _dio.get(
      '/notifications',
      queryParameters: {'limit': limit},
    );

    final body = res.data;

    // Backend returns { data: [...] }
    final items =
        (body is Map && body['data'] is List) ? body['data'] as List : const [];

    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Mark a single notification as read
  Future<void> markRead(String id) async {
    await _dio.post('/notifications/$id/read');
  }

  /// Mark all notifications as read
  Future<void> markAllRead() async {
    await _dio.post('/notifications/read-all');
  }
}
