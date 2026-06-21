import 'package:dio/dio.dart';

import 'participation_models.dart';

class ParticipationRepository {
  ParticipationRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return {};
  }

  Future<List<InstitutionParticipation>> list(String institutionId) async {
    final res = await _dio.get('/institutions/$institutionId/participation');
    final root = _unwrap(res.data);
    final raw = (root['data'] ?? root['items'] ?? root) as dynamic;
    final items = raw is List ? raw : (raw is Map ? [raw] : <dynamic>[]);
    return items
        .whereType<Map>()
        .map((e) => InstitutionParticipation.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  Future<InstitutionParticipation> create({
    required String institutionId,
    required String topic,
    required String mode,
    String? jurisdictionId,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'topic': topic,
      'mode': mode,
      if ((jurisdictionId ?? '').trim().isNotEmpty)
        'jurisdictionId': jurisdictionId!.trim(),
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    };
    final res = await _dio.post(
      '/institutions/$institutionId/participation',
      data: payload,
    );
    final root = _unwrap(res.data);
    final record = root['data'] ?? root;
    return InstitutionParticipation.fromJson(_unwrap(record));
  }

  Future<InstitutionParticipation> updateStatus({
    required String institutionId,
    required String participationId,
    required String status,
  }) async {
    final res = await _dio.patch(
      '/institutions/$institutionId/participation/$participationId',
      data: {'status': status},
    );
    final root = _unwrap(res.data);
    final record = root['data'] ?? root;
    return InstitutionParticipation.fromJson(_unwrap(record));
  }
}
