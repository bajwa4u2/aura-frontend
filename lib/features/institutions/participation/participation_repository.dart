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
    // The server answers `{ ok, participations: [...] }` (seen live, 9 Oct
    // 2026). Reading only `data`/`items` turned the whole envelope into one
    // record: "Unknown topic · Responding · Inactive" in place of the four
    // real topics. An envelope is never itself a record.
    final raw = (root['participations'] ?? root['data'] ?? root['items']) as dynamic;
    final items = raw is List ? raw : <dynamic>[];
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
    return InstitutionParticipation.fromJson(_record(res.data));
  }

  /// One record from `{ ok, participation: {...} }`. Reading the envelope as
  /// the record lost the new topic's id, so "start answering now" had no id
  /// to switch on and every topic taken on stayed inactive (9 Oct 2026).
  Map<String, dynamic> _record(dynamic body) {
    final root = _unwrap(body);
    return _unwrap(root['participation'] ?? root['data'] ?? root);
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
    return InstitutionParticipation.fromJson(_record(res.data));
  }
}
