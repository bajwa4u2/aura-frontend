import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
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

  static const Duration _bundleTtl = Duration(seconds: 30);

  final _bundleCache = <String, RealtimeSessionSnapshot>{};
  final _bundleCacheAt = <String, DateTime>{};
  final _bundleInFlight = <String, Future<RealtimeSessionSnapshot>>{};

  void clearBundleCache([String? sessionId]) {
    if (sessionId != null) {
      _bundleCache.remove(sessionId);
      _bundleCacheAt.remove(sessionId);
      _bundleInFlight.remove(sessionId);
    } else {
      _bundleCache.clear();
      _bundleCacheAt.clear();
      _bundleInFlight.clear();
    }
  }

  Future<void> _safePost(String path, {Map<String, dynamic>? data}) async {
    try {
      await _dio.post(path, data: data);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null &&
          (statusCode == 403 || statusCode == 404 || statusCode == 405)) {
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

    String path;
    Map<String, dynamic>? body;

    if ((normalizedType == 'THREAD' || normalizedType == 'DM') &&
        threadId.isNotEmpty) {
      path =
          '/threads/$threadId/live/${normalizedKind == 'VIDEO' ? 'video' : 'audio'}/start';
      body = null;
    } else if (normalizedType == 'SPACE' && surfaceId.trim().isNotEmpty) {
      path =
          '/spaces/$surfaceId/live/${normalizedKind == 'VIDEO' ? 'video' : 'audio'}/start';
      body = null;
    } else if ((normalizedType == 'EVENT_ROOM' ||
            normalizedType == 'INSTITUTION_ROOM' ||
            normalizedType == 'ROOM') &&
        surfaceId.trim().isNotEmpty) {
      path =
          '/rooms/$surfaceId/${normalizedKind == 'VIDEO' ? 'video' : 'audio'}/start';
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

    final res = body == null
        ? await _dio.post(path)
        : await _dio.post(path, data: body);
    final sessionMap = _unwrapMap(res.data);
    final sessionId = sessionMap['id']?.toString() ?? '';
    return await loadSessionBundle(sessionId);
  }

  Future<RealtimeSessionSnapshot> loadSessionBundle(
    String sessionId, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cached = _bundleCache[sessionId];
    final cachedAt = _bundleCacheAt[sessionId];

    if (!forceRefresh &&
        cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _bundleTtl) {
      return cached;
    }

    final existing = _bundleInFlight[sessionId];
    if (!forceRefresh && existing != null) return existing;

    final future = _fetchSessionBundle(sessionId);
    _bundleInFlight[sessionId] = future;
    try {
      final result = await future;
      _bundleCache[sessionId] = result;
      _bundleCacheAt[sessionId] = DateTime.now();
      return result;
    } finally {
      if (identical(_bundleInFlight[sessionId], future)) {
        _bundleInFlight.remove(sessionId);
      }
    }
  }

  Future<RealtimeSessionSnapshot> _fetchSessionBundle(String sessionId) async {
    final sessionRes = await _dio.get('/realtime/sessions/$sessionId');

    final policyRes = await _safeGet('/realtime/sessions/$sessionId/policy');
    final consentRes = await _safeGet(
      '/realtime/sessions/$sessionId/consent',
      toleratedStatusCodes: const <int>[404],
    );
    final recordingsRes = await _safeGet(
      '/realtime/sessions/$sessionId/recordings',
    );
    final transcriptsRes = await _safeGet(
      '/realtime/sessions/$sessionId/transcripts',
    );
    final artifactsRes = await _safeGet(
      '/realtime/sessions/$sessionId/artifacts',
    );

    final sessionMap = _unwrapMap(sessionRes.data);
    final policyMap = policyRes == null
        ? <String, dynamic>{}
        : _unwrapMap(policyRes.data);
    final ownConsentMap = consentRes == null ? null : _unwrapMap(consentRes.data);
    final consents = ownConsentMap == null || ownConsentMap.isEmpty
        ? const <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[ownConsentMap];
    final recordings = recordingsRes == null
        ? const <Map<String, dynamic>>[]
        : _unwrapList(recordingsRes.data);
    final transcripts = transcriptsRes == null
        ? const <Map<String, dynamic>>[]
        : _unwrapList(transcriptsRes.data);
    final artifacts = artifactsRes == null
        ? const <Map<String, dynamic>>[]
        : _unwrapList(artifactsRes.data);

    return RealtimeSessionSnapshot.fromJson(<String, dynamic>{
      'session': sessionMap,
      'participants':
          sessionMap['participants'] ??
          sessionMap['sessionParticipants'] ??
          const [],
      'policy': policyMap,
      'consents': consents,
      'recordings': recordings,
      'transcripts': transcripts,
      'artifacts': artifacts,
    });
  }

  Future<List<RealtimeSession>> listMySessions() async {
    final res = await _dio.get('/realtime/sessions', queryParameters: {'scope': 'me'});
    final raw = _unwrapData(res.data);
    final list = raw is List ? raw : (raw is Map && raw.containsKey('items') ? raw['items'] : []);
    return _asList(list).map((m) => RealtimeSession.fromJson(m)).toList();
  }

  /// Lightweight resolution check for app-resume reconciliation. Returns
  /// whether the bridge should drop the ringing card for [sessionId]:
  ///   - session 404 / ENDED / CANCELLED → drop
  ///   - my participant invite is no longer PENDING (accepted on another
  ///     device, declined, expired) → drop
  ///
  /// On any transport error returns false so the existing TTL still wins —
  /// we never want a network blip to silently dismiss a legitimately
  /// ringing call.
  Future<bool> isCallResolvedForUser(String sessionId, String myUserId) async {
    final trimmedSession = sessionId.trim();
    final trimmedUser = myUserId.trim();
    if (trimmedSession.isEmpty || trimmedUser.isEmpty) return false;

    Response<dynamic> res;
    try {
      res = await _dio.get('/realtime/sessions/$trimmedSession');
    } on DioException catch (error) {
      // Treat 404/410 as authoritative "session gone — clear the card".
      // Anything else (timeout, 5xx) leaves the decision to the TTL.
      final status = error.response?.statusCode ?? 0;
      if (status == 404 || status == 410) return true;
      return false;
    } catch (_) {
      return false;
    }

    final sessionMap = _unwrapMap(res.data);
    final status = (sessionMap['status'] ?? '').toString().toUpperCase();
    if (status == 'ENDED' || status == 'CANCELLED') return true;

    final participantsRaw =
        sessionMap['participants'] ?? sessionMap['sessionParticipants'];
    if (participantsRaw is List) {
      for (final p in participantsRaw) {
        if (p is! Map) continue;
        final pUserId = (p['userId'] ?? p['user']?['id'] ?? '').toString().trim();
        if (pUserId != trimmedUser) continue;
        final inviteStatus = (p['inviteStatus'] ?? '').toString().toUpperCase();
        final joinState = (p['joinState'] ?? '').toString().toUpperCase();
        // PENDING + INVITED = still ringing for me; anything else (ACCEPTED,
        // DECLINED, EXPIRED, REVOKED, or any non-INVITED joinState) means
        // the invite has resolved on this user, even if the session is
        // still ACTIVE (the user accepted on another device).
        if (inviteStatus != 'PENDING' || joinState != 'INVITED') return true;
        return false;
      }
    }
    return false;
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
    if (waitingRoomEnabled != null) {
      payload['waitingRoomEnabled'] = waitingRoomEnabled;
    }
    if (audioAllowed != null) payload['audioAllowed'] = audioAllowed;
    if (videoAllowed != null) payload['videoAllowed'] = videoAllowed;
    if (screenAllowed != null) payload['screenAllowed'] = screenAllowed;

    final res = await _dio.patch(
      '/realtime/sessions/$sessionId/policy',
      data: payload,
    );
    return RealtimePolicy.fromJson(_unwrapMap(res.data));
  }

  Future<RealtimePolicy> setLocked(
    String sessionId, {
    required bool locked,
  }) async {
    final res = await _dio.post(
      '/realtime/sessions/$sessionId/${locked ? 'lock' : 'unlock'}',
    );
    return RealtimePolicy.fromJson(_unwrapMap(res.data));
  }

  Future<void> createJoinRequest(String sessionId) async {
    await _dio.post('/realtime/sessions/$sessionId/join-request');
  }

  Future<void> declineInvite(String sessionId) async {
    await _safePost('/realtime/sessions/$sessionId/decline');
  }

  Future<RealtimeSessionSnapshot> joinSession(RealtimeSession session) async {
    final id = session.id.trim();
    if (id.isEmpty) {
      throw StateError('Live session id is missing.');
    }

    final surfaceId = (session.surfaceId ?? '').trim();
    final surfaceType = session.surfaceType.name.trim().toLowerCase();

    if ((surfaceType == 'thread' || surfaceType == 'dm') &&
        surfaceId.isNotEmpty) {
      final joinPath = '/threads/$surfaceId/live/$id/join';
      await _dio.post(joinPath);
      return loadSessionBundle(id, forceRefresh: true);
    }

    if (surfaceType == 'space' && surfaceId.isNotEmpty) {
      final joinPath = '/spaces/$surfaceId/live/$id/join';
      await _dio.post(joinPath);
      return loadSessionBundle(id, forceRefresh: true);
    }

    if ((surfaceType == 'room' ||
            surfaceType == 'eventroom' ||
            surfaceType == 'institutionroom') &&
        surfaceId.isNotEmpty) {
      final joinPath = '/rooms/$surfaceId/live/$id/join';
      await _dio.post(joinPath);
      return loadSessionBundle(id, forceRefresh: true);
    }

    await _dio.post('/realtime/sessions/$id/join');
    return loadSessionBundle(id, forceRefresh: true);
  }

  Future<void> respondToJoinRequest(
    String sessionId, {
    required String requestUserId,
    required String decision,
  }) async {
    final normalizedDecision = _joinDecisionValue(decision);
    await _dio.post(
      '/realtime/sessions/$sessionId/join-requests/$requestUserId/respond',
      data: <String, dynamic>{'decision': normalizedDecision},
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
    final status = _consentStatusValue(decision);
    await _dio.post(
      '/realtime/sessions/$sessionId/consents/respond',
      data: <String, dynamic>{
        'recordingConsentStatus': status,
        'transcriptionConsentStatus': status,
      },
    );
  }

  Future<List<RealtimeConsent>> listConsents(String sessionId) async {
    final res = await _dio.get('/realtime/sessions/$sessionId/consents');
    return _unwrapList(res.data).map(RealtimeConsent.fromJson).toList();
  }

  Future<List<RealtimeConsent>> getOwnConsent(String sessionId) async {
    final res = await _safeGet(
      '/realtime/sessions/$sessionId/consent',
      toleratedStatusCodes: const <int>[404],
    );
    if (res == null) return const <RealtimeConsent>[];

    final consentMap = _unwrapMap(res.data);
    if (consentMap.isEmpty) return const <RealtimeConsent>[];

    return <RealtimeConsent>[RealtimeConsent.fromJson(consentMap)];
  }

  Future<List<RealtimeRecording>> listRecordings(String sessionId) async {
    final res = await _dio.get('/realtime/sessions/$sessionId/recordings');
    return _unwrapList(res.data).map(RealtimeRecording.fromJson).toList();
  }

  Future<void> requestRecording(String sessionId, {String? title}) async {
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

  Future<void> requestTranscript(String sessionId, {String? title}) async {
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
    if (surfaceType == 'room' ||
        surfaceType == 'eventroom' ||
        surfaceType == 'institutionroom') {
      if (surfaceId.isNotEmpty) {
        await _safePost('/rooms/$surfaceId/live/$id/leave');
        return;
      }
    }
    await _safePost('/realtime/sessions/$id/leave');
    clearBundleCache(id);
  }

  Future<void> endSession(RealtimeSession? session) async {
    if (session == null) {
      debugPrint('[END] endSession: session is null — no-op');
      return;
    }
    final id = session.id.trim();
    if (id.isEmpty) {
      debugPrint('[END] endSession: session.id is empty — no-op');
      return;
    }

    final surfaceId = (session.surfaceId ?? '').trim();
    final surfaceType = session.surfaceType.name.trim().toLowerCase();

    String path;
    if ((surfaceType == 'thread' || surfaceType == 'dm') && surfaceId.isNotEmpty) {
      path = '/threads/$surfaceId/live/$id/end';
    } else if (surfaceType == 'space' && surfaceId.isNotEmpty) {
      path = '/spaces/$surfaceId/live/$id/end';
    } else if ((surfaceType == 'room' ||
            surfaceType == 'eventroom' ||
            surfaceType == 'institutionroom') &&
        surfaceId.isNotEmpty) {
      path = '/rooms/$surfaceId/live/$id/end';
    } else {
      path = '/realtime/sessions/$id/end';
    }

    debugPrint('[END] endSession: surfaceType=$surfaceType surfaceId=$surfaceId id=$id → POST $path');
    try {
      await _dio.post(path);
      debugPrint('[END] endSession: POST $path succeeded');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      debugPrint('[END] endSession: POST $path FAILED status=$status body=${e.response?.data}');
      // 404 = session already gone; treat as success so local state still clears.
      if (status == 404) {
        clearBundleCache(id);
        return;
      }
      rethrow;
    }
    clearBundleCache(id);
  }

  String _joinDecisionValue(String decision) {
    final normalized = decision.trim().toLowerCase();
    if (normalized == 'approved' || normalized == 'approve') {
      return 'APPROVED';
    }
    if (normalized == 'rejected' || normalized == 'reject') {
      return 'REJECTED';
    }
    return decision.trim().toUpperCase();
  }

  String _consentStatusValue(String decision) {
    final normalized = decision.trim().toLowerCase();
    if (normalized == 'grant' ||
        normalized == 'granted' ||
        normalized == 'approve' ||
        normalized == 'approved') {
      return 'GRANTED';
    }
    if (normalized == 'decline' ||
        normalized == 'declined' ||
        normalized == 'reject' ||
        normalized == 'rejected') {
      return 'DECLINED';
    }
    return decision.trim().toUpperCase();
  }
}
