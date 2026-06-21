import 'package:dio/dio.dart';

import 'engagement_models.dart';

class EngagementRepository {
  EngagementRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return {};
  }

  Future<List<RoutedRecord>> list(
    String institutionId, {
    String? status,
  }) async {
    final res = await _dio.get(
      '/institutions/$institutionId/engagement',
      queryParameters: {
        if ((status ?? '').isNotEmpty) 'status': status,
      },
    );
    final root = _unwrap(res.data);
    final raw = root['data'] ?? root['items'] ?? root;
    final items = raw is List ? raw : (raw is Map ? [raw] : <dynamic>[]);
    return items
        .whereType<Map>()
        .map((e) => RoutedRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<RoutedRecord> getDetail(
    String institutionId,
    String recordId,
  ) async {
    final res = await _dio.get(
      '/institutions/$institutionId/engagement/$recordId',
    );
    final root = _unwrap(res.data);
    final record = root['data'] ?? root;
    return RoutedRecord.fromJson(_unwrap(record));
  }

  Future<EngagementSummary> getSummary(String institutionId) async {
    final res = await _dio.get(
      '/institutions/$institutionId/engagement/summary',
    );
    return EngagementSummary.fromJson(_unwrap(res.data));
  }
}
