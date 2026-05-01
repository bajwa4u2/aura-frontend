import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/institution.dart';

final institutionsRepositoryProvider = Provider<InstitutionsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return InstitutionsRepository(dio);
});

final pendingInstitutionRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listVerificationRequests(status: 'UNDER_REVIEW');
});

final verifiedInstitutionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listInstitutions(status: 'VERIFIED');
});

final suspendedInstitutionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listInstitutions(status: 'SUSPENDED');
});

final rejectedInstitutionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listInstitutions(status: 'REJECTED');
});

final approveInstitutionRequestProvider =
    FutureProvider.family<void, String>((ref, requestId) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  await repo.approveVerificationRequest(requestId);
});

final rejectInstitutionRequestProvider =
    FutureProvider.family<void, String>((ref, requestId) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  await repo.rejectVerificationRequest(requestId);
});

class InstitutionsRepository {
  InstitutionsRepository(this._dio);

  final dynamic _dio;

  Future<Institution> getBySlug(String slug) async {
    final cleanSlug = slug.trim();
    if (cleanSlug.isEmpty) {
      throw Exception('Institution slug is missing.');
    }

    final res = await _dio.get('/institutions/$cleanSlug');
    final body = res.data;

    if (body is Map) {
      final root = Map<String, dynamic>.from(body);

      final directInstitution = root['institution'];
      if (directInstitution is Map) {
        return Institution.fromJson(
          Map<String, dynamic>.from(directInstitution),
        );
      }

      final data = root['data'];
      if (data is Map) {
        final dataMap = Map<String, dynamic>.from(data);

        final nestedInstitution = dataMap['institution'];
        if (nestedInstitution is Map) {
          return Institution.fromJson(
            Map<String, dynamic>.from(nestedInstitution),
          );
        }

        return Institution.fromJson(dataMap);
      }

      final item = root['item'];
      if (item is Map) {
        return Institution.fromJson(
          Map<String, dynamic>.from(item),
        );
      }

      return Institution.fromJson(root);
    }

    throw Exception('Unexpected institution response.');
  }

  Future<List<Map<String, dynamic>>> listVerificationRequests({
    required String status,
  }) async {
    final res = await _dio.get(
      '/institutions/admin/verification-requests',
      queryParameters: {'status': status},
    );
    return _readItems(res.data);
  }

  Future<List<Map<String, dynamic>>> listInstitutions({
    required String status,
  }) async {
    final res = await _dio.get(
      '/institutions/admin',
      queryParameters: {'status': status},
    );
    return _readItems(res.data);
  }

  Future<void> approveVerificationRequest(String requestId) async {
    final id = requestId.trim();
    if (id.isEmpty) {
      throw Exception('Request id is missing.');
    }

    await _dio.post('/institutions/admin/verification-requests/$id/approve');
  }

  Future<void> rejectVerificationRequest(String requestId) async {
    final id = requestId.trim();
    if (id.isEmpty) {
      throw Exception('Request id is missing.');
    }

    await _dio.post('/institutions/admin/verification-requests/$id/reject');
  }

  Future<Map<String, dynamic>> listMembers(String institutionId) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    final res = await _dio.get('/institutions/$id/members');
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return <String, dynamic>{};
  }

  Future<void> removeMember(String institutionId, String targetUserId) async {
    final id = institutionId.trim();
    final uid = targetUserId.trim();
    if (id.isEmpty || uid.isEmpty) throw Exception('Institution or user id is missing.');
    await _dio.delete('/institutions/$id/members/$uid');
  }

  Future<Map<String, dynamic>> createInvite(
    String institutionId, {
    String? email,
    String? role,
    int? expiresInDays,
  }) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    final res = await _dio.post(
      '/institutions/$id/invites',
      data: <String, dynamic>{
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
        if (expiresInDays != null) 'expiresInDays': expiresInDays,
      },
    );
    if (res.data is Map) {
      final root = Map<String, dynamic>.from(res.data as Map);
      final invite = root['invite'];
      if (invite is Map) return Map<String, dynamic>.from(invite);
    }
    throw Exception('Unexpected response from create invite.');
  }

  Future<List<Map<String, dynamic>>> listInvites(String institutionId) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    final res = await _dio.get('/institutions/$id/invites');
    if (res.data is Map) {
      final root = Map<String, dynamic>.from(res.data as Map);
      final invites = root['invites'];
      if (invites is List) {
        return invites.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> updateMemberRole(
    String institutionId,
    String targetUserId,
    String role,
  ) async {
    final id = institutionId.trim();
    final uid = targetUserId.trim();
    if (id.isEmpty || uid.isEmpty) throw Exception('Institution or user id is missing.');
    final res = await _dio.patch(
      '/institutions/$id/members/$uid/role',
      data: <String, dynamic>{'role': role},
    );
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return <String, dynamic>{};
  }

  Future<void> revokeInvite(String institutionId, String inviteId) async {
    final id = institutionId.trim();
    final iid = inviteId.trim();
    if (id.isEmpty || iid.isEmpty) throw Exception('Institution or invite id is missing.');
    await _dio.delete('/institutions/$id/invites/$iid');
  }

  Future<Map<String, dynamic>> createJoinRequest(
    String institutionId, {
    String? message,
  }) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    final res = await _dio.post(
      '/institutions/$id/join-requests',
      data: <String, dynamic>{
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      },
    );
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listJoinRequests(String institutionId) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    final res = await _dio.get('/institutions/$id/join-requests');
    if (res.data is Map) {
      final root = Map<String, dynamic>.from(res.data as Map);
      final requests = root['requests'];
      if (requests is List) {
        return requests.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> approveJoinRequest(
    String institutionId,
    String requestId, {
    String? note,
  }) async {
    final id = institutionId.trim();
    final rid = requestId.trim();
    if (id.isEmpty || rid.isEmpty) throw Exception('Institution or request id is missing.');
    await _dio.post(
      '/institutions/$id/join-requests/$rid/approve',
      data: <String, dynamic>{
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<void> rejectJoinRequest(
    String institutionId,
    String requestId, {
    String? note,
  }) async {
    final id = institutionId.trim();
    final rid = requestId.trim();
    if (id.isEmpty || rid.isEmpty) throw Exception('Institution or request id is missing.');
    await _dio.post(
      '/institutions/$id/join-requests/$rid/reject',
      data: <String, dynamic>{
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  // ── Institution Announcements ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listInstitutionAnnouncements(String institutionId) async {
    final res = await _dio.get('/institutions/$institutionId/announcements');
    if (res.data is Map) {
      final root = Map<String, dynamic>.from(res.data as Map);
      final items = root['items'];
      if (items is List) return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> listInstitutionDrafts(String institutionId) async {
    final res = await _dio.get('/institutions/$institutionId/announcements/drafts');
    if (res.data is Map) {
      final root = Map<String, dynamic>.from(res.data as Map);
      final items = root['items'];
      if (items is List) return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createInstitutionAnnouncement(
    String institutionId, {
    required String title,
    required String summary,
    required String bodyMarkdown,
    String kind = 'GENERAL',
    String audience = 'PUBLIC',
  }) async {
    final res = await _dio.post(
      '/institutions/$institutionId/announcements',
      data: <String, dynamic>{
        'title': title,
        'summary': summary,
        'excerpt': summary,
        'bodyMarkdown': bodyMarkdown,
        'kind': kind,
        'audience': audience,
      },
    );
    if (res.data is Map) {
      final root = Map<String, dynamic>.from(res.data as Map);
      final item = root['item'];
      if (item is Map) return Map<String, dynamic>.from(item);
    }
    throw Exception('Unexpected response from create announcement.');
  }

  Future<Map<String, dynamic>> updateInstitutionAnnouncement(
    String institutionId,
    String announcementId, {
    String? title,
    String? summary,
    String? bodyMarkdown,
    String? kind,
    String? audience,
  }) async {
    final res = await _dio.patch(
      '/institutions/$institutionId/announcements/$announcementId',
      data: <String, dynamic>{
        if (title != null) 'title': title,
        if (summary != null) 'summary': summary,
        if (summary != null) 'excerpt': summary,
        if (bodyMarkdown != null) 'bodyMarkdown': bodyMarkdown,
        if (kind != null) 'kind': kind,
        if (audience != null) 'audience': audience,
      },
    );
    if (res.data is Map) {
      final root = Map<String, dynamic>.from(res.data as Map);
      final item = root['item'];
      if (item is Map) return Map<String, dynamic>.from(item);
    }
    throw Exception('Unexpected response from update announcement.');
  }

  Future<void> publishInstitutionAnnouncement(String institutionId, String announcementId) async {
    await _dio.post('/institutions/$institutionId/announcements/$announcementId/publish');
  }

  Future<void> unpublishInstitutionAnnouncement(String institutionId, String announcementId) async {
    await _dio.post('/institutions/$institutionId/announcements/$announcementId/unpublish');
  }

  Future<void> deleteInstitutionAnnouncement(String institutionId, String announcementId) async {
    await _dio.delete('/institutions/$institutionId/announcements/$announcementId');
  }

  // ── Institution Spaces ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listInstitutionSpaces(String institutionId) async {
    final res = await _dio.get('/institutions/$institutionId/spaces');
    if (res.data is Map) {
      final root = Map<String, dynamic>.from(res.data as Map);
      final spaces = root['spaces'];
      if (spaces is List) return spaces.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createInstitutionSpace(
    String institutionId, {
    required String title,
    String? description,
    String visibility = 'INVITE_ONLY',
  }) async {
    final res = await _dio.post(
      '/institutions/$institutionId/spaces',
      data: <String, dynamic>{
        'title': title,
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        'visibility': visibility,
      },
    );
    if (res.data is Map) {
      final root = Map<String, dynamic>.from(res.data as Map);
      final space = root['space'];
      if (space is Map) return Map<String, dynamic>.from(space);
    }
    throw Exception('Unexpected response from create space.');
  }

  Future<void> archiveInstitutionSpace(String institutionId, String spaceId) async {
    await _dio.delete('/institutions/$institutionId/spaces/$spaceId');
  }

  Future<void> joinInstitutionSpace(String institutionId, String spaceId) async {
    await _dio.post('/institutions/$institutionId/spaces/$spaceId/join');
  }

  List<Map<String, dynamic>> _readItems(dynamic body) {
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);

      final directItems = root['items'];
      if (directItems is List) {
        return directItems
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final data = root['data'];
      if (data is Map) {
        final dataMap = Map<String, dynamic>.from(data);

        final nestedItems = dataMap['items'];
        if (nestedItems is List) {
          return nestedItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }

    if (body is List) {
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }
}