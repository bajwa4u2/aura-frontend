import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../domain/explore_feed_item.dart';
import '../domain/institution.dart';
import '../domain/institution_activity_event.dart';
import '../domain/institution_post.dart';

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

  Future<Institution> getById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) throw Exception('Institution id is missing.');
    final res = await _dio.get('/institutions/id/$cleanId');
    final body = res.data;
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      final inst = root['institution'] ?? root['data'] ?? root;
      if (inst is Map) return Institution.fromJson(Map<String, dynamic>.from(inst));
    }
    throw Exception('Unexpected institution response.');
  }

  Future<Map<String, dynamic>> updateInstitutionProfile(
    String institutionId,
    Map<String, dynamic> fields,
  ) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');

    // Normalize: trim all string values, keep empty strings (backend treats them as null-clear)
    final data = <String, dynamic>{};
    for (final entry in fields.entries) {
      final v = entry.value;
      if (v is String) {
        data[entry.key] = v.trim();
      } else if (v != null) {
        data[entry.key] = v;
      }
    }

    final res = await _dio.patch('/institutions/$id', data: data);
    if (res.data is Map) {
      final root = Map<String, dynamic>.from(res.data as Map);
      // Unwrap response envelope: { ok, institution: {...} } or { data: { institution: {...} } }
      final inst = root['institution'] ?? root['data']?['institution'] ?? root['data'];
      if (inst is Map) return Map<String, dynamic>.from(inst);
      return root;
    }
    return <String, dynamic>{};
  }

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

  // ── Institution Live Rooms ────────────────────────────────────────────────

  Future<Map<String, dynamic>> listInstitutionLiveRooms(String institutionId) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    final res = await _dio.get('/institutions/$id/live');
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> startInstitutionLiveRoom(
    String institutionId, {
    String kind = 'AUDIO',
  }) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    final endpoint = kind == 'VIDEO'
        ? '/institutions/$id/live/video/start'
        : '/institutions/$id/live/audio/start';
    final res = await _dio.post(endpoint);
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    throw Exception('Unexpected response from start live room.');
  }

  Future<Map<String, dynamic>> joinInstitutionLiveRoom(
    String institutionId,
    String sessionId,
  ) async {
    final id = institutionId.trim();
    final sid = sessionId.trim();
    if (id.isEmpty || sid.isEmpty) throw Exception('Institution or session id is missing.');
    final res = await _dio.post('/institutions/$id/live/$sid/join');
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    throw Exception('Unexpected response from join live room.');
  }

  Future<Map<String, dynamic>> leaveInstitutionLiveRoom(
    String institutionId,
    String sessionId,
  ) async {
    final id = institutionId.trim();
    final sid = sessionId.trim();
    if (id.isEmpty || sid.isEmpty) throw Exception('Institution or session id is missing.');
    final res = await _dio.post('/institutions/$id/live/$sid/leave');
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> endInstitutionLiveRoom(
    String institutionId,
    String sessionId,
  ) async {
    final id = institutionId.trim();
    final sid = sessionId.trim();
    if (id.isEmpty || sid.isEmpty) throw Exception('Institution or session id is missing.');
    final res = await _dio.post('/institutions/$id/live/$sid/end');
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return <String, dynamic>{};
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

  // ── Institution Posts ─────────────────────────────────────────────────────

  Future<InstitutionPostPage> listInstitutionPosts({
    required String institutionId,
    String? scope,
    String? cursor,
    int? limit,
  }) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    final query = <String, dynamic>{
      if (scope != null && scope.trim().isNotEmpty) 'scope': scope.trim(),
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      if (limit != null) 'limit': limit,
    };
    final res = await _dio.get(
      '/institutions/$id/posts',
      queryParameters: query.isEmpty ? null : query,
    );
    final body = res.data;
    final items = <InstitutionPost>[];
    String? nextCursor;
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      final raw = root['items'];
      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          items.add(
            InstitutionPost.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
      final cur = root['nextCursor'];
      if (cur != null) {
        final s = cur.toString().trim();
        if (s.isNotEmpty) nextCursor = s;
      }
    }
    return InstitutionPostPage(items: items, nextCursor: nextCursor);
  }

  /// Returns the merged-feed entry shape from `/institutions/:id/posts/:postId`
  /// (single-post variant). Used by the institution-post detail screen.
  Future<InstitutionPost> getInstitutionPost({
    required String institutionId,
    required String postId,
  }) async {
    final iid = institutionId.trim();
    final pid = postId.trim();
    if (iid.isEmpty || pid.isEmpty) {
      throw Exception('institutionId and postId are required.');
    }
    // The list endpoint accepts a `id` filter implicitly via the page; here
    // we do not have a single-post endpoint yet. Since replies + the parent
    // post must be visible together, the detail screen pulls the parent
    // out of the same merged listing using the replies endpoint's parent
    // probe. For now we read from the institution feed as a fallback —
    // real single-post fetch is implemented as part of Phase 2 routing.
    // Phase 1.5 path: scan the listing until we hit the id, capped at 50.
    final res = await _dio.get('/institutions/$iid/posts',
        queryParameters: <String, dynamic>{'limit': 50});
    final body = res.data;
    if (body is Map) {
      final raw = body['items'];
      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          final m = Map<String, dynamic>.from(entry);
          if (m['id']?.toString().trim() == pid) {
            return InstitutionPost.fromJson(m);
          }
        }
      }
    }
    throw Exception('Institution post not found.');
  }

  /// Lists replies under an InstitutionPost. Visibility is enforced by the
  /// server — it returns 404 when the caller cannot view the parent.
  Future<InstitutionPostPage> listInstitutionPostReplies({
    required String institutionId,
    required String postId,
    String? cursor,
    int? limit,
  }) async {
    final iid = institutionId.trim();
    final pid = postId.trim();
    if (iid.isEmpty || pid.isEmpty) {
      throw Exception('institutionId and postId are required.');
    }
    final query = <String, dynamic>{
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      if (limit != null) 'limit': limit,
    };
    final res = await _dio.get(
      '/institutions/$iid/posts/$pid/replies',
      queryParameters: query.isEmpty ? null : query,
    );
    final body = res.data;
    final items = <InstitutionPost>[];
    String? nextCursor;
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      final raw = root['items'];
      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          items.add(
            InstitutionPost.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
      final cur = root['nextCursor'];
      if (cur != null) {
        final s = cur.toString().trim();
        if (s.isNotEmpty) nextCursor = s;
      }
    }
    return InstitutionPostPage(items: items, nextCursor: nextCursor);
  }

  /// Creates an InstitutionPost.
  ///
  /// `status` is sent as a query parameter (`?status=DRAFT|PUBLISHED`) — the
  /// backend's `CreateInstitutionPostDto` does not allow `status` in the body
  /// and will reject the request with `property status should not exist`.
  /// `payload` must contain only: title, body, mediaUrl?, visibility,
  /// distribution.
  Future<InstitutionPost> createInstitutionPost(
    String institutionId,
    Map<String, dynamic> payload, {
    String? status,
  }) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    final s = (status ?? '').trim().toUpperCase();
    final res = await _dio.post(
      '/institutions/$id/posts',
      data: payload,
      queryParameters: s.isNotEmpty ? <String, dynamic>{'status': s} : null,
    );
    final post = _readPost(res.data);
    if (kDebugMode) {
      debugPrint(
        '[InstitutionsRepository] createInstitutionPost: '
        'sent ?status=${s.isEmpty ? "<none>" : s}, '
        'savedStatus=${post.status.wire}, '
        'id=${post.id}',
      );
    }
    return post;
  }

  Future<InstitutionPost> updateInstitutionPost(
    String institutionId,
    String postId,
    Map<String, dynamic> payload,
  ) async {
    final id = institutionId.trim();
    final pid = postId.trim();
    if (id.isEmpty || pid.isEmpty) {
      throw Exception('Institution or post id is missing.');
    }
    final res = await _dio.patch(
      '/institutions/$id/posts/$pid',
      data: payload,
    );
    return _readPost(res.data);
  }

  Future<InstitutionPost> submitInstitutionPost(
    String institutionId,
    String postId,
  ) async {
    final id = institutionId.trim();
    final pid = postId.trim();
    if (id.isEmpty || pid.isEmpty) {
      throw Exception('Institution or post id is missing.');
    }
    final res = await _dio.post('/institutions/$id/posts/$pid/submit');
    return _readPost(res.data);
  }

  Future<InstitutionPost> publishInstitutionPost(
    String institutionId,
    String postId,
  ) async {
    final id = institutionId.trim();
    final pid = postId.trim();
    if (id.isEmpty || pid.isEmpty) {
      throw Exception('Institution or post id is missing.');
    }
    final res = await _dio.post('/institutions/$id/posts/$pid/publish');
    return _readPost(res.data);
  }

  Future<InstitutionPost> archiveInstitutionPost(
    String institutionId,
    String postId,
  ) async {
    final id = institutionId.trim();
    final pid = postId.trim();
    if (id.isEmpty || pid.isEmpty) {
      throw Exception('Institution or post id is missing.');
    }
    final res = await _dio.post('/institutions/$id/posts/$pid/archive');
    return _readPost(res.data);
  }

  Future<void> deleteInstitutionPost(
    String institutionId,
    String postId,
  ) async {
    final id = institutionId.trim();
    final pid = postId.trim();
    if (id.isEmpty || pid.isEmpty) {
      throw Exception('Institution or post id is missing.');
    }
    await _dio.delete('/institutions/$id/posts/$pid');
  }

  InstitutionPost _readPost(dynamic body) {
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      final post = root['post'] ?? root['item'] ?? root['data'] ?? root;
      if (post is Map) {
        return InstitutionPost.fromJson(Map<String, dynamic>.from(post));
      }
    }
    throw Exception('Unexpected post response.');
  }

  // ── Global public feed (people + institutions, merged) ────────────────────

  /// Calls `/posts/public` (a.k.a. `/posts/feed`) and parses the merged feed
  /// of user posts and globally-distributable institution posts. Used by the
  /// institution Explore "Public" tab so the institution is showing the same
  /// global interaction feed that public/member home shows.
  Future<ExploreFeedPage> listGlobalPublicFeed({
    String? cursor,
    int? limit,
  }) async {
    final query = <String, dynamic>{
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      if (limit != null) 'limit': limit,
    };
    final res = await _dio.get(
      '/posts/public',
      queryParameters: query.isEmpty ? null : query,
    );
    final body = res.data;
    final items = <ExploreFeedItem>[];
    String? nextCursor;
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      final raw = root['items'];
      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          final parsed =
              ExploreFeedItem.fromJson(Map<String, dynamic>.from(entry));
          if (parsed != null) items.add(parsed);
        }
      }
      final cur = root['nextCursor'];
      if (cur != null) {
        final s = cur.toString().trim();
        if (s.isNotEmpty) nextCursor = s;
      }
    }
    return ExploreFeedPage(items: items, nextCursor: nextCursor);
  }

  // ── Institution Activity ──────────────────────────────────────────────────

  Future<InstitutionActivityPage> listInstitutionActivity({
    required String institutionId,
    String? kind,
    String? cursor,
    int? limit,
  }) async {
    final id = institutionId.trim();
    if (id.isEmpty) throw Exception('Institution id is missing.');
    final query = <String, dynamic>{
      if (kind != null && kind.trim().isNotEmpty) 'kind': kind.trim(),
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      if (limit != null) 'limit': limit,
    };
    final res = await _dio.get(
      '/institutions/$id/activity',
      queryParameters: query.isEmpty ? null : query,
    );
    final body = res.data;
    final items = <InstitutionActivityEvent>[];
    String? nextCursor;
    if (body is Map) {
      final root = Map<String, dynamic>.from(body);
      final raw = root['items'];
      if (raw is List) {
        for (final entry in raw.whereType<Map>()) {
          items.add(
            InstitutionActivityEvent.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          );
        }
      }
      final cur = root['nextCursor'];
      if (cur != null) {
        final s = cur.toString().trim();
        if (s.isNotEmpty) nextCursor = s;
      }
    }
    return InstitutionActivityPage(items: items, nextCursor: nextCursor);
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

/// Paginated result wrapper for [InstitutionPost] listings.
class InstitutionPostPage {
  const InstitutionPostPage({required this.items, this.nextCursor});

  final List<InstitutionPost> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

/// Paginated result wrapper for [InstitutionActivityEvent] listings.
class InstitutionActivityPage {
  const InstitutionActivityPage({required this.items, this.nextCursor});

  final List<InstitutionActivityEvent> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

/// Family arg for the institution post list provider.
class InstitutionPostListArgs {
  const InstitutionPostListArgs({
    required this.institutionId,
    required this.scope,
  });

  final String institutionId;
  final String scope; // 'public' | 'member' | 'internal'

  @override
  bool operator ==(Object other) =>
      other is InstitutionPostListArgs &&
      other.institutionId == institutionId &&
      other.scope == scope;

  @override
  int get hashCode => Object.hash(institutionId, scope);
}

/// First-page provider for institution posts. Pagination beyond the first
/// page is handled imperatively by callers using the repository directly.
final institutionPostsFirstPageProvider = FutureProvider.family<
    InstitutionPostPage, InstitutionPostListArgs>((ref, args) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listInstitutionPosts(
    institutionId: args.institutionId,
    scope: args.scope,
    limit: 20,
  );
});

/// First-page provider for the merged global public feed used by the
/// institution Explore "Public" tab. Keyed by institution id only because the
/// underlying endpoint is global, but using a family lets each Explore screen
/// invalidate its own cache without nuking unrelated state.
final institutionExplorePublicFeedProvider =
    FutureProvider.family<ExploreFeedPage, String>((ref, institutionId) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listGlobalPublicFeed(limit: 20);
});

/// Identifies a single InstitutionPost by feed institution + post id.
class InstitutionPostKey {
  const InstitutionPostKey({
    required this.institutionId,
    required this.postId,
  });

  final String institutionId;
  final String postId;

  @override
  bool operator ==(Object other) =>
      other is InstitutionPostKey &&
      other.institutionId == institutionId &&
      other.postId == postId;

  @override
  int get hashCode => Object.hash(institutionId, postId);
}

final institutionPostDetailProvider = FutureProvider.autoDispose
    .family<InstitutionPost, InstitutionPostKey>((ref, key) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.getInstitutionPost(
    institutionId: key.institutionId,
    postId: key.postId,
  );
});

final institutionPostRepliesProvider = FutureProvider.autoDispose
    .family<InstitutionPostPage, InstitutionPostKey>((ref, key) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listInstitutionPostReplies(
    institutionId: key.institutionId,
    postId: key.postId,
    limit: 50,
  );
});

/// Family arg for the activity feed provider.
class InstitutionActivityArgs {
  const InstitutionActivityArgs({
    required this.institutionId,
    this.kind,
  });

  final String institutionId;
  final String? kind;

  @override
  bool operator ==(Object other) =>
      other is InstitutionActivityArgs &&
      other.institutionId == institutionId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(institutionId, kind);
}

final institutionActivityFirstPageProvider = FutureProvider.family<
    InstitutionActivityPage, InstitutionActivityArgs>((ref, args) async {
  final repo = ref.watch(institutionsRepositoryProvider);
  return repo.listInstitutionActivity(
    institutionId: args.institutionId,
    kind: args.kind,
    limit: 30,
  );
});