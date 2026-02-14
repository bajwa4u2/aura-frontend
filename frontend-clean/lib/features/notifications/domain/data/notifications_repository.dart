import 'package:dio/dio.dart';
import '../domain/notification_item.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  /// GET /notifications
  /// Returns: { data: [...] }
  Future<List<NotificationItem>> fetchNotifications() async {
    final res = await _dio.get('/notifications');

    final raw = (res.data as Map).cast<String, dynamic>();
    final list = (raw['data'] as List? ?? const []).cast<dynamic>();

    return list
        .map((e) => NotificationItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// POST /notifications/:id/read
  Future<void> markRead(String id) async {
    await _dio.post('/notifications/$id/read');
  }
}
