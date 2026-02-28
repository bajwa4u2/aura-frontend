import 'package:dio/dio.dart';

class AiRepository {
  AiRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> claimAudit({
    required String text,
    String? locale,
  }) async {
    final payload = <String, dynamic>{
      'text': text,
      if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
    };

    final res = await _dio.post('/ai/claim-audit', data: payload);

    // Expected envelope: { ok:true, data:{...} } or direct map.
    final raw = res.data;
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw.cast<String, dynamic>());
    return <String, dynamic>{'raw': raw};
  }
}
