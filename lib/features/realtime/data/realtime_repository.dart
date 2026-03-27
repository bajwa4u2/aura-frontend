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

  Future<RealtimeSessionSnapshot> createSession({
    required String surfaceType,
    required String surfaceId,
    required String kind,
    Map<String, dynamic>? metadata,
  }) async {
    final res = await _dio.post(
      '/realtime/sessions',
      data: <String, dynamic>{
        'surfaceType': surfaceType,
        'surfaceId': surfaceId,
        'kind': kind,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      },
    );
    final sessionMap = _unwrapMap(res.data);
    return await loadSessionBundle(sessionMap['id']?.toString() ?? '');
  }

  Future<RealtimeSessionSnapshot> loadSessionBundle(String sessionId) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _dio.get('/realtime/sessions/$sessionId'),
      _dio.get('/realtime/sessions/$sessionId/policy'),
      _dio.get('/realtime/sessions/$sessionId/consents'),
      _dio.get('/realtime/sessions/$sessionId/recordings'),
      _dio.get('/realtime/sessions/$sessionId/transcripts'),
      _dio.get('/realtime/sessions/$sessionId/artifacts'),
    ]);

    final sessionMap = _unwrapMap((results[0] as Response).data);
    final policyMap = _unwrapMap((results[1] as Response).data);
    final consents = _unwrapList((results[2] as Response).data);
    final recordings = _unwrapList((results[3] as Response).data);
    final transcripts = _unwrapList((results[4] as Response).data);
    final artifacts = _unwrapList((results[5] as Response).data);

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
    bool? isLocked,
  }) async {
    final payload = <String, dynamic>{};
    if (waitingRoomEnabled != null) {
      payload['waitingRoomEnabled'] = waitingRoomEnabled;
    }
    if (audioAllowed != null) {
      payload['audioAllowed'] = audioAllowed;
    }
    if (videoAllowed != null) {
      payload['videoAllowed'] = videoAllowed;
    }
    if (screenAllowed != null) {
      payload['screenAllowed'] = screenAllowed;
    }
    if (isLocked != null) {
      payload['isLocked'] = isLocked;
    }

    final res = await _dio.patch('/realtime/sessions/$sessionId/policy', data: payload);
    return RealtimePolicy.fromJson(_unwrapMap(res.data));
  }

  Future<void> createJoinRequest(String sessionId) async {
    await _dio.post('/realtime/sessions/$sessionId/join-request');
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
}
