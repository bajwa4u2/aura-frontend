import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/client_identity/client_identity.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../data/realtime_event_parser.dart';
import '../data/realtime_media_service.dart';
import '../data/realtime_repository.dart';
import '../data/realtime_socket_service.dart';
import '../domain/realtime_enums.dart';
import '../domain/realtime_models.dart';
import '../domain/realtime_state.dart';

class RealtimeController extends StateNotifier<RealtimeState> {
  RealtimeController(
    this._repository,
    this._socketService,
    this._mediaService,
    this._tokenStore,
    this._readClientIdentity,
  ) : super(RealtimeState.initial()) {
    _subscription = _socketService.events.listen(_handleSocketEvent);
    _mediaSubscription = _mediaService.snapshots.listen(_handleMediaSnapshot);
  }

  final RealtimeRepository _repository;
  final RealtimeSocketService _socketService;
  final RealtimeMediaService _mediaService;
  final TokenStore _tokenStore;
  // Awaits the client identity FutureProvider so the realtime handshake
  // always carries identity headers even on a very-early reconnect (e.g.
  // immediately after sign-in before any HTTP request has run). Resolves
  // synchronously from cache after the first successful read.
  final Future<ClientIdentity?> Function() _readClientIdentity;

  StreamSubscription<RealtimeParsedEvent>? _subscription;
  StreamSubscription<RealtimeMediaSnapshot>? _mediaSubscription;

  String? _hydratingSessionId;
  String? _joiningSessionId;
  bool _terminating = false;
  bool _endingCall = false;

  /// D4: client-side heartbeat ticker fires `session:heartbeat` every 20s
  /// while joined. The backend's stale-presence sweeper compares this
  /// against `heartbeatStaleAfterSeconds` (default 30) so a wedged client
  /// is reaped within ~45s of falling silent. Slow networks still get 1.5×
  /// the heartbeat interval before being treated as ghost.
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 20);

  Map<String, dynamic>? _rtcConfiguration;
  String? _rtcConfigurationSessionId;
  final Map<String, String> _pendingOfferTargets = <String, String>{};
  bool _flushingPendingOffers = false;

  String get _managedSessionId =>
      (state.sessionId ?? state.session?.id ?? '').trim();

  bool _isSameManagedSession(String sessionId) {
    final trimmed = sessionId.trim();
    return trimmed.isNotEmpty && _managedSessionId == trimmed;
  }

  RealtimeState _copyWithDetachedMediaState({
    required RealtimeJoinState joinState,
    String? infoMessage,
    String? lastSocketEvent,
    RealtimeConnectionStatus? connectionStatus,
    bool clearSessionContext = false,
    bool clearPolicy = false,
    bool clearErrorMessage = false,
  }) {
    return state.copyWith(
      connectionStatus: connectionStatus,
      joinState: joinState,
      clearSessionId: clearSessionContext,
      clearSession: clearSessionContext,
      participants: clearSessionContext
          ? const <RealtimeParticipant>[]
          : state.participants,
      clearPolicy: clearPolicy,
      consents: clearSessionContext
          ? const <RealtimeConsent>[]
          : state.consents,
      recordings: clearSessionContext
          ? const <RealtimeRecording>[]
          : state.recordings,
      transcripts: clearSessionContext
          ? const <RealtimeTranscriptJob>[]
          : state.transcripts,
      artifacts: clearSessionContext
          ? const <RealtimeArtifact>[]
          : state.artifacts,
      infoMessage: infoMessage,
      clearErrorMessage: clearErrorMessage,
      clearRemoteRenderers: true,
      clearLocalRenderer: true,
      isMediaReady: false,
      isMediaBusy: false,
      microphoneEnabled: false,
      cameraEnabled: false,
      clearMediaError: true,
      clearIncomingCall: true,
      clearCallMode: true,
      lastSocketEvent: lastSocketEvent,
    );
  }

  void _queueOfferTarget({
    required String peerKey,
    required String targetSocketId,
  }) {
    final normalizedPeerKey = peerKey.trim();
    final normalizedSocketId = targetSocketId.trim();
    if (normalizedPeerKey.isEmpty || normalizedSocketId.isEmpty) return;
    if (normalizedSocketId == _socketService.socketId) return;
    _pendingOfferTargets[normalizedPeerKey] = normalizedSocketId;
  }

  void _removePendingOfferTarget(String peerKey) {
    final normalizedPeerKey = peerKey.trim();
    if (normalizedPeerKey.isEmpty) return;
    _pendingOfferTargets.remove(normalizedPeerKey);
  }

  void _clearPendingOfferTargets() {
    _pendingOfferTargets.clear();
  }

  String _transportPeerKeyFromPayload(Map<String, dynamic> payload) {
    final socketId = (payload['socketId'] ?? '').toString().trim();
    if (socketId.isNotEmpty) return socketId;
    final fromSocketId = (payload['fromSocketId'] ?? '').toString().trim();
    if (fromSocketId.isNotEmpty) return fromSocketId;
    final userId = (payload['userId'] ?? '').toString().trim();
    return userId;
  }

  String _participantUserIdFromPayload(Map<String, dynamic> payload) {
    return (payload['userId'] ?? '').toString().trim();
  }

  Future<void> _flushPendingOffers({
    bool refreshTurnCredentials = false,
  }) async {
    if (_flushingPendingOffers || _pendingOfferTargets.isEmpty) return;

    final sessionId = _managedSessionId;
    if (sessionId.isEmpty || !state.isJoined) return;

    _flushingPendingOffers = true;
    try {
      await _ensureMediaReady(
        sessionId,
        refreshTurnCredentials: refreshTurnCredentials,
      );

      if (!state.isMediaReady) return;

      final queued = Map<String, String>.from(_pendingOfferTargets);
      for (final entry in queued.entries) {
        final peerKey = entry.key.trim();
        final targetSocketId = entry.value.trim();
        if (peerKey.isEmpty || targetSocketId.isEmpty) {
          _pendingOfferTargets.remove(entry.key);
          continue;
        }
        if (_pendingOfferTargets[peerKey] != targetSocketId) {
          continue;
        }

        try {
          await _sendOfferToSocket(
            peerKey: peerKey,
            targetSocketId: targetSocketId,
          );
          _pendingOfferTargets.remove(peerKey);
        } catch (error) {
          state = state.copyWith(errorMessage: error.toString());
        }
      }
    } finally {
      _flushingPendingOffers = false;
    }
  }

  Future<void> connect() async {
    if (state.connectionStatus == RealtimeConnectionStatus.connected ||
        state.connectionStatus == RealtimeConnectionStatus.connecting) {
      return;
    }

    state = state.copyWith(
      connectionStatus: RealtimeConnectionStatus.connecting,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );

    try {
      await _tokenStore.load();
      final token = _tokenStore.accessToken?.trim() ?? '';
      if (token.isEmpty) {
        throw StateError('You need to sign in before joining live.');
      }

      ClientIdentity? identity;
      try {
        identity = await _readClientIdentity();
      } catch (_) {
        identity = null;
      }

      await _socketService.connect(accessToken: token, identity: identity);

      state = state.copyWith(
        connectionStatus: RealtimeConnectionStatus.connected,
        infoMessage: 'Live connection ready.',
      );
    } catch (error) {
      state = state.copyWith(
        connectionStatus: RealtimeConnectionStatus.error,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<String> createSession({
    required String surfaceType,
    required String surfaceId,
    required String kind,
    Map<String, dynamic>? metadata,
  }) async {
    state = state.copyWith(
      isBusy: true,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );

    try {
      final bundle = await _repository.createSession(
        surfaceType: surfaceType,
        surfaceId: surfaceId,
        kind: kind,
        metadata: metadata,
      );
      _applyBundle(bundle);
      await _forceNegotiationIfNeeded();
      final normalizedKind = kind.trim().toLowerCase();
      state = state.copyWith(
        isBusy: false,
        sessionId: bundle.session.id,
        joinState: RealtimeJoinState.idle,
        callMode: normalizedKind == 'video' ? 'video' : 'audio',
        infoMessage: 'Live started here.',
      );
      return bundle.session.id;
    } catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: error.toString());
      rethrow;
    }
  }

  bool isManagingSurface({
    required String surfaceType,
    required String surfaceId,
  }) {
    final session = state.session;
    if (session == null) return false;
    final normalizedType = surfaceType.trim().toLowerCase();
    final sessionType = session.surfaceType.name.trim().toLowerCase();
    final targetId = surfaceId.trim();
    final currentId = (session.surfaceId ?? '').trim();
    return normalizedType.isNotEmpty &&
        sessionType == normalizedType &&
        targetId.isNotEmpty &&
        currentId == targetId;
  }

  Future<String> ensureCorrespondenceLive({
    required String surfaceType,
    required String surfaceId,
    required String kind,
    Map<String, dynamic>? metadata,
    bool joinAfterCreate = true,
  }) async {
    final normalizedType = surfaceType.trim().toUpperCase();
    final normalizedId = surfaceId.trim();
    final normalizedKind = kind.trim().toUpperCase();
    if (normalizedType.isEmpty || normalizedId.isEmpty) {
      throw StateError(
        'A conversation, space, or institution context is required before starting live.',
      );
    }

    if (isManagingSurface(
      surfaceType: normalizedType,
      surfaceId: normalizedId,
    )) {
      final existingSessionId = _managedSessionId;
      if (existingSessionId.isNotEmpty) {
        if (joinAfterCreate && state.joinState != RealtimeJoinState.joined) {
          await join(existingSessionId);
        }
        return existingSessionId;
      }
    }

    final sessionId = await createSession(
      surfaceType: normalizedType,
      surfaceId: normalizedId,
      kind: normalizedKind,
      metadata: metadata,
    );
    if (joinAfterCreate) {
      await join(sessionId);
    }
    return sessionId;
  }

  Future<void> disconnect() async {
    await _terminateSession(
      keepSocketConnected: false,
      infoMessage: null,
      alsoCallRepository: true,
    );

    state = state.copyWith(
      connectionStatus: RealtimeConnectionStatus.disconnected,
      clearInfoMessage: true,
      lastSocketEvent: 'socket:disconnected',
    );
  }

  Future<void> hydrateSession(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty) return;
    if (_hydratingSessionId == trimmed) return;

    _hydratingSessionId = trimmed;
    state = state.copyWith(
      isBusy: true,
      clearErrorMessage: true,
      sessionId: trimmed,
    );

    try {
      final bundle = await _repository.loadSessionBundle(trimmed);
      _applyBundle(bundle);
      await _forceNegotiationIfNeeded();
      state = state.copyWith(
        isBusy: false,
        infoMessage: state.isJoined ? state.infoMessage : 'Live loaded.',
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _safeJoinErrorMessage(error),
      );
      rethrow;
    } finally {
      if (_hydratingSessionId == trimmed) {
        _hydratingSessionId = null;
      }
    }
  }

  Future<void> join(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty || _terminating) return;

    final currentSessionId = (state.sessionId ?? state.session?.id ?? '')
        .trim();
    if (_joiningSessionId == trimmed) return;
    if (state.joinState == RealtimeJoinState.joined &&
        _isSameManagedSession(trimmed)) {
      return;
    }
    if (state.joinState == RealtimeJoinState.joining &&
        _isSameManagedSession(trimmed)) {
      return;
    }

    if (currentSessionId.isNotEmpty &&
        currentSessionId != trimmed &&
        state.isJoined) {
      await leave();
    }

    _joiningSessionId = trimmed;
    _clearRtcConfiguration();

    // Show "Connecting..." immediately — the user should see progress even
    // while the socket is being established (deeplink, cold page load, etc.).
    state = state.copyWith(
      joinState: RealtimeJoinState.joining,
      sessionId: trimmed,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );

    try {
      // P0: Ensure socket is connected BEFORE any join operations.
      // join() must never execute HTTP/socket join on a disconnected transport.
      if (!_socketService.isConnected) {
        await connect();
      }

      // Perform join with retry-once on transient socket/network errors.
      // A 30-second timeout covers the entire join phase.
      await _performJoinWithRetry(trimmed);
    } catch (error) {
      if (_terminating) return;

      // Retryable connection errors (socket drop, timeout, network) must NOT
      // put the user into a fatal "failed" state. Keep joinState=joining and
      // show a soft "Connecting…" message so the UI remains actionable and the
      // user can tap Join again when connectivity recovers.
      if (_isRetryableConnectionError(error)) {
        state = state.copyWith(
          connectionStatus: RealtimeConnectionStatus.reconnecting,
          infoMessage: 'Connecting…',
          clearErrorMessage: true,
        );
        return; // Do not rethrow — allow caller to retry.
      }

      state = state.copyWith(
        joinState: _mapJoinError(error),
        errorMessage: _safeJoinErrorMessage(error),
      );
      rethrow;
    } finally {
      if (_joiningSessionId == trimmed) {
        _joiningSessionId = null;
      }
    }
  }

  /// Attempts to join [sessionId], retrying transient transport errors with
  /// exponential backoff + jitter. The previous design retried exactly once
  /// with a hardcoded 30s timeout — a stuck-on-handshake socket would burn
  /// the entire 30s budget on the first attempt and leave the UI frozen.
  ///
  /// New shape:
  ///   - up to 3 attempts total (initial + 2 retries)
  ///   - per-attempt timeout: 15s
  ///   - backoff between attempts: 500ms, 1500ms (base), each with up to
  ///     ±50% jitter to avoid synchronized reconnect storms across clients
  ///     that all lost connectivity at the same instant
  ///   - non-retryable errors (e.g. business-rule rejections) bubble out
  ///     after the first attempt without consuming the budget
  ///   - if the user is mid-teardown or has navigated away mid-retry,
  ///     abort the loop instead of running ghost attempts against a dead
  ///     controller
  Future<void> _performJoinWithRetry(String sessionId) async {
    const maxAttempts = 3;
    const perAttemptTimeout = Duration(seconds: 15);
    const baseDelays = [
      Duration(milliseconds: 500),
      Duration(milliseconds: 1500),
    ];
    final rng = math.Random();

    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (_terminating || _joiningSessionId != sessionId) {
        // The caller (a re-join, a teardown, or a switch to another
        // session) has moved on. Don't run a phantom join that would
        // succeed against a controller no longer interested.
        return;
      }

      try {
        await _performJoin(sessionId).timeout(perAttemptTimeout);
        return;
      } catch (error, stack) {
        lastError = error;
        lastStack = stack;

        final retryable =
            error is TimeoutException || _isRetryableConnectionError(error);
        if (!retryable || attempt == maxAttempts - 1) {
          // Either the error is a business-rule failure (e.g. session
          // already ended) or we exhausted retries. Bubble out so the
          // caller surfaces the error to the user instead of looping.
          break;
        }

        // Backoff with ±50% jitter. Jitter is critical: multiple clients
        // reconnecting in lockstep after a server blip would otherwise
        // produce a thundering herd. The jitter window is symmetric so
        // expected backoff matches the base value.
        final base = baseDelays[attempt].inMilliseconds;
        final jittered = (base * (0.5 + rng.nextDouble())).round();
        await Future<void>.delayed(Duration(milliseconds: jittered));

        // If we lost the socket between attempts, re-establish before
        // the next try so the join doesn't fail-fast on no-transport.
        if (!_socketService.isConnected && !_terminating) {
          try {
            await connect().timeout(const Duration(seconds: 10));
          } catch (_) {
            // Connect failure here is fine — _performJoin will surface
            // a clearer error on its own attempt.
          }
        }
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(lastError, lastStack ?? StackTrace.current);
    }
  }

  bool _isRetryableConnectionError(Object error) {
    if (error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('socket') ||
        text.contains('connect') ||
        text.contains('websocket') ||
        text.contains('transport') ||
        text.contains('network');
  }

  Future<void> _performJoin(String sessionId) async {
    await hydrateSession(sessionId);

    final session = state.session;
    if (session == null) {
      throw StateError('Live session could not be loaded.');
    }

    if (!session.isActive) {
      throw StateError(
        session.surfaceType == RealtimeSurfaceType.meeting
            ? 'Meeting room is unavailable.'
            : 'Live session has already ended.',
      );
    }

    final isMeetingSession = session.surfaceType == RealtimeSurfaceType.meeting;
    if (isMeetingSession) {
      state = state.copyWith(
        joinState: RealtimeJoinState.joined,
        clearIncomingCall: true,
        infoMessage: 'Waiting for guest to join.',
        clearErrorMessage: true,
      );
    }

    if (isMeetingSession) {
      // Meeting GUESTS are not DB RealtimeSessionParticipants, so the member
      // REST join (POST /realtime/sessions/:id/join, strict @CurrentUserId)
      // 401s for them. For meetings the socket `session:join` below is
      // authoritative (it registers guests in-memory and broadcasts), so a REST
      // join failure must not abort — otherwise the guest never reaches the
      // socket join and the room shows "Something went wrong".
      try {
        final joinedBundle = await _repository.joinSession(session);
        _applyBundle(joinedBundle);
      } catch (_) {
        // Non-fatal for meetings — proceed to the socket join.
      }
    } else {
      final joinedBundle = await _repository.joinSession(session);
      _applyBundle(joinedBundle);
    }

    await connect();
    final meSocketId = _socketService.socketId ?? '';
    debugPrint(
      '[join-seq] 1 socket connected socketId=$meSocketId'
      ' sessionId=$sessionId isMeeting=$isMeetingSession',
    );

    debugPrint('[join-seq] 2 session join emitted sessionId=$sessionId');
    final Map<String, dynamic> joinAck = await _socketService.emitAck(
      'session:join',
      <String, dynamic>{'sessionId': sessionId},
    );
    debugPrint(
      '[join-seq] 3 session join ack received sessionId=$sessionId'
      ' ack=$joinAck',
    );

    // P0 FIX (guest reconnect storm): start the heartbeat the INSTANT the
    // socket join is acknowledged — BEFORE media/room readiness. Previously
    // _startHeartbeat ran only after _ensureMediaReady + negotiation at the end
    // of _performJoin; a guest that stalled in the media path never reached it,
    // so no heartbeat was ever sent, the server's 30s stale sweep expired the
    // participant, the socket recycled, and it reconnected forever. The
    // heartbeat only needs a joined socket, not media, so it must not wait.
    state = state.copyWith(
      joinState: RealtimeJoinState.joined,
      clearIncomingCall: true,
      infoMessage: isMeetingSession
          ? 'Waiting for guest to join.'
          : 'You joined live.',
    );
    debugPrint(
      '[join-seq] 4 state.isJoined=${state.isJoined} sessionId=$sessionId',
    );
    _startHeartbeat();
    debugPrint('[join-seq] 5 heartbeat started sessionId=$sessionId');

    // Media + negotiation run AFTER the heartbeat is live AND are wrapped so
    // they can NEVER throw out of _performJoin. Previously a failure here
    // bubbled to join()'s catch, which flips joinState off `joined`; the
    // heartbeat ticker then skips on its `!isJoined` guard, the participant
    // goes stale, and the guest drops back to "Connecting…" + reconnect. The
    // socket join is already acked and authoritative — media is best-effort and
    // self-retries, so a media/negotiation hiccup must not un-join the user.
    try {
      await _ensureMediaReady(sessionId, refreshTurnCredentials: true);
      await _flushPendingOffers(refreshTurnCredentials: true);
      await _forceNegotiationIfNeeded();
      debugPrint('[join-seq] 8 media+negotiation complete sessionId=$sessionId');
    } catch (e, st) {
      debugPrint(
        '[join-seq] media/negotiation NON-FATAL error sessionId=$sessionId'
        ' err=$e\n$st',
      );
    }
  }

  Future<void> resume(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty || _terminating) return;
    if (_joiningSessionId == trimmed) return;

    _joiningSessionId = trimmed;
    await connect();
    _clearRtcConfiguration();

    state = state.copyWith(
      joinState: RealtimeJoinState.joining,
      sessionId: trimmed,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );

    try {
      await _socketService.emitAck('session:resume', <String, dynamic>{
        'sessionId': trimmed,
      });

      await hydrateSession(trimmed);
      await _ensureMediaReady(trimmed, refreshTurnCredentials: true);

      state = state.copyWith(
        joinState: RealtimeJoinState.joined,
        clearIncomingCall: true,
        infoMessage: 'Your live session was restored.',
      );
      _startHeartbeat();
      await _flushPendingOffers(refreshTurnCredentials: true);
      await _forceNegotiationIfNeeded();
    } catch (error) {
      state = state.copyWith(
        joinState: _mapJoinError(error),
        errorMessage: _safeJoinErrorMessage(error),
      );
    } finally {
      if (_joiningSessionId == trimmed) {
        _joiningSessionId = null;
      }
    }
  }

  Future<void> leave() async {
    if (_terminating) return;
    final sessionId = (state.sessionId ?? '').trim();
    if (sessionId.isEmpty) return;

    await _terminateSession(
      keepSocketConnected: true,
      infoMessage: 'You left live.',
      alsoCallRepository: true,
    );
  }

  /// Clears local session state without any backend or socket calls.
  ///
  /// Called from the messages tab when the [callPresenceBridgeProvider]
  /// BroadcastChannel signals the call ended in the popup window.
  /// The main tab was never joined (joinState stays idle), so none of the
  /// regular terminate paths fire — this is the only way to evict the stale
  /// session reference that [_threadResolvedSessionId] falls back to.
  void clearLocalSession() {
    final sessionId = (state.sessionId ?? '').trim();
    if (sessionId.isEmpty && state.session == null) return;
    _joiningSessionId = null;
    _hydratingSessionId = null;
    _terminating = false;
    _clearRtcConfiguration();
    _clearPendingOfferTargets();
    state = _copyWithDetachedMediaState(
      joinState: RealtimeJoinState.idle,
      clearSessionContext: true,
      clearPolicy: true,
      clearErrorMessage: true,
    );
  }

  /// Ends the session entirely (host action). Calls the backend /end endpoint
  /// so the session is marked ENDED and all participants are notified.
  /// Use [leave] when only one participant departs; use [endCall] when the
  /// host intends to terminate the session for everyone.
  /// End the session for everyone. This is deliberately local-first:
  /// backend failure must never leave the user trapped in the call UI or force a
  /// second tap. The captured session is sent to the backend, while local media,
  /// socket membership, and call state are torn down regardless of that result.
  Future<void> endCall() async {
    if (_endingCall) {
      return;
    }

    final sessionId = _managedSessionId;
    final session = state.session;
    if (sessionId.isEmpty && session == null) {
      state = _copyWithDetachedMediaState(
        joinState: RealtimeJoinState.idle,
        clearSessionContext: true,
        clearPolicy: true,
        clearErrorMessage: true,
        infoMessage: 'Call ended.',
      );
      return;
    }

    _endingCall = true;
    // A5: surface the in-progress end through state so every UI surface
    // (room screen, PiP) reads from a single authoritative flag instead of
    // carrying its own `_isEnding` race that can fire endCall a second time.
    state = state.copyWith(isEndingCall: true);
    try {
      // Always fire the server-end RPC on a host tap, even if a concurrent
      // socket teardown set `_terminating`. The backend is idempotent on
      // double-end; not firing leaves the host's authoritative end stuck
      // on the client and the UI navigates away with the server still
      // believing the session is live.
      unawaited(_repository.endSession(session).catchError((Object error) {}));

      // If a concurrent teardown is already in-flight, skip the second
      // local teardown — but the server end above has already fired.
      if (!_terminating) {
        await _terminateSession(
          keepSocketConnected: true,
          infoMessage: 'Call ended.',
          alsoCallRepository: false,
        );
      }
    } finally {
      _endingCall = false;
      // Clear the flag — _terminateSession's _copyWithDetachedMediaState
      // already nukes most of the state, but does not touch isEndingCall.
      // We reset it explicitly so a subsequent call can lock again.
      state = state.copyWith(isEndingCall: false);
    }
  }

  /// A4: room screen calls this from initState/dispose to publish whether the
  /// dedicated full-screen call surface is mounted. PiP visibility reads
  /// `state.isCallRoomVisible` instead of route path, eliminating the 1-2
  /// frame race where neither full screen nor PiP rendered during minimize.
  void setCallRoomVisible(bool visible) {
    if (state.isCallRoomVisible == visible) return;
    state = state.copyWith(isCallRoomVisible: visible);
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    var firstBeat = true;
    // Fire one heartbeat immediately so the server's lastSeenAt is refreshed
    // right after join — don't wait a full interval for the first beat.
    _sendHeartbeat(isFirst: true);
    firstBeat = false;
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat(isFirst: firstBeat);
      firstBeat = false;
    });
  }

  void _sendHeartbeat({required bool isFirst}) {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty || !state.isJoined) {
      debugPrint(
        '[join-seq] heartbeat SKIPPED sessionId=$sessionId'
        ' isJoined=${state.isJoined}',
      );
      return;
    }
    if (isFirst) {
      debugPrint('[join-seq] 6 first heartbeat sent sessionId=$sessionId');
    }
    // emitAck is best-effort — a transient network blip drops the beat
    // but the next 20s tick recovers. The server ignores heartbeats from
    // non-joined sockets, so the ticker is safe to keep running.
    unawaited(
      _socketService
          .emitAck('session:heartbeat', <String, dynamic>{
            'sessionId': sessionId,
          })
          .then((ack) {
            if (isFirst) {
              debugPrint(
                '[join-seq] 7 heartbeat ack received sessionId=$sessionId'
                ' ack=$ack',
              );
            }
          })
          .catchError((Object e) {
            if (isFirst) {
              debugPrint(
                '[join-seq] 7 heartbeat ack FAILED sessionId=$sessionId err=$e',
              );
            }
          }),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> toggleMicrophone() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    if (state.isMediaBusy) {
      // Tracks are mid-acquisition — the busy spinner already communicates
      // this in the UI. Swallow the tap rather than racing the underlying
      // permission/media negotiation.
      return;
    }
    if (!state.isMediaReady) {
      // No live track yet. The most common cause is that the OS hasn't
      // delivered a permission decision; the next most common is
      // hardware that's still warming up after a device switch. Either
      // way, the user's next action is to wait or grant permission in
      // OS settings — not to retry the toggle.
      state = state.copyWith(
        infoMessage:
            'Preparing your microphone. If this stays, check microphone permission for Aura in your device settings.',
        clearErrorMessage: true,
      );
      return;
    }

    final enabled = !state.microphoneEnabled;
    await _mediaService.setMicrophoneEnabled(enabled);
    await _socketService.emitAck('session:audio.set', <String, dynamic>{
      'sessionId': sessionId,
      'enabled': enabled,
    });
    _patchMyTrack(audioOn: enabled);
  }

  Future<void> toggleCamera() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    if (state.isMediaBusy) return;
    if (!state.isVideoMode) {
      state = state.copyWith(
        infoMessage: 'Camera is only available in video calls.',
        clearErrorMessage: true,
      );
      return;
    }
    if (!state.isMediaReady) {
      // Same shape as the microphone branch. The mic message handles the
      // common case; for camera we add the explicit "front/back camera"
      // note since some devices fail acquisition silently when another
      // app has the camera open.
      state = state.copyWith(
        infoMessage:
            'Preparing your camera. If this stays, check camera permission for Aura in your device settings and close any other app using the camera.',
        clearErrorMessage: true,
      );
      return;
    }

    final enabled = !state.cameraEnabled;
    await _mediaService.setCameraEnabled(enabled);
    await _socketService.emitAck('session:video.set', <String, dynamic>{
      'sessionId': sessionId,
      'enabled': enabled,
    });
    _patchMyTrack(videoOn: enabled);
  }

  /// I1: Start broadcasting the local screen. Replaces the video track in each
  /// peer connection with the display media track and signals the change.
  Future<void> startScreenShare() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _mediaService.startScreenShare();

    unawaited(
      _socketService
          .emitAck('session:screen.set', <String, dynamic>{
            'sessionId': sessionId,
            'enabled': true,
          })
          .catchError((Object _) => <String, dynamic>{}),
    );
  }

  /// I1: Stop broadcasting the local screen. Restores the camera track in each
  /// peer connection and signals the change.
  Future<void> stopScreenShare() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _mediaService.stopScreenShare();

    unawaited(
      _socketService
          .emitAck('session:screen.set', <String, dynamic>{
            'sessionId': sessionId,
            'enabled': false,
          })
          .catchError((Object _) => <String, dynamic>{}),
    );
  }

  /// I4: Flip between front and rear camera. No-op when not in a video session
  /// or when media is not ready.
  Future<void> flipCamera() async {
    if (!state.isMediaReady || !state.isVideoMode) return;
    await _mediaService.switchCamera();
  }

  Future<void> requestJoin(String sessionId) async {
    await _repository.createJoinRequest(sessionId);
    state = state.copyWith(
      sessionId: sessionId,
      joinState: RealtimeJoinState.requested,
      infoMessage: 'Entry request sent.',
      clearErrorMessage: true,
    );
  }

  Future<void> refreshPolicy() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    try {
      final policy = await _repository.getPolicy(sessionId);
      state = state.copyWith(policy: policy);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> refreshArtifacts() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    try {
      final artifacts = await _repository.listArtifacts(sessionId);
      state = state.copyWith(artifacts: artifacts);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> setWaitingRoom(bool enabled) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final policy = await _repository.updatePolicy(
      sessionId,
      waitingRoomEnabled: enabled,
    );
    state = state.copyWith(
      policy: policy,
      infoMessage: enabled
          ? 'Entry requests turned on.'
          : 'Entry requests turned off.',
    );
  }

  Future<void> setLocked(bool locked) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final policy = await _repository.setLocked(sessionId, locked: locked);
    final session = state.session;

    state = state.copyWith(
      session: session == null
          ? null
          : RealtimeSession(
              id: session.id,
              surfaceType: session.surfaceType,
              surfaceId: session.surfaceId,
              startedByUserId: session.startedByUserId,
              status: session.status,
              kind: session.kind,
              isActive: session.isActive,
              isLocked: locked,
              waitingRoomEnabled: session.waitingRoomEnabled,
              startedAt: session.startedAt,
              answeredAt: session.answeredAt,
              firstJoinedAt: session.firstJoinedAt,
              endedAt: session.endedAt,
              durationSeconds: session.durationSeconds,
              createdAt: session.createdAt,
              updatedAt: DateTime.now(),
              activeParticipantCount: session.activeParticipantCount,
            ),
      policy: policy,
      infoMessage: locked
          ? 'Room closed to new entries.'
          : 'Room opened to new entries.',
    );
  }

  Future<void> approveJoinRequest(String requestUserId) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.respondToJoinRequest(
      sessionId,
      requestUserId: requestUserId,
      decision: 'approve',
    );

    await refreshPolicy();
    await hydrateSession(sessionId);
    state = state.copyWith(infoMessage: 'Entry request approved.');
  }

  Future<void> rejectJoinRequest(String requestUserId) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.respondToJoinRequest(
      sessionId,
      requestUserId: requestUserId,
      decision: 'reject',
    );

    await refreshPolicy();
    state = state.copyWith(infoMessage: 'Entry request declined.');
  }

  Future<void> inviteMember({
    required String invitedUserId,
    String? note,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.createInvite(
      sessionId,
      invitedUserId: invitedUserId,
      note: note,
    );

    state = state.copyWith(
      infoMessage: 'Invitation sent.',
      clearErrorMessage: true,
    );
  }

  Future<void> removeParticipant(String targetUserId) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.removeParticipant(sessionId, targetUserId);
    await hydrateSession(sessionId);
    state = state.copyWith(
      infoMessage: 'Member removed from this live session.',
    );
  }

  Future<void> requestConsent() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.requestConsent(sessionId);
    await syncConsentsVisibility(canManageConsents: false);
    state = state.copyWith(infoMessage: 'Fresh consent requested.');
  }

  Future<void> answerConsent({required bool granted}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.respondToOwnConsent(
      sessionId,
      decision: granted ? 'grant' : 'decline',
    );
    await syncConsentsVisibility(canManageConsents: false);
    state = state.copyWith(
      infoMessage: granted ? 'Consent granted.' : 'Consent declined.',
    );
  }

  Future<void> syncConsentsVisibility({
    required bool? canManageConsents,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    if (canManageConsents == null) return;

    try {
      final consents = canManageConsents
          ? await _repository.listConsents(sessionId)
          : await _repository.getOwnConsent(sessionId);
      state = state.copyWith(consents: consents);
    } catch (error) {
      if (canManageConsents) {
        try {
          final consents = await _repository.getOwnConsent(sessionId);
          state = state.copyWith(consents: consents);
          return;
        } catch (_) {}
      }
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> requestRecording({String? title}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.requestRecording(sessionId, title: title);
    final recordings = await _repository.listRecordings(sessionId);
    state = state.copyWith(
      recordings: recordings,
      infoMessage: 'Recording requested.',
    );
  }

  Future<void> requestTranscript({String? title}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    await _repository.requestTranscript(sessionId, title: title);
    final transcripts = await _repository.listTranscripts(sessionId);
    state = state.copyWith(
      transcripts: transcripts,
      infoMessage: 'Live notes requested.',
    );
  }

  void clearMessage() {
    state = state.copyWith(clearErrorMessage: true, clearInfoMessage: true);
  }

  void _applyBundle(RealtimeSessionSnapshot bundle) {
    final session = bundle.session;
    final sessionKind = session.kind.trim().toUpperCase();

    // session.kind is the sole authority for call mode. Participant media
    // state (hasVideo) reflects capability, not the call type the host chose.
    //
    // MIXED must map to 'video': meetings are created with kind=MIXED
    // (MeetingSessionBridgeService), and leaving it null made isVideoMode=false,
    // so _ensureMediaReady captured an AUDIO-ONLY stream — no video track was
    // ever published and "Show camera" (setCameraEnabled) had no track to
    // enable. That is the "guest side is just audio" defect. MIXED is
    // video-capable; users can still turn their camera off.
    final String? callMode;
    if (sessionKind == 'VIDEO' || sessionKind == 'MIXED') {
      callMode = 'video';
    } else if (sessionKind == 'AUDIO') {
      callMode = 'audio';
    } else {
      callMode = state.callMode;
    }

    state = state.copyWith(
      session: session,
      sessionId: session.id,
      callMode: callMode,
      participants: bundle.participants,
      policy: bundle.policy,
      consents: bundle.consents,
      recordings: bundle.recordings,
      transcripts: bundle.transcriptJobs,
      artifacts: bundle.artifacts,
    );
  }

  Future<void> _terminateSession({
    required bool keepSocketConnected,
    String? infoMessage,
    required bool alsoCallRepository,
  }) async {
    if (_terminating) return;
    _terminating = true;
    _stopHeartbeat();

    final session = state.session;
    final sessionId = _managedSessionId;

    try {
      if (sessionId.isNotEmpty && keepSocketConnected) {
        try {
          await _socketService.emitAck('session:leave', <String, dynamic>{
            'sessionId': sessionId,
          });
        } catch (_) {}
      }

      if (alsoCallRepository && sessionId.isNotEmpty) {
        try {
          await _repository.leaveSession(session);
        } catch (_) {}
      }

      try {
        await _mediaService.resetSessionMedia();
      } catch (e) {
        final _ = e;
      }
      if (!keepSocketConnected) {
        try {
          await _socketService.disconnect();
        } catch (_) {}
      }
      _clearRtcConfiguration();
      _clearPendingOfferTargets();

      state = _copyWithDetachedMediaState(
        joinState: RealtimeJoinState.idle,
        clearSessionContext: true,
        clearPolicy: true,
        clearErrorMessage: true,
        infoMessage: infoMessage,
      );
    } finally {
      _joiningSessionId = null;
      _hydratingSessionId = null;
      _terminating = false;
    }
  }

  Future<void> _ensureMediaReady(
    String sessionId, {
    bool refreshTurnCredentials = false,
  }) async {
    if (state.isMediaBusy) return;

    state = state.copyWith(isMediaBusy: true, clearMediaError: true);

    try {
      final configuration = await _resolveRtcConfiguration(
        sessionId,
        refreshTurnCredentials: refreshTurnCredentials,
      );

      final wantsAudio = state.policy?.audioAllowed ?? true;
      final wantsVideo =
          state.isVideoMode && (state.policy?.videoAllowed ?? true);

      if (!state.isMediaReady) {
        await _mediaService.ensureLocalMedia(
          audio: wantsAudio,
          video: wantsVideo,
        );
      }

      await _socketService.emitAck('session:audio.set', <String, dynamic>{
        'sessionId': sessionId,
        'enabled': wantsAudio,
      });
      await _socketService.emitAck('session:video.set', <String, dynamic>{
        'sessionId': sessionId,
        'enabled': wantsVideo,
      });

      state = state.copyWith(
        isMediaBusy: false,
        isMediaReady: true,
        microphoneEnabled: wantsAudio,
        cameraEnabled: wantsVideo,
      );

      _rtcConfiguration = configuration;
      _rtcConfigurationSessionId = sessionId;
    } catch (error) {
      state = state.copyWith(
        isMediaBusy: false,
        mediaError: error.toString(),
        infoMessage: 'You are connected, but browser media is not active yet.',
      );
    }
  }

  Future<Map<String, dynamic>> _resolveRtcConfiguration(
    String sessionId, {
    bool refreshTurnCredentials = false,
  }) async {
    if (!refreshTurnCredentials &&
        _rtcConfiguration != null &&
        _rtcConfigurationSessionId == sessionId) {
      return _rtcConfiguration!;
    }

    final issued = await _repository.issueTurnCredentials(sessionId);
    final rawIceServers = issued['iceServers'];
    final configuration = <String, dynamic>{
      'iceServers': rawIceServers is List ? rawIceServers : const <dynamic>[],
      'sdpSemantics': 'unified-plan',
    };

    _rtcConfiguration = configuration;
    _rtcConfigurationSessionId = sessionId;
    return configuration;
  }

  void _clearRtcConfiguration() {
    _rtcConfiguration = null;
    _rtcConfigurationSessionId = null;
  }

  void _handleMediaSnapshot(RealtimeMediaSnapshot snapshot) {
    state = state.copyWith(
      isMediaReady: snapshot.ready,
      localRenderer: snapshot.localRenderer,
      remoteRenderers: snapshot.remoteRenderers,
      microphoneEnabled: snapshot.micEnabled,
      cameraEnabled: snapshot.cameraEnabled,
      mediaError: snapshot.error,
      isScreenSharing: snapshot.isScreenSharing,
    );

    if (snapshot.ready && state.isJoined) {
      unawaited(_flushPendingOffers());
      unawaited(_forceNegotiationIfNeeded());
    }
  }

  Future<void> _sendOfferToSocket({
    required String peerKey,
    required String targetSocketId,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final configuration = await _resolveRtcConfiguration(sessionId);

    final offer = await _mediaService.createOffer(
      peerKey: peerKey,
      targetSocketId: targetSocketId,
      configuration: configuration,
      onIceCandidate: (candidate) {
        unawaited(
          _socketService.emitAck('session:ice-candidate', <String, dynamic>{
            'sessionId': sessionId,
            'targetSocketId': targetSocketId,
            'candidate': <String, dynamic>{
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          }),
        );
      },
    );

    await _socketService.emitAck('session:offer', <String, dynamic>{
      'sessionId': sessionId,
      'targetSocketId': targetSocketId,
      'sdp': <String, dynamic>{'sdp': offer.sdp, 'type': offer.type},
    });
  }

  void _patchMyTrack({bool? audioOn, bool? videoOn}) {
    final meSocketId = _socketService.socketId;
    if (meSocketId == null) return;
    state = state.copyWith(
      participants: state.participants
          .map(
            (participant) => participant.runtimeDeviceId == meSocketId
                ? participant.copyWith(
                    audioOn: audioOn ?? participant.audioOn,
                    videoOn: videoOn ?? participant.videoOn,
                  )
                : participant,
          )
          .toList(),
    );
  }

  void _handleSocketEvent(RealtimeParsedEvent event) {
    switch (event.name) {
      case 'socket:connected':
        state = state.copyWith(
          connectionStatus: RealtimeConnectionStatus.connected,
          lastSocketEvent: event.name,
        );
        return;
      case 'socket:disconnected':
        // R4 — Cancel the heartbeat ticker on disconnect. The body
        // already skips emits when `!state.isJoined`, but the periodic
        // timer keeps the scheduler waking up every 20s and can leak
        // across a sign-out / sign-in on the same tab if the controller
        // isn't disposed. Stopping it on disconnect is defensive — a
        // fresh join restarts it through `_startHeartbeat`.
        _stopHeartbeat();
        _clearPendingOfferTargets();
        unawaited(_mediaService.resetSessionMedia());
        state = _copyWithDetachedMediaState(
          connectionStatus: RealtimeConnectionStatus.disconnected,
          joinState: RealtimeJoinState.idle,
          clearSessionContext: true,
          lastSocketEvent: event.name,
        );
        return;
      case 'socket:connect_error':
      case 'socket:error':
        state = state.copyWith(
          connectionStatus: RealtimeConnectionStatus.error,
          errorMessage: event.payload['message']?.toString(),
          lastSocketEvent: event.name,
        );
        return;
      case 'session:participant.joined':
      case 'session:participant.resumed':
        final merged = RealtimeEventParser.mergeSnapshot(state, event.payload);
        final modeFromEvent =
            ((event.payload['videoState'] ?? '').toString().toUpperCase() ==
                    'ON' ||
                (event.payload['screenState'] ?? '').toString().toUpperCase() ==
                    'ON')
            ? 'video'
            : merged.callMode;
        state = merged.copyWith(
          callMode: modeFromEvent,
          lastSocketEvent: event.name,
        );

        // Offer initiation is centralized in _forceNegotiationIfNeeded, which
        // applies the deterministic-initiator glare guard. Queuing an offer
        // directly here bypassed that guard and re-introduced glare (both peers
        // offering at once → collision → connection failed → reconnect loop).
        // Just run the negotiation sweep: we offer to the peers we initiate for
        // and answer the offers from the rest.
        if (state.isJoined) {
          unawaited(_flushPendingOffers());
          unawaited(_forceNegotiationIfNeeded());
        }
        return;
      case 'session:participant.left':
        final leavingUserId = _participantUserIdFromPayload(event.payload);
        final leavingPeerKey = _transportPeerKeyFromPayload(event.payload);
        final updatedParticipants = state.participants
            .where((participant) => participant.userId != leavingUserId)
            .toList();

        state = state.copyWith(
          participants: updatedParticipants,
          lastSocketEvent: event.name,
        );

        if (leavingPeerKey.isNotEmpty) {
          _removePendingOfferTarget(leavingPeerKey);
          unawaited(_mediaService.removePeer(leavingPeerKey));
        } else if (leavingUserId.isNotEmpty) {
          _removePendingOfferTarget(leavingUserId);
          unawaited(_mediaService.removePeer(leavingUserId));
        }

        if (updatedParticipants.length <= 1 && state.isJoined) {
          unawaited(
            _terminateSession(
              keepSocketConnected: true,
              infoMessage: 'Call ended.',
              alsoCallRepository: false,
            ),
          );
        }
        return;
      case 'session:offer':
        unawaited(() async {
          final sessionId = state.sessionId;
          if (sessionId == null || sessionId.isEmpty) return;

          await _ensureMediaReady(sessionId);
          final configuration = _rtcConfiguration;
          if (configuration == null) return;

          final peerKey = _transportPeerKeyFromPayload(event.payload);
          final fromSocketId = event.payload['fromSocketId']?.toString();
          if (peerKey.isEmpty || fromSocketId == null || fromSocketId.isEmpty) {
            return;
          }
          final answer = await _mediaService.handleRemoteOffer(
            peerKey: peerKey,
            targetSocketId: fromSocketId,
            configuration: configuration,
            sdp: Map<String, dynamic>.from(
              (event.payload['sdp'] ?? const <String, dynamic>{}) as Map,
            ),
            onIceCandidate: (candidate) {
              unawaited(
                _socketService.emitAck(
                  'session:ice-candidate',
                  <String, dynamic>{
                    'sessionId': sessionId,
                    'targetSocketId': fromSocketId,
                    'candidate': <String, dynamic>{
                      'candidate': candidate.candidate,
                      'sdpMid': candidate.sdpMid,
                      'sdpMLineIndex': candidate.sdpMLineIndex,
                    },
                  },
                ),
              );
            },
          );
          await _socketService.emitAck('session:answer', <String, dynamic>{
            'sessionId': sessionId,
            'targetSocketId': fromSocketId,
            'sdp': <String, dynamic>{'sdp': answer.sdp, 'type': answer.type},
          });
        }());
        state = state.copyWith(lastSocketEvent: event.name);
        return;
      case 'session:answer':
        unawaited(() async {
          final peerKey = _transportPeerKeyFromPayload(event.payload);
          if (peerKey.isEmpty) return;
          final sdp = event.payload['sdp'];
          if (sdp is Map) {
            await _mediaService.handleRemoteAnswer(
              peerKey: peerKey,
              sdp: Map<String, dynamic>.from(sdp),
            );
          }
        }());
        state = state.copyWith(lastSocketEvent: event.name);
        return;
      case 'session:ice-candidate':
        unawaited(() async {
          final peerKey = _transportPeerKeyFromPayload(event.payload);
          if (peerKey.isEmpty) return;
          final candidate = event.payload['candidate'];
          if (candidate is Map) {
            await _mediaService.addRemoteCandidate(
              peerKey: peerKey,
              candidate: Map<String, dynamic>.from(candidate),
            );
          }
        }());
        state = state.copyWith(lastSocketEvent: event.name);
        return;
      case 'session:track.updated':
        final userId = event.payload['userId']?.toString();
        if (userId != null && userId.isNotEmpty) {
          final videoOn =
              (event.payload['videoState'] ?? '').toString().toUpperCase() ==
              'ON';
          final screenOn =
              (event.payload['screenState'] ?? '').toString().toUpperCase() ==
              'ON';
          state = state.copyWith(
            callMode: (videoOn || screenOn) ? 'video' : state.callMode,
            participants: state.participants
                .map(
                  (participant) => participant.userId == userId
                      ? participant.copyWith(
                          audioOn:
                              (event.payload['audioState'] ?? '')
                                  .toString()
                                  .toUpperCase() ==
                              'ON',
                          videoOn: videoOn,
                          screenOn: screenOn,
                        )
                      : participant,
                )
                .toList(),
            lastSocketEvent: event.name,
          );
        }
        return;
      case 'session:replaced':
        state = state.copyWith(
          connectionStatus: RealtimeConnectionStatus.reconnecting,
          infoMessage: 'This live session moved to a new connection.',
          lastSocketEvent: event.name,
        );
        return;
      case 'session:removed':
      case 'realtime:removed':
        _clearPendingOfferTargets();
        unawaited(_mediaService.resetSessionMedia());
        state = _copyWithDetachedMediaState(
          joinState: RealtimeJoinState.removed,
          infoMessage: 'You were removed from this live session.',
          lastSocketEvent: event.name,
        );
        return;
      case 'join:requested':
        state = state.copyWith(
          joinState: RealtimeJoinState.requested,
          infoMessage: 'Your request to join is pending.',
          lastSocketEvent: event.name,
        );
        return;
      case 'join:approved':
        state = state.copyWith(
          joinState: RealtimeJoinState.joined,
          infoMessage: 'Your request to join was approved.',
          lastSocketEvent: event.name,
        );
        return;
      case 'join:rejected':
        state = state.copyWith(
          joinState: RealtimeJoinState.rejected,
          infoMessage: 'Your request to join was declined.',
          lastSocketEvent: event.name,
        );
        return;
      case 'call:incoming':
        // Routing is owned by `incomingCallBridgeProvider`, which listens
        // to BOTH the correspondence socket and this realtime socket and
        // dedupes by session id. We surface the event on `lastSocketEvent`
        // so observability dashboards and debug overlays can confirm the
        // event reached the controller, but we intentionally do not
        // mutate `participants` / `joinState` here — the controller is
        // responsible for the join/leave lifecycle, not the ring UI.
        state = state.copyWith(lastSocketEvent: event.name);
        return;
      case 'call:declined':
        final declinedUserId = (event.payload['userId'] ?? '')
            .toString()
            .trim();
        final declinedSessionId = (event.payload['sessionId'] ?? '')
            .toString()
            .trim();
        // Ignore if this event belongs to a different session
        if (declinedSessionId.isNotEmpty &&
            state.session?.id != null &&
            declinedSessionId != state.session!.id) {
          return;
        }
        final participantsAfterDecline = state.participants
            .where((p) => p.userId != declinedUserId)
            .toList();
        if (participantsAfterDecline.length <= 1 && state.isJoined) {
          unawaited(
            _terminateSession(
              keepSocketConnected: true,
              infoMessage: 'Call declined.',
              alsoCallRepository: true,
            ),
          );
        } else {
          state = state.copyWith(
            participants: participantsAfterDecline,
            infoMessage: 'Someone declined the call.',
            lastSocketEvent: event.name,
          );
        }
        return;
      case 'session:ended':
      case 'call:terminal':
        // Session ended — tear down media, clear stale bundle cache so any
        // subsequent fetch sees the ENDED status rather than a cached snapshot.
        // C6: `call:terminal` arriving on either socket converges to the
        // same teardown path as a primary `session:ended`.
        final endedSessionId = _managedSessionId;
        // Only honor the terminal event when it concerns the call we are
        // currently in. A stale `call:terminal` for an unrelated session
        // (e.g. a previous tab's teardown) must not nuke the current call.
        final eventSessionId = (event.payload['sessionId'] ?? '')
            .toString()
            .trim();
        if (eventSessionId.isNotEmpty &&
            endedSessionId.isNotEmpty &&
            eventSessionId != endedSessionId) {
          state = state.copyWith(lastSocketEvent: event.name);
          return;
        }
        final terminalReason = (event.payload['reason'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
        final terminalCallState = (event.payload['callState'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
        if (state.session?.surfaceType == RealtimeSurfaceType.meeting &&
            (terminalReason == 'ACCEPTED' || terminalCallState == 'ACTIVE')) {
          state = state.copyWith(lastSocketEvent: event.name);
          return;
        }
        _clearPendingOfferTargets();
        if (endedSessionId.isNotEmpty) {
          _repository.clearBundleCache(endedSessionId);
        }
        unawaited(_mediaService.resetSessionMedia());
        state = _copyWithDetachedMediaState(
          joinState: RealtimeJoinState.idle,
          clearSessionContext: true,
          infoMessage: state.session?.surfaceType == RealtimeSurfaceType.meeting
              ? 'The meeting has ended.'
              : 'The call has ended.',
          lastSocketEvent: event.name,
        );
        return;
      case 'session:stale':
        if (state.session?.surfaceType == RealtimeSurfaceType.meeting) {
          state = state.copyWith(lastSocketEvent: event.name);
          return;
        }
        // Server detected heartbeat timeout and is about to disconnect this
        // socket — treat as a local disconnect so the UI tears down cleanly.
        _clearPendingOfferTargets();
        unawaited(_mediaService.resetSessionMedia());
        state = _copyWithDetachedMediaState(
          connectionStatus: RealtimeConnectionStatus.disconnected,
          joinState: RealtimeJoinState.idle,
          clearSessionContext: true,
          lastSocketEvent: event.name,
        );
        return;
      case 'session:state':
      case 'participants:updated':
      case 'policy:updated':
      case 'session:policyUpdated':
      case 'session:updated':
      case 'session:participantUpdated':
      case 'session:participantRemoved':
      case 'consent:updated':
      case 'recording:updated':
      case 'transcript:updated':
      case 'artifact:updated':
        // Ignore stale server push events when the local session is idle —
        // merging them would restore cleared state and keep polling alive
        // after endCall() / leave() has already torn down the session.
        if (state.joinState == RealtimeJoinState.idle) {
          state = state.copyWith(lastSocketEvent: event.name);
          return;
        }
        final merged = RealtimeEventParser.mergeSnapshot(state, event.payload);
        state = merged.copyWith(lastSocketEvent: event.name);
        return;
      default:
        state = state.copyWith(lastSocketEvent: event.name);
        return;
    }
  }

  RealtimeJoinState _mapJoinError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('approval') || text.contains('waiting room')) {
      return RealtimeJoinState.requested;
    }
    if (text.contains('locked')) return RealtimeJoinState.locked;
    if (text.contains('reject')) return RealtimeJoinState.rejected;
    // Expired invites and closed sessions are terminal — map to failed so the
    // pre-join view can detect them via errorMessage and suppress the retry button.
    if (text.contains('invite_expired') ||
        text.contains('invite has expired') ||
        text.contains('session_closed') ||
        text.contains('session is closed')) {
      return RealtimeJoinState.failed;
    }
    return RealtimeJoinState.failed;
  }

  /// Convert any error into a safe user-facing message for the join /
  /// hydrate / resume paths. Stale-call deeplinks land here as
  /// `DioException` 403/404 ("Realtime session is closed") or as the
  /// internal `StateError('This session has already ended.')` thrown
  /// from [_performJoin]; both should surface as a clean terminal
  /// message instead of `Instance of 'DioException'` or a raw stack
  /// trace. AppErrorMapper handles 401/403/404/5xx; we only override
  /// for the call-specific terminal codes.
  String _safeJoinErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('invite_expired') ||
        text.contains('invite has expired')) {
      return state.session?.surfaceType == RealtimeSurfaceType.meeting
          ? 'This meeting invite has expired.'
          : 'This call invite has expired.';
    }
    if (text.contains('session_closed') ||
        text.contains('session is closed') ||
        text.contains('already ended')) {
      return state.session?.surfaceType == RealtimeSurfaceType.meeting
          ? 'This meeting is unavailable right now. Please try again.'
          : 'This call has ended.';
    }
    if (text.contains('locked')) {
      return state.session?.surfaceType == RealtimeSurfaceType.meeting
          ? 'This meeting room is locked.'
          : 'This call is locked.';
    }
    if (text.contains('approval') || text.contains('waiting room')) {
      return state.session?.surfaceType == RealtimeSurfaceType.meeting
          ? 'Your request was sent. Waiting for the host.'
          : 'Your join request was sent. Waiting for approval.';
    }
    return AppErrorMapper.from(
      error,
      feature: state.session?.surfaceType == RealtimeSurfaceType.meeting
          ? 'join this meeting'
          : 'join this call',
    ).message;
  }

  bool managesCorrespondenceSurface({
    required String threadId,
    String? spaceId,
  }) {
    final session = state.session;
    if (session == null) return false;
    final surfaceType = session.surfaceType.name.trim().toLowerCase();
    final surfaceId = (session.surfaceId ?? '').trim();
    final normalizedThreadId = threadId.trim();
    final normalizedSpaceId = (spaceId ?? '').trim();

    if (surfaceType == 'dm' || surfaceType == 'thread') {
      return normalizedThreadId.isNotEmpty && surfaceId == normalizedThreadId;
    }

    if (surfaceType == 'space') {
      if (normalizedSpaceId.isNotEmpty && surfaceId == normalizedSpaceId) {
        return true;
      }
    }

    return false;
  }

  String? activeSessionIdForCorrespondence({
    required String threadId,
    String? spaceId,
  }) {
    if (!managesCorrespondenceSurface(threadId: threadId, spaceId: spaceId)) {
      return null;
    }
    final value = _managedSessionId;
    return value.isEmpty ? null : value;
  }

  Future<void> _forceNegotiationIfNeeded() async {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty) return;
    if (!state.isJoined) return;
    if (!state.isMediaReady) return;

    final meSocketId = _socketService.socketId;
    if (meSocketId == null || meSocketId.isEmpty) return;

    // runtimeDeviceId can arrive either as the bare socket id ("XXX") or as
    // "socket:XXX" depending on which payload populated it, while
    // _socketService.socketId is always the bare id. Compare on the RAW id so
    // the deterministic-initiator decision is consistent on both peers —
    // comparing mixed formats made BOTH sides skip and wait forever.
    String rawSock(String s) =>
        s.startsWith('socket:') ? s.substring('socket:'.length) : s;
    final myRaw = rawSock(meSocketId);

    for (final participant in state.participants) {
      final peerSocketId = participant.runtimeDeviceId?.trim() ?? '';
      if (peerSocketId.isEmpty) continue;
      final peerRaw = rawSock(peerSocketId);
      if (peerRaw.isEmpty || peerRaw == myRaw) continue;

      // GLARE AVOIDANCE (deterministic initiator). Both peers run this method,
      // so without arbitration both createOffer + setLocalDescription at once;
      // the incoming offer then arrives in `have-local-offer` state, the
      // negotiation collides, the RTCPeerConnection goes to `failed`, and
      // onConnectionState → removePeer → reconnect. Only ONE side offers: the
      // peer with the higher RAW socket id initiates; the lower waits for the
      // offer and answers (the session:offer handler is unconditional).
      final iInitiate = myRaw.compareTo(peerRaw) > 0;
      debugPrint(
        '[rtc-init] peer=$peerRaw me=$myRaw iInitiate=$iInitiate'
        ' mediaReady=${state.isMediaReady}',
      );
      if (!iInitiate) continue;

      final peerKey = peerSocketId;

      if (_pendingOfferTargets.containsKey(peerKey)) continue;

      _queueOfferTarget(peerKey: peerKey, targetSocketId: peerSocketId);
    }

    if (_pendingOfferTargets.isNotEmpty) {
      await _flushPendingOffers();
    }
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _subscription?.cancel();
    _mediaSubscription?.cancel();
    _mediaService.dispose();
    _socketService.dispose();
    super.dispose();
  }
}
