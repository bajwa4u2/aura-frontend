import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/realtime_models.dart';
import '../../../core/identity/person_identity_model.dart';

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
    // 401 is tolerated so a meeting GUEST (whose token resolves no member
    // userId, making strict @CurrentUserId member endpoints like
    // /realtime/sessions/:id/policy return 401) still gets a session bundle:
    // the supplementary policy/consent/recordings fetches degrade to empty
    // instead of throwing and failing the whole join. Members are authed and
    // won't 401 on these, so this never masks a real member auth failure here.
    List<int> toleratedStatusCodes = const <int>[401, 403, 404],
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

  /// THE SIX REQUESTS RUN CONCURRENTLY, NOT ONE AFTER ANOTHER.
  ///
  /// Founder-observed 2026-08-25: *"there is bit delay too before connecting"*.
  /// Measured on a Pixel 9a over one real answered call, this bundle took
  /// **2.62 s** of a 6.51 s accept-to-connected — the single largest phase, and
  /// larger than the socket connect, the join ack, `getUserMedia`, and the
  /// remote track attach put together.
  ///
  /// No individual request was slow: the same six measured 106/85/159/132/84/81
  /// ms. They were simply awaited in sequence, so the person answering a call
  /// paid the SUM of six round trips. Three of them — recordings, transcripts,
  /// artifacts — are the call's RECORD, which nobody needs in order to answer.
  ///
  /// Concurrency is the whole fix, and is preferred here over splitting the
  /// bundle into join-critical and record halves: run together, the cost falls
  /// to roughly the slowest single request, so dropping three of six from the
  /// join path would buy almost nothing further while risking a cached snapshot
  /// that silently lacks the record other surfaces read from it.
  ///
  /// Failure semantics are unchanged. The session GET still throws (there is no
  /// call without it); the other five still go through [_safeGet], which
  /// tolerates 401/403/404 — the tolerance a meeting GUEST depends on, whose
  /// token resolves no member userId and therefore 401s on `/policy` and
  /// `/consent`. Narrowing that to 404 once made guests unable to join at all.
  Future<RealtimeSessionSnapshot> _fetchSessionBundle(String sessionId) async {
    final results = await Future.wait(<Future<Response<dynamic>?>>[
      _dio.get('/realtime/sessions/$sessionId'),
      _safeGet('/realtime/sessions/$sessionId/policy'),
      _safeGet('/realtime/sessions/$sessionId/consent'),
      _safeGet('/realtime/sessions/$sessionId/recordings'),
      _safeGet('/realtime/sessions/$sessionId/transcripts'),
      _safeGet('/realtime/sessions/$sessionId/artifacts'),
    ]);

    final sessionRes = results[0]!;
    final policyRes = results[1];
    final consentRes = results[2];
    final recordingsRes = results[3];
    final transcriptsRes = results[4];
    final artifactsRes = results[5];

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

  /// Router kill-switch support — resolve just enough of a session to decide
  /// whether a `/realtime/:sessionId` deep link actually points at a MEETING
  /// surface (which must be diverted to the meeting live room rather than the
  /// generic realtime call screen). Best-effort: a single GET, and any failure
  /// returns null so legitimate direct-call navigation is never blocked.
  Future<RealtimeSession?> fetchSessionCore(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return null;
    try {
      final res = await _dio.get('/realtime/sessions/$id');
      return RealtimeSession.fromJson(_unwrapMap(res.data));
    } catch (_) {
      return null;
    }
  }

  Future<List<RealtimeSession>> listMySessions() async {
    final res = await _dio.get('/realtime/sessions', queryParameters: {'scope': 'me'});
    final raw = _unwrapData(res.data);
    final list = raw is List ? raw : (raw is Map && raw.containsKey('items') ? raw['items'] : []);
    return _asList(list).map((m) => RealtimeSession.fromJson(m)).toList();
  }

  /// GO LIVE (founder charter 2026-08-17): escalate the CURRENT active
  /// conversation call session into the LIVE lifecycle state. Same
  /// session id in, same session id out — never a second session.
  Future<RealtimeSession?> goLive({
    required String conversationId,
    required String sessionId,
  }) async {
    final res = await _dio.post(
      '/conversations/$conversationId/live/$sessionId/go-live',
    );
    final raw = _unwrapData(res.data);
    final session = raw is Map ? raw['session'] : null;
    return session is Map
        ? RealtimeSession.fromJson(Map<String, dynamic>.from(session))
        : null;
  }

  /// END LIVE ≠ END CALL: closes the public boundary; the same session
  /// stays active and the private call continues.
  Future<RealtimeSession?> endLive({
    required String conversationId,
    required String sessionId,
  }) async {
    final res = await _dio.post(
      '/conversations/$conversationId/live/$sessionId/end-live',
    );
    final raw = _unwrapData(res.data);
    final session = raw is Map ? raw['session'] : null;
    return session is Map
        ? RealtimeSession.fromJson(Map<String, dynamic>.from(session))
        : null;
  }

  /// Live discovery ("what is live on Aura right now"), listable by any
  /// authenticated user. The broadcaster's canonical display name is
  /// folded into the session title so every existing session-labeling
  /// surface renders it without a new code path.
  Future<List<RealtimeSession>> listPublicBroadcasts() async {
    final res = await _dio.get('/realtime/live/broadcasts');
    final raw = _unwrapData(res.data);
    final list = raw is List ? raw : (raw is Map && raw.containsKey('items') ? raw['items'] : []);
    return _asList(list).map((m) {
      final map = Map<String, dynamic>.from(m);
      final broadcaster = map['broadcaster'];
      final title = (map['title'] ?? '').toString().trim();
      if (title.isEmpty && broadcaster is Map) {
        // A broadcast with no title is named after the person broadcasting -
        // by the canonical reader, not by a second reading of the same field.
        final person = AuraPersonIdentity.fromJson(broadcaster);
        if (person.displayName.trim().isNotEmpty ||
            person.handle.trim().isNotEmpty) {
          map['title'] = '${person.proseName} — Live';
        }
      }
      return RealtimeSession.fromJson(map);
    }).toList();
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

  // ── STAGE MEDIA CONTROL PLANE ──────────────────────────────────────────
  //
  // Client -> Aura -> Cloudflare for control; client <-> Cloudflare for media.
  // Nothing here sends or receives a provider identifier: a subscribe names
  // AURA track ids, and the response says which m-line carries whose track.

  Future<Map<String, dynamic>> openStageTransport(
    String sessionId, {
    required String offerSdp,
  }) async {
    final res = await _dio.post(
      '/realtime/sessions/$sessionId/stage/transport',
      data: <String, dynamic>{'offerSdp': offerSdp},
    );
    return _unwrapMap(res.data);
  }

  Future<Map<String, dynamic>> publishStageTracks(
    String sessionId, {
    required String offerSdp,
    required List<Map<String, dynamic>> tracks,
  }) async {
    final res = await _dio.post(
      '/realtime/sessions/$sessionId/stage/publish',
      data: <String, dynamic>{'offerSdp': offerSdp, 'tracks': tracks},
    );
    return _unwrapMap(res.data);
  }

  Future<List<Map<String, dynamic>>> listStageTracks(String sessionId) async {
    final res = await _dio.get('/realtime/sessions/$sessionId/stage/tracks');
    final raw = res.data;
    final data = (raw is Map && raw['data'] is List) ? raw['data'] : raw;
    if (data is! List) return const <Map<String, dynamic>>[];
    return data
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> subscribeStageTracks(
    String sessionId, {
    required List<String> trackIds,
  }) async {
    final res = await _dio.post(
      '/realtime/sessions/$sessionId/stage/subscribe',
      data: <String, dynamic>{'trackIds': trackIds},
    );
    return _unwrapMap(res.data);
  }

  /// Retire the RECEIVE side of tracks this client no longer needs.
  ///
  /// Best-effort: failing to tidy a stale receiver leaves the client exactly
  /// where it already was, so it must never fail the reconciliation that
  /// noticed it.
  Future<int> unsubscribeStageTracks(
    String sessionId, {
    required List<String> trackIds,
  }) async {
    if (trackIds.isEmpty) return 0;
    try {
      final res = await _dio.post(
        '/realtime/sessions/$sessionId/stage/tracks/unsubscribe',
        data: <String, dynamic>{'trackIds': trackIds},
      );
      final body = _unwrapMap(res.data);
      return (body['retired'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> renegotiateStage(
    String sessionId, {
    required String answerSdp,
  }) async {
    await _dio.post(
      '/realtime/sessions/$sessionId/stage/renegotiate',
      data: <String, dynamic>{'answerSdp': answerSdp},
    );
  }

  /// Report why the stage failed for this client.
  ///
  /// Best-effort and never throws: diagnosis must not become a second way for
  /// a call to break.
  /// Diagnostics that could not be sent, held until the network returns.
  ///
  /// THE BLIND SPOT THIS CLOSES (2026-08-28). A diagnostic describing a
  /// network failure is emitted WHILE THE NETWORK IS DOWN, so the post fails
  /// and the record is discarded — and the events that matter most are
  /// precisely the ones that can never arrive. An induced wifi drop on a real
  /// call produced a completely empty trace: every ICE transition and every
  /// recovery attempt happened, and not one was recorded.
  ///
  /// Bounded to the last [_diagnosticQueueCap] entries. This is a debugging
  /// aid, not a delivery guarantee: dropping the OLDEST keeps the newest
  /// picture, and an unbounded queue on a long outage would be a leak.
  final List<Map<String, String>> _pendingDiagnostics = <Map<String, String>>[];
  static const int _diagnosticQueueCap = 40;
  bool _flushingDiagnostics = false;

  /// TELL THE SERVER WHETHER THIS PHONE ACTUALLY RANG.
  ///
  /// The one fact the backend cannot observe. A push provider accepting a VoIP
  /// push proves delivery was accepted, not that CallKit presented anything —
  /// it can refuse for Do Not Disturb, a blocked caller, or a call slot still
  /// occupied. Aura suppresses a phone's ordinary fallback banner on the
  /// expectation that CallKit will present; this is what makes that
  /// expectation checkable instead of assumed.
  ///
  /// Never blocking, but no longer single-shot.
  ///
  /// A failure here must still never delay or break a ringing call, so this
  /// stays unawaited by its callers. What changed is the assumption underneath
  /// it. The old comment said a lost report "degrades toward showing the
  /// fallback, which is the safe direction" — that is true only when the phone
  /// did not ring. Production on 2026-09-01 showed the other case: a locked
  /// iPhone woke, CallKit presented, and the server received nothing at all —
  /// no ack and no diagnostic — for the ~28 seconds the app was alive. The
  /// fallback then presented a second time on a phone that was already ringing.
  ///
  /// The cause is structural rather than incidental. A just-woken app can
  /// receive pushes long before its own outbound HTTPS is usable: Apple's
  /// connection delivers the push, but this request has to open its own. One
  /// attempt fired in that window is simply lost, and silence is then read by
  /// the server as proof the phone stayed quiet.
  ///
  /// So it retries, briefly and bounded. The delays are chosen against the
  /// server's own deadline — CallPresentationService.FALLBACK_GRACE_MS is 12s —
  /// so every attempt lands before the fallback can decide, and the last one
  /// still leaves margin. Retrying after that point would be pointless: the
  /// decision it exists to inform has already been taken.
  ///
  /// A 4xx is never retried. The server understood and refused, and repeating
  /// a refusal is noise.
  ///
  /// The installation is taken from the request's client identity headers, not
  /// sent in the body: a client does not get to claim which phone it is.
  static const List<Duration> _presentationRetryDelays = <Duration>[
    Duration(milliseconds: 800),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  Future<void> reportCallPresentation(
    String sessionId, {
    required String state,
    String? platform,
    String? detail,
  }) async {
    final id = sessionId.trim();
    if (id.isEmpty) return;

    final body = <String, dynamic>{
      'state': state,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
      if (detail != null && detail.isNotEmpty) 'detail': detail,
    };

    for (var attempt = 0; ; attempt++) {
      try {
        await _dio.post<dynamic>(
          '/realtime/sessions/$id/presentation',
          data: body,
        );
        return;
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code != null && code >= 400 && code < 500) return;
      } catch (_) {
        // Fall through to the retry decision below.
      }

      if (attempt >= _presentationRetryDelays.length) return;
      await Future<void>.delayed(_presentationRetryDelays[attempt]);
    }
  }

  Future<void> reportStageDiagnostic(
    String sessionId, {
    required String phase,
    required String code,
    required String message,
    required String platform,
  }) async {
    final entry = <String, String>{
      'sessionId': sessionId,
      'phase': phase,
      'code': code,
      'message': message,
      'platform': platform,
    };
    if (!await _postDiagnostic(entry)) {
      _pendingDiagnostics.add(entry);
      while (_pendingDiagnostics.length > _diagnosticQueueCap) {
        _pendingDiagnostics.removeAt(0);
      }
      _armDiagnosticRetry();
      return;
    }
    // That post succeeded, so connectivity is back — anything held during the
    // outage can go now, in the order it happened.
    unawaited(_flushPendingDiagnostics());
  }

  Future<bool> _postDiagnostic(Map<String, String> entry) async {
    try {
      await _dio.post(
        '/realtime/sessions/${entry['sessionId']}/stage/diagnostics',
        data: <String, dynamic>{
          'phase': entry['phase'],
          'code': entry['code'],
          // Mark what was replayed, so a held trace is never mistaken for a
          // live one when reading timings back. NOT `held=` -- the render
          // diagnostic already emits a `held=N` counter, and the collision
          // made the queue marker unsearchable the first time out.
          'message': entry.containsKey('queued')
              ? '${entry['message']} queued=1'
              : entry['message'],
          'platform': entry['platform'],
        },
      );
      return true;
    } catch (e) {
      debugPrint('[rtc] stage diagnostic report failed: $e');
      return false;
    }
  }

  /// THE QUEUE NEEDS ITS OWN HEARTBEAT.
  ///
  /// The first version flushed only after a LATER report happened to succeed,
  /// which fails in exactly the case the queue exists for: the network dies,
  /// the call ends, the room is torn down, and no further diagnostic is ever
  /// attempted -- so the held evidence is never delivered and the outage
  /// stays unexplained. Measured 2026-08-28: a whole blackout produced no
  /// Android traces, and I initially misread the cause as the endpoint
  /// refusing a departed participant. It does not; it only requires that a
  /// participant ROW exist. The queue simply had no way to try again.
  ///
  /// So it retries on its own, bounded: every 15 seconds while anything is
  /// held, giving up after [_diagnosticRetryLimit] rounds so a permanently
  /// offline client does not poll forever.
  static const Duration _diagnosticRetryEvery = Duration(seconds: 15);
  static const int _diagnosticRetryLimit = 20;
  Timer? _diagnosticRetryTimer;
  int _diagnosticRetryRounds = 0;

  void _armDiagnosticRetry() {
    if (_diagnosticRetryTimer != null) return;
    _diagnosticRetryRounds = 0;
    _diagnosticRetryTimer = Timer.periodic(_diagnosticRetryEvery, (t) async {
      _diagnosticRetryRounds += 1;
      if (_pendingDiagnostics.isEmpty ||
          _diagnosticRetryRounds > _diagnosticRetryLimit) {
        t.cancel();
        _diagnosticRetryTimer = null;
        return;
      }
      await _flushPendingDiagnostics();
      if (_pendingDiagnostics.isEmpty) {
        t.cancel();
        _diagnosticRetryTimer = null;
      }
    });
  }

  Future<void> _flushPendingDiagnostics() async {
    if (_flushingDiagnostics || _pendingDiagnostics.isEmpty) return;
    _flushingDiagnostics = true;
    try {
      while (_pendingDiagnostics.isNotEmpty) {
        final entry = _pendingDiagnostics.first;
        entry['queued'] = '1';
        if (!await _postDiagnostic(entry)) return; // still down; keep the rest
        _pendingDiagnostics.removeAt(0);
      }
    } finally {
      _flushingDiagnostics = false;
    }
  }

  Future<void> closeStageTransport(String sessionId) async {
    await _dio.post('/realtime/sessions/$sessionId/stage/transport/close', data: const {});
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

  /// REPORT THAT THIS DEVICE HAS A USABLE MEDIA PATH.
  ///
  /// Evidence, not a verdict. The backend decides whether the call is
  /// connected — and only once the other side has reported the same thing.
  /// The installation identity is read from the request headers the platform
  /// already sends, never from this body: a client does not get to claim which
  /// physical device it is.
  Future<void> reportMediaEstablished(
    String sessionId, {
    String? evidence,
  }) async {
    await _dio.post(
      '/realtime/sessions/$sessionId/media-established',
      data: {if (evidence != null && evidence.isNotEmpty) 'evidence': evidence},
    );
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

    if (surfaceType == 'conversation' && surfaceId.isNotEmpty) {
      // First-class Conversation surface consumer (founder directive
      // 2026-08-17 §3): the conversation-scoped join carries the surface's
      // own presence/notification semantics — never the generic fallback.
      final joinPath = '/conversations/$surfaceId/live/$id/join';
      // ignore: avoid_print
      print('[rtc-diag] REST join → $joinPath');
      await _dio.post(joinPath);
      // ignore: avoid_print
      print('[rtc-diag] REST join OK');
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
