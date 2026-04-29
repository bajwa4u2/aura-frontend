import 'package:dio/dio.dart';

import 'support_models.dart';

class SupportRepository {
  SupportRepository(this._dio);

  final Dio _dio;

  Future<SupportConversation> startConversation({
    String? source,
    String? institutionId,
    String? initialMessage,
  }) async {
    final res = await _dio.post('/support/conversations', data: {
      if (source != null) 'source': source,
      if (institutionId != null) 'institutionId': institutionId,
      if (initialMessage != null) 'initialMessage': initialMessage,
    });
    return SupportConversation.fromJson(_unwrap(res.data));
  }

  Future<List<SupportMessage>> sendMessage({
    required String conversationId,
    required String content,
    String? sessionToken,
  }) async {
    final res = await _dio.post(
      '/support/conversations/$conversationId/messages',
      data: {
        'content': content,
        if (sessionToken != null) 'sessionToken': sessionToken,
      },
    );
    final payload = _unwrap(res.data);
    final raw = (payload['messages'] as List<dynamic>?) ?? [];
    return raw
        .map((m) => SupportMessage.fromJson(_asMap(m)))
        .toList();
  }

  Future<SupportEscalateResult> escalate({
    required String conversationId,
    String? sessionToken,
    String? requesterEmail,
    String? requesterName,
  }) async {
    final res = await _dio.post(
      '/support/conversations/$conversationId/escalate',
      data: {
        if (sessionToken != null) 'sessionToken': sessionToken,
        if (requesterEmail != null) 'requesterEmail': requesterEmail,
        if (requesterName != null) 'requesterName': requesterName,
      },
    );
    return SupportEscalateResult.fromJson(_unwrap(res.data));
  }

  Future<SupportConversation> getConversation({
    required String conversationId,
    String? sessionToken,
  }) async {
    final res = await _dio.get(
      '/support/conversations/$conversationId',
      queryParameters: {
        if (sessionToken != null) 'sessionToken': sessionToken,
      },
    );
    return SupportConversation.fromJson(_unwrap(res.data));
  }

  // ── Admin ─────────────────────────────────────────────────────────────────

  Future<SupportAdminListResult> adminListCases({
    String? status,
    String? category,
    String? severity,
    String? search,
    int skip = 0,
    int take = 20,
  }) async {
    final res = await _dio.get('/admin/support/cases', queryParameters: {
      if (status != null) 'status': status,
      if (category != null) 'category': category,
      if (severity != null) 'severity': severity,
      if (search != null && search.isNotEmpty) 'search': search,
      'skip': skip,
      'take': take,
    });
    return SupportAdminListResult.fromJson(_unwrap(res.data));
  }

  Future<Map<String, dynamic>> adminGetCase(String caseId) async {
    final res = await _dio.get('/admin/support/cases/$caseId');
    return _unwrap(res.data);
  }

  Future<void> adminChangeStatus(String caseId, String status,
      {String? note}) async {
    await _dio.patch('/admin/support/cases/$caseId/status', data: {
      'status': status,
      if (note != null) 'note': note,
    });
  }

  Future<void> adminAssign(String caseId,
      {String? assignedAdminId}) async {
    await _dio.patch('/admin/support/cases/$caseId/assign', data: {
      'assignedAdminId': assignedAdminId,
    });
  }

  Future<void> adminReply(String caseId, String content) async {
    await _dio.post('/admin/support/cases/$caseId/reply',
        data: {'content': content});
  }

  Future<Map<String, dynamic>> adminAiDraft(String caseId) async {
    final res = await _dio.get('/admin/support/cases/$caseId/ai-draft');
    return _unwrap(res.data);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Peels the global `{ ok: true, data: <payload> }` envelope that
/// ResponseWrapInterceptor adds to every backend response.
/// Falls back to the raw map if the envelope is absent.
Map<String, dynamic> _unwrap(dynamic raw) {
  if (raw is Map) {
    final outer = Map<String, dynamic>.from(raw);
    final inner = outer['data'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return outer;
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
