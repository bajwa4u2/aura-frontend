import 'package:dio/dio.dart';

class UpdatesRepository {
  UpdatesRepository(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listUpdates({int limit = 12}) async {
    // Endpoint naming can differ; this is the most common.
    // If your backend uses /v1/notifications, swap the path here.
    final res = await _dio.get(
      '/updates',
      queryParameters: <String, dynamic>{'limit': limit},
    );

    final raw = res.data;

    // Accept raw list response
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }

    // Accept envelope responses
    if (raw is Map) {
      final root = raw.cast<String, dynamic>();
      final d1 = root['data'];
      final d2 = (d1 is Map) ? (d1['data'] ?? d1['items']) : null;

      final items = (d2 is List)
          ? d2
          : (root['items'] is List ? root['items'] : (root['data'] is List ? root['data'] : const []));

      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }
    }

    return const <Map<String, dynamic>>[];
  }

  Future<void> markRead(String t) async {
    // Updates are currently a view over the public feed; read-tracking is not implemented yet.
    return;
  }

  Future<void> markAllRead() async {
    // No-op until server implements read-tracking.
    return;
  }
}