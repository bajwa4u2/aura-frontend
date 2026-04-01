import 'package:dio/dio.dart';

import '../domain/realtime_models.dart';

class RealtimeRepository {
  RealtimeRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  dynamic _unwrapData(dynamic raw) {
    final root = _asMap(raw);
    if (root.containsKey('data')) return root['data'];
    return raw;
  }

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    final value = _unwrapData(raw);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic raw) {
    final value = _unwrapData(raw);
    return _asList(value);
  }

  Future<Response<dynamic>?> _safeGet(
    String path, {
    List<int> toleratedStatusCodes = const <int>[403, 404],
  }) async {
    try {
      return await _dio.get(path);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null && toleratedStatusCodes.contains(statusCode)) {
        return error.response;
      }
      rethrow;
    }
  }

  Future<void> _safePost(String path, {Map<String, dynamic>? data}) async {
    try {
      await _dio.post(path, data: data);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null && (statusCode == 403 || statusCode == 404 || statusCode == 405)) {
        return;
      }
      rethrow;
    }
  }

  Future<RealtimeSessionSnapshot> createSession({
    required String surfaceType,
    required String surfaceId,
    required String kind,
    Map<String, dynamic>? metadata,
  }) async {
    final normalizedType = surfaceType.trim().toUpperCase();
    final normalizedKind = kind.trim().toUpperCase();
    final threadId = (metadata?['threadId'] ?? '').toString().trim();
    final spaceId = (metadata?['spaceId'] ?? '').toString().trim();

    String path;
    Map<String, dynamic>? body;

    if ((normalizedType == 'THREAD' || normalizedType == 'DM') && threadId.isNotEmpty) {
      path = '/threads/$threadId/live/${normalizedKind == 'VIDEO' ? 'video' : 'audio'}/start';
      body = null;
    } else if (normalizedType == 'SPACE' && surfaceId.trim().isNotEmpty) {
      path = '/spaces/$surfaceId/live/${normalizedKind == 'VIDEO' ? 'video' : 'audio'}/start';
      body = null;
    } else if ((normalizedType == 'EVENT_ROOM' || normalizedType == 'INSTITUTION_ROOM' || normalizedType == 'ROOM') && surfaceId.trim().isNotEmpty) {
      path = '/rooms/$surfaceId/${normalizedKind == 'VIDEO' ? 'video' : 'audio'}/start';
      body = null;
    } else {
      path = '/realtime/sessions';
      body = <String, dynamic>{
        'surfaceType': surfaceType,
        'surfaceId': surfaceId,
        'kind': kind,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      };
    }

    final res = body == null ? await _dio.post(path) : await _dio.post(path, data: body);
    final sessionMap = _unwrapMap(res.data);
    return await loadSessionBundle(sessionMap['id']?.toString() ?? '');
  }

  Future<RealtimeSessionSnapshot> loadSessionBundle(String sessionId) async {
    final sessionRes = await _dio.get('/realtime/sessions/$sessionId');

    final policyRes = await _safeGet('/realtime/sessions/$sessionId/policy');
    final consentsRes = await _safeGet('/realtime/sessions/$sessionId/consents');
    final recordingsRes = await _safeGet('/realtime/sessions/$sessionId/recordings');
    final transcriptsRes = await _safeGet('/realtime/sessions/$sessionId/transcripts');
    final artifactsRes = await _safeGet('/realtime/sessions/$sessionId/artifacts');

    final sessionMap = _unwrapMap(sessionRes.data);
    final policyMap = policyRes == null ? <String, dynamic>{} : _unwrapMap(policyRes.data);
    final consents = consentsRes == null ? const <Map<String, dynamic>>[] : _unwrapList(consentsRes.data);
    final recordings = recordingsRes == null ? const <Map<String, dynamic>>[] : _unwrapList(recordingsRes.data);
    final transcripts = transcriptsRes == null ? const <Map<String, dynamic>>[] : _unwrapList(transcriptsRes.data);
    final artifacts = artifactsRes == null ? const <Map<String, dynamic>>[] : _unwrapList(artifactsRes.data);

    return RealtimeSessionSnapshot.fromJson(
      <String, dynamic>{
        'session': sessionMap,
        'participants': sessionMap['participants'] ?? sessionMap['sessionParticipants'] ?? const [],
        'policy': policyMap,
        'consents': consents,
        'recordings': recordings,
        'transcripts': transcripts,
        'artifacts': artifacts,
      },
    );
  }

  Future<Map<String, dynamic>> issueTurnCredentials(String sessionId) async {
    final res = await _dio.post(
      '/realtime/turn-credentials',
      data: <String, dynamic>{'sessionId': sessionId},
    );
    return _unwrapMap(res.data);
  }

  Future<RealtimePolicy> getPolicy(String sessionId) async {
    final res = await _dio.get('/realtime/sessions/$sessionId/policy');
    return RealtimePolicy.fromJson(_unwrapMap(res.data));
  }

  Future<RealtimePolicy> updatePolicy(
    String sessionId, {
    bool? waitingRoomEnabled,
    bool? audioAllowed,
    bool? videoAllowed,
    bool? screenAllowed,
  }) async {
    final payload = <String, dynamic>{};
    if (waitingRoomEnabled != null) payload['waitingRoomEnabled'] = waitingRoomEnabled;
    if (audioAllowed != null) payload['audioAllowed'] = audioAllowed;
    if (videoAllowed != null) payload['videoAllowed'] = videoAllowed;
    if (screenAllowed != null) payload['screenAllowed'] = screenAllowed;

    final res = await _dio.patch('/realtime/sessions/$sessionId/policy', data: payload);
    return RealtimePolicy.fromJson(_unwrapMap(res.data));
  }

  Future<RealtimePolicy> setLocked(String sessionId, {required bool locked}) async {
    final res = await _dio.post(
      '/realtime/sessions/$sessionId/${locked ? 'lock' : 'unlock'}',
    );
    return RealtimePolicy.fromJson(_unwrapMap(res.data));
  }

  Future<void> createJoinRequest(String sessionId) async {
    await _dio.post('/realtime/sessions/$sessionId/join-request');
  }


  Future<RealtimeSessionSnapshot> joinSession(RealtimeSession session) async {
    final id = session.id.trim();
    if (id.isEmpty) {
      throw StateError('Live session id is missing.');
    }

    final surfaceId = (session.surfaceId ?? '').trim();
    final surfaceType = session.surfaceType.name.trim().toLowerCase();

    if ((surfaceType == 'thread' || surfaceType == 'dm') && surfaceId.isNotEmpty) {
      await _dio.post('/threads/$surfaceId/live/$id/join');
      return loadSessionBundle(id);
    }

    if (surfaceType == 'space' && surfaceId.isNotEmpty) {
      await _dio.post('/spaces/$surfaceId/live/$id/join');
      return loadSessionBundle(id);
    }

    if ((surfaceType == 'room' ||
            surfaceType == 'eventroom' ||
            surfaceType == 'institutionroom') &&
        surfaceId.isNotEmpty) {
      await _dio.post('/rooms/$surfaceId/live/$id/join');
      return loadSessionBundle(id);
    }

    throw StateError('Unable to determine join route for this live session.');
  }

  Future<void> respondToJoinRequest(
    String sessionId, {
    required String requestUserId,
    required String decision,
  }) async {
    await _dio.post(
      '/realtime/sessions/$sessionId/join-requests/$requestUserId/respond',
      data: <String, dynamic>{'decision': decision},
    );
  }

  Future<void> createInvite(
    String sessionId, {
    required String invitedUserId,
    String? note,
  }) async {
    await _dio.post(
      '/realtime/sessions/$sessionId/invites',
      data: <String, dynamic>{
        'invitedUserId': invitedUserId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<void> removeParticipant(String sessionId, String targetUserId) async {
    await _dio.post('/realtime/sessions/$sessionId/remove/$targetUserId');
  }

  Future<void> requestConsent(String sessionId) async {
    await _dio.post('/realtime/sessions/$sessionId/consents/request');
  }

  Future<void> respondToOwnConsent(
    String sessionId, {
    required String decision,
  }) async {
    await _dio.post(
      '/realtime/sessions/$sessionId/consents/respond',
      data: <String, dynamic>{'decision': decision},
    );
  }

  Future<List<RealtimeConsent>> listConsents(String sessionId) async {
    final res = await _dio.get('/realtime/sessions/$sessionId/consents');
    return _unwrapList(res.data).map(RealtimeConsent.fromJson).toList();
  }

  Future<List<RealtimeRecording>> listRecordings(String sessionId) async {
    final res = await _dio.get('/realtime/sessions/$sessionId/recordings');
    return _unwrapList(res.data).map(RealtimeRecording.fromJson).toList();
  }

  Future<void> requestRecording(
    String sessionId, {
    String? title,
  }) async {
    await _dio.post(
      '/realtime/sessions/$sessionId/recordings/request',
      data: <String, dynamic>{
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      },
    );
  }

  Future<List<RealtimeTranscriptJob>> listTranscripts(String sessionId) async {
    final res = await _dio.get('/realtime/sessions/$sessionId/transcripts');
    return _unwrapList(res.data).map(RealtimeTranscriptJob.fromJson).toList();
  }

  Future<void> requestTranscript(
    String sessionId, {
    String? title,
  }) async {
    await _dio.post(
      '/realtime/sessions/$sessionId/transcripts/request',
      data: <String, dynamic>{
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      },
    );
  }

  Future<List<RealtimeArtifact>> listArtifacts(String sessionId) async {
    final res = await _dio.get('/realtime/sessions/$sessionId/artifacts');
    return _unwrapList(res.data).map(RealtimeArtifact.fromJson).toList();
  }

  Future<void> leaveSession(RealtimeSession? session) async {
    if (session == null) return;
    final id = session.id.trim();
    if (id.isEmpty) return;

    final surfaceId = (session.surfaceId ?? '').trim();
    final surfaceType = session.surfaceType.name.trim().toLowerCase();

    if (surfaceType == 'thread' || surfaceType == 'dm') {
      if (surfaceId.isNotEmpty) {
        await _safePost('/threads/$surfaceId/live/$id/leave');
        return;
      }
    }
    if (surfaceType == 'space') {
      if (surfaceId.isNotEmpty) {
        await _safePost('/spaces/$surfaceId/live/$id/leave');
        return;
      }
    }
    if (surfaceType == 'room' || surfaceType == 'eventroom' || surfaceType == 'institutionroom') {
      if (surfaceId.isNotEmpty) {
        await _safePost('/rooms/$surfaceId/live/$id/leave');
        return;
      }
    }
    await _safePost('/realtime/sessions/$id/leave');
  }

  Future<void> endSession(RealtimeSession? session) async {
    if (session == null) return;
    final id = session.id.trim();
    if (id.isEmpty) return;

    final surfaceId = (session.surfaceId ?? '').trim();
    final surfaceType = session.surfaceType.name.trim().toLowerCase();

    if (surfaceType == 'thread' || surfaceType == 'dm') {
      if (surfaceId.isNotEmpty) {
        await _safePost('/threads/$surfaceId/live/$id/end');
        return;
      }
    }
    if (surfaceType == 'space') {
      if (surfaceId.isNotEmpty) {
        await _safePost('/spaces/$surfaceId/live/$id/end');
        return;
      }
    }
    if (surfaceType == 'room' || surfaceType == 'eventroom' || surfaceType == 'institutionroom') {
      if (surfaceId.isNotEmpty) {
        await _safePost('/rooms/$surfaceId/live/$id/end');
        return;
      }
    }
    await _safePost('/realtime/sessions/$id/end');
  }
}
