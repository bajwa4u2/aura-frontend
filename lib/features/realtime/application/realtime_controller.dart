import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/client_identity/client_identity.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/realtime/meeting_realtime_semantics.dart';
import '../data/realtime_event_parser.dart';
import '../data/realtime_media_service.dart';
import '../data/realtime_repository.dart';
import '../data/sfu_realtime_transport.dart';
import '../data/realtime_socket_service.dart';
import '../domain/realtime_enums.dart';
import '../domain/realtime_models.dart';
import '../domain/call_mode.dart';
import '../domain/call_state.dart';
import '../domain/realtime_state.dart';
import '../../../core/diagnostics/call_teardown_diag.dart';
import '../../../core/notifications/android_telecom.dart';
import '../../../core/notifications/ios_call_kit.dart';

/// THE BACKEND WOULD NOT SAY HOW THIS CALL MAY CONNECT.
///
/// Raised when the transport-configuration request fails, and never for a
/// device, permission or negotiation problem. Those are different failures
/// with different answers: a microphone problem is this person's to fix, and
/// this one is not.
///
/// It exists as a TYPE rather than a message, because the only honest response
/// to it is a policy decision — fail the call visibly — and a policy must not
/// hinge on server wording that nobody promised to keep stable.
class TransportConfigurationUnavailable implements Exception {
  const TransportConfigurationUnavailable(this.cause);

  /// The underlying failure, kept for logs and never shown to a person.
  final Object cause;

  @override
  String toString() => 'TransportConfigurationUnavailable: $cause';
}

class RealtimeController extends StateNotifier<RealtimeState>
    with WidgetsBindingObserver {
  RealtimeController(
    this._repository,
    this._socketService,
    this._mediaService,
    this._tokenStore,
    this._readClientIdentity, {
    Future<String> Function()? readMyUserId,
  }) : _readMyUserId = readMyUserId,
       super(RealtimeState.initial()) {
    _subscription = _socketService.events.listen(_handleSocketEvent);
    _mediaSubscription = _mediaService.snapshots.listen(_handleMediaSnapshot);
    _peerHealthSubscription =
        _mediaService.peerHealthEvents.listen(_handlePeerHealth);
    // Browser/app lifecycle: on resume, verify the socket AND every peer
    // transport — a laptop waking from sleep can hold a live socket over
    // dead ICE, which previously looked "connected" with frozen tiles.
    WidgetsBinding.instance.addObserver(this);
  }

  final RealtimeRepository _repository;
  final RealtimeSocketService _socketService;
  final RealtimeMediaService _mediaService;
  final TokenStore _tokenStore;

  /// GO LIVE viewer path (task #172): resolves the signed-in user id so
  /// media capture can distinguish the broadcaster (publishes) from a
  /// PUBLIC_STAGE viewer (receive-only). Null in tests that don't care.
  final Future<String> Function()? _readMyUserId;
  // Awaits the client identity FutureProvider so the realtime handshake
  // always carries identity headers even on a very-early reconnect (e.g.
  // immediately after sign-in before any HTTP request has run). Resolves
  // synchronously from cache after the first successful read.
  final Future<ClientIdentity?> Function() _readClientIdentity;

  StreamSubscription<RealtimeParsedEvent>? _subscription;
  StreamSubscription<RealtimeMediaSnapshot>? _mediaSubscription;
  StreamSubscription<RealtimePeerHealthEvent>? _peerHealthSubscription;

  String? _hydratingSessionId;
  String? _joiningSessionId;
  bool _terminating = false;
  bool _endingCall = false;

  // 2026-08-14 — permanent fix for a proven race: Future.timeout() does NOT
  // cancel the timed-out Future, it only stops awaiting it. When a single
  // _performJoin() attempt ran past the per-attempt timeout (slow ICE/media
  // on real networks, not a failed join — the authoritative joinState=joined
  // transition happens BEFORE that slow tail), _performJoinWithRetry started
  // a second, fully concurrent _performJoin() for the same session while the
  // first was still alive in the background. Both could mutate `state`
  // independently; live device logs captured three `session:join` emissions
  // for one session within 6 seconds. If the superseded attempt's late
  // success or the retry's spurious "already joined" failure landed last, it
  // could overwrite a genuinely successful join with an error state — the
  // proven cause of the call connecting cleanly while a Retry/Dismiss error
  // banner still appeared. `_joinEpoch` makes every attempt identify itself;
  // an attempt whose epoch has been superseded by a newer one silently
  // no-ops instead of mutating shared state.
  int _joinEpoch = 0;

  // ── Media-continuity grace windows ──────────────────────────────────────
  // The media plane no longer dies with the signaling socket. A socket drop
  // starts the signaling grace; the media plane is only torn down if the
  // rejoin does not land inside it. A peer's involuntary departure starts a
  // per-peer grace; their tile shows "Reconnecting…" and only leaves for real
  // when the window expires.
  Timer? _signalingGraceTimer;
  /// THE CLIENT MUST NOT ABANDON A SESSION THE SERVER STILL HOLDS.
  ///
  /// This was 45s while the server revokes a silent participant at 60s, so a
  /// client destroyed its own resume state FIFTEEN SECONDS BEFORE the call it
  /// was trying to rejoin actually expired. On expiry this grace calls
  /// `resetSessionMedia()` and clears session context -- which takes
  /// `_resumeSessionId` with it, and that is precisely what the automatic
  /// rejoin on `socket:connected` needs. The recovery mechanism disarmed
  /// itself, which is why a returning network did not restore the call and
  /// the founder had to rejoin by hand through the thread banner
  /// (2026-08-28).
  ///
  /// The ordering has to be: the client keeps hoping slightly LONGER than the
  /// server does, never shorter. Then a socket that returns inside the
  /// server's window still finds a session to rejoin, and if the server HAS
  /// revoked, the rejoin fails cleanly through `_mapJoinError` and says so --
  /// an honest failure after asking, rather than a silent teardown that never
  /// asked.
  ///
  /// Raised 45 -> 75 -> 135 as the server's tolerance went 60 -> 120. These
  /// two numbers move together or the defect returns; the client must outlast
  /// the server, never the reverse.
  ///
  /// This is deliberately NOT the same number as the UI patience budget.
  /// What we SHOW and what we DESTROY are different questions: after 45s we
  /// stop promising the person it will come back, but we keep the session
  /// recoverable until the server itself has let go.
  static const Duration _signalingGrace = Duration(seconds: 135);
  final Map<String, Timer> _peerGraceTimers = <String, Timer>{};
  static const Duration _peerGrace = Duration(seconds: 45);
  // userId → last known live socketId, so a rejoining peer's stale peer
  // connection can be replaced precisely.
  final Map<String, String> _peerSocketByUserId = <String, String>{};

  // Quality evidence: sampled every 5s while joined, attached to heartbeats.
  Timer? _statsTimer;
  static const Duration _statsInterval = Duration(seconds: 5);
  RealtimeQualitySample? _lastQualitySample;

  // TURN credential rotation: refreshed at ~80% of the issued TTL so an ICE
  // restart late in a long meeting never runs on expired relay credentials.
  Timer? _turnRefreshTimer;
  int _turnTtlSeconds = 3600;

  /// Client-side heartbeat ticker fires `session:heartbeat` while joined.
  /// 10s (was 20s): with the backend stale window widened to 60s, this gives
  /// ~6× margin, so a single skipped beat — during the join/renegotiation
  /// churn that flips joinState off `joined` for a tick, or a mobile timer
  /// throttle — no longer lets a live GUEST cross the stale threshold and get
  /// reaped every ~30s (the guest reconnect loop). The immediate first beat in
  /// _startHeartbeat plus this cadence keep presence fresh through churn.
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 10);

  Map<String, dynamic>? _rtcConfiguration;
  String? _rtcConfigurationSessionId;
  final Map<String, String> _pendingOfferTargets = <String, String>{};
  bool _flushingPendingOffers = false;

  // Reconnect resilience. The session to silently rejoin if the socket drops
  // while the user is still in the room (backgrounded desktop tab, mobile
  // app-switch/resume, transient network). Cleared ONLY on an intentional
  // leave/terminate — never on a socket disconnect.
  String? _resumeSessionId;
  bool _awaitingReconnectRejoin = false;

  /// Consecutive fully-exhausted join cycles (each = 3 attempts inside
  /// _performJoinWithRetry). BOUNDED FAILURE SEMANTICS (founder directive
  /// 2026-08-17 §4): after [_maxSilentTransportCycles] cycles the UI must
  /// tell the truth — the real reason, a Retry affordance — instead of an
  /// endless "Connecting…" spinner. Auto-recovery stays armed regardless.
  int _transportFailureStreak = 0;
  // 0 = truth after the FIRST exhausted cycle. A cycle is already three
  // real attempts with backoff (~up to 45s of genuine trying) — hiding the
  // reason behind further silent cycles only recreates the endless
  // spinner the founder rejected. join() is invoked once per screen
  // visit, so a higher threshold may never be reached at all.
  static const int _maxSilentTransportCycles = 0;

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
      reconnectingUserIds: const <String>{},
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
      acceptedByPeer: clearSessionContext ? false : state.acceptedByPeer,
      speakerphoneEnabled: clearSessionContext ? false : state.speakerphoneEnabled,
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

  /// Backfill an existing peer's live [socketId] onto its roster participant,
  /// matched by [userId]. A NEWCOMER learns existing peers via the hydrate
  /// roster, which carries no live socketId — so the peer's video renderer
  /// (keyed by the socket) can't be mapped to a named participant (badge
  /// mapped=0/1, tile shows no identity). The offer/answer relay DOES carry the
  /// sender's userId + socketId, so when we receive one we stamp the socket
  /// onto the matching participant → the renderer key now maps to the roster
  /// entry (mapped=1/1, the host's name/avatar appears on the tile).
  void _backfillPeerSocket(String userId, String socketId) {
    if (userId.isEmpty || socketId.isEmpty) return;
    var changed = false;
    final updated = state.participants.map((p) {
      if (p.userId == userId && (p.runtimeDeviceId ?? '').trim() != socketId) {
        changed = true;
        return p.copyWith(runtimeDeviceId: socketId);
      }
      return p;
    }).toList();
    if (changed) {
      state = state.copyWith(participants: updated);
    }
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

      // Proceed even when local media could not be acquired (permission
      // denied, devices busy): a recvonly connection still lets this
      // participant SEE and HEAR the room. Requiring isMediaReady stalled
      // every queued offer forever for exactly the users who most needed
      // the connection to succeed.
      if (state.isMediaBusy) return;

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
          // Same distinction as in _ensureMediaReady: a failure to obtain
          // authorised configuration is a failed CONNECTION, not a stray error
          // string on a room that is otherwise fine.
          if (error is TransportConfigurationUnavailable) {
            state = state.copyWith(
              connectionFailure: CallConnectionFailure.transportUnavailable,
            );
            return;
          }
          state = state.copyWith(errorMessage: error.toString());
        }
      }
    } finally {
      _flushingPendingOffers = false;
    }
  }

  // 2026-08-14 — PERMANENT TRANSPORT OWNERSHIP REPAIR. This used to guard
  // itself with `state.connectionStatus == connecting`, a SEPARATE signal
  // from RealtimeSocketService's own internal connect-guard — the two
  // could desync (e.g. this state stuck at `connecting` from an abandoned
  // attempt) and, combined with Future.timeout() not cancelling abandoned
  // attempts, let multiple concurrent callers each reach past this guard
  // and independently call the socket service's connect, which always
  // disconnected/recreated the transport. `RealtimeSocketService
  // .ensureConnected()` is now the SOLE, single-flight owner of connection
  // establishment — this method is a thin pass-through with no gating
  // logic of its own; concurrent callers safely share one establishment
  // underneath instead of racing.
  Future<void> connect() async {
    debugPrint(
      '[transport-diag] RealtimeController.connect() called,'
      ' socketServiceIsConnected=${_socketService.isConnected}'
      ' socketId=${_socketService.socketId}',
    );
    if (_socketService.isConnected) {
      _clearTrouble();
      if (state.connectionStatus != RealtimeConnectionStatus.connected) {
        state = state.copyWith(connectionStatus: RealtimeConnectionStatus.connected);
      }
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

      await _socketService.ensureConnected(
        accessToken: token,
        identity: identity,
      );

      _clearTrouble();
      state = state.copyWith(
        connectionStatus: RealtimeConnectionStatus.connected,
        infoMessage: 'Live connection ready.',
      );
    } catch (error) {
      final status = _troubleStatus();
      final reconnecting = status == RealtimeConnectionStatus.reconnecting;
      // `copyWith` KEEPS a field when passed null -- it is
      // `errorMessage ?? this.errorMessage`. Clearing requires the explicit
      // flag, so passing null here would have left a stale error sitting
      // under "Reconnecting…" rather than removing it.
      state = state.copyWith(
        connectionStatus: status,
        clearErrorMessage: reconnecting,
        errorMessage: reconnecting ? null : error.toString(),
        clearInfoMessage: !reconnecting,
        infoMessage: reconnecting ? 'Reconnecting…' : null,
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
      await _reconcileRtcPeers('hydrate');
      final normalizedKind = kind.trim().toLowerCase();
      state = state.copyWith(
        isBusy: false,
        sessionId: bundle.session.id,
        joinState: RealtimeJoinState.idle,
        // One authority for this question. This line used to read
        // `normalizedKind == 'video' ? 'video' : 'audio'`, which sent MIXED —
        // how meetings are created — to audio.
        callMode: callModeForSessionKind(normalizedKind, fallback: 'audio'),
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
      await _reconcileRtcPeers('hydrate-live');
      state = state.copyWith(
        isBusy: false,
        infoMessage: state.isJoined ? state.infoMessage : 'Live loaded.',
      );
      // Pre-join session-end truth, controller half (founder evidence
      // 2026-08-17: a dead session's "Ready to join" surface squatted
      // over /messages indefinitely). A TERMINAL session hydrated while
      // NOT joined must not keep pinning call UI anywhere: one frame is
      // granted so a mounted room screen can run its own ended-session
      // navigation off the hydrated state, then the session context is
      // cleared entirely — no stale sessionId left to resurrect a call
      // surface over any route.
      final hydrated = state.session;
      if (hydrated != null && !hydrated.isActive && !state.isJoined) {
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 600)).then((_) {
            final current = state;
            final stillSame =
                (current.sessionId ?? current.session?.id ?? '').trim() ==
                trimmed;
            final stillTerminal = current.session?.isActive == false;
            if (stillSame && stillTerminal && !current.isJoined) {
              debugPrint(
                '[ended-diag] hydrate found terminal session sessionId=$trimmed '
                'status=${current.session?.status}',
              );
              state = current.copyWith(
                clearSession: true,
                clearSessionId: true,
                clearPolicy: true,
                infoMessage: 'This call has ended.',
              );
            }
          }),
        );
      }
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
    debugPrint(
      '[join-diag] join() called sessionId=$trimmed'
      ' terminating=$_terminating joiningSessionId=$_joiningSessionId'
      ' joinState=${state.joinState} stateSessionId=${state.sessionId}',
    );
    if (trimmed.isEmpty || _terminating) {
      debugPrint('[join-diag] early-return: empty id or terminating');
      return;
    }

    final currentSessionId = (state.sessionId ?? state.session?.id ?? '')
        .trim();
    if (_joiningSessionId == trimmed) {
      debugPrint('[join-diag] early-return: _joiningSessionId already = $trimmed (stale guard candidate)');
      return;
    }
    if (state.joinState == RealtimeJoinState.joined &&
        _isSameManagedSession(trimmed)) {
      debugPrint('[join-diag] early-return: already joined this session');
      return;
    }
    if (state.joinState == RealtimeJoinState.joining &&
        _isSameManagedSession(trimmed)) {
      debugPrint('[join-diag] early-return: already joining this session (stale guard candidate)');
      return;
    }

    if (currentSessionId.isNotEmpty &&
        currentSessionId != trimmed &&
        state.isJoined) {
      await leave();
    }

    _joiningSessionId = trimmed;
    _resumeSessionId = trimmed;
    _clearRtcConfiguration();

    // Show "Connecting..." immediately — the user should see progress even
    // while the socket is being established (deeplink, cold page load, etc.).
    // A fresh join always starts without a prior session's stale ACCEPT
    // truth attached.
    state = state.copyWith(
      joinState: RealtimeJoinState.joining,
      sessionId: trimmed,
      clearErrorMessage: true,
      clearInfoMessage: true,
      acceptedByPeer: false,
    );

    try {
      // No standalone connect() call here — _performJoin's own connect()
      // call (delegating to RealtimeSocketService.ensureConnected(),
      // single-flight) is the sole transport-establishment owner for the
      // whole join sequence. A second, independent pre-check here used to
      // exist; removed as part of the transport-ownership repair — see
      // RealtimeSocketService for why having more than one caller decide
      // to (re)connect was the actual root defect.
      await _performJoinWithRetry(trimmed);
      _transportFailureStreak = 0;
    } catch (error) {
      if (_terminating) return;

      // Retryable connection errors (socket drop, timeout, network) must NOT
      // put the user into a fatal "failed" state. Keep joinState=joining and
      // show a soft "Connecting…" message so the UI remains actionable.
      //
      // 2026-08-14 — proven-stuck-spinner fix. The comment above originally
      // said "the user can tap Join again when connectivity recovers", but
      // the accept flow (AuraIncomingLiveLayer._joinCurrent) navigates
      // straight to the room screen on ANY non-throwing join() outcome —
      // there is no "Join" button left to tap. The room screen's own mount
      // logic only calls hydrateSession() (a REST refetch) when not already
      // joined, never re-attempts the socket join. Confirmed via live device
      // logs: three real _performJoinWithRetry attempts, all failing fast
      // with an empty socket id, after which nothing ever tried again —
      // joinState stayed `joining` and connectionStatus stayed
      // `reconnecting` forever, an unrecoverable stuck spinner. The
      // 'socket:connected' handler below already has an automatic-rejoin
      // mechanism (_rejoinAfterReconnect via _awaitingReconnectRejoin) built
      // for exactly this situation — it was just never armed for a join
      // that never succeeded in the first place (only for a join that
      // succeeded and then lost its socket). Arming it here means that
      // if/when the socket eventually reconnects on its own — including
      // Socket.IO's own built-in retry — the existing mechanism completes
      // the join automatically instead of leaving the user stranded.
      if (_isRetryableConnectionError(error)) {
        _awaitingReconnectRejoin = true;
        _transportFailureStreak++;
        if (_transportFailureStreak <= _maxSilentTransportCycles) {
          state = state.copyWith(
            connectionStatus: RealtimeConnectionStatus.reconnecting,
            infoMessage: 'Connecting…',
            clearErrorMessage: true,
          );
        } else {
          // Truth over hope: repeated full retry cycles have failed. Show
          // the REAL reason and a usable retry state; keep auto-rejoin
          // armed so a recovered socket still completes the join.
          // The RAW transport error is shown deliberately: this branch only
          // carries connection-establishment failures (timeouts, socket
          // exceptions) — never business data — and the exact reason is
          // what makes the state truthful and diagnosable.
          final reason = error.toString().replaceFirst('Exception: ', '');
          // The streak counts ATTEMPTS; the budget counts TIME, and the
          // server revokes on time. A streak exhausted inside the budget is
          // still a call worth waiting for, so the shared budget has the
          // final word on what the person is shown.
          // A RECONNECTING CALL IS NOT AN ERROR, AND MUST NOT READ LIKE ONE.
          // The raw transport reason is deliberately truthful when the call
          // has genuinely failed, but showing it WHILE still reconnecting put
          // a DioException string on screen beside "Reconnecting…" -- founder,
          // 2026-08-28: "raw message in pixel was too odd and uggly beside
          // reconnecting". Truth is owed when there is bad news; during a
          // recovery that may still succeed, the honest state is simply that
          // we are trying.
          final status = _troubleStatus();
          final reconnecting = status == RealtimeConnectionStatus.reconnecting;
          state = state.copyWith(
            connectionStatus: status,
            joinState: RealtimeJoinState.idle,
            clearInfoMessage: !reconnecting,
            infoMessage: reconnecting ? 'Reconnecting…' : null,
            clearErrorMessage: reconnecting,
            errorMessage: reconnecting
                ? null
                : 'Live connection could not be established. ($reason)',
          );
        }
        return; // Do not rethrow — 'socket:connected' will retry.
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

  /// Silent rejoin after an involuntary socket drop while the user stayed in
  /// the room. Unlike join(), it does NOT early-return when joinState is still
  /// `joined` (it is, by design, so the room UI persists through the gap). It
  /// re-runs the full join (rehydrate → socket session:join → media → heartbeat
  /// → renegotiation). On a retryable failure it stays in the reconnecting
  /// state and re-arms for the next 'socket:connected'.
  Future<void> _rejoinAfterReconnect(String sessionId) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty || _terminating) return;
    _joiningSessionId = trimmed;
    _clearRtcConfiguration();
    state = state.copyWith(
      joinState: RealtimeJoinState.joining,
      sessionId: trimmed,
      connectionStatus: RealtimeConnectionStatus.reconnecting,
      infoMessage: 'Reconnecting…',
      clearErrorMessage: true,
    );
    try {
      // A SOCKET THAT DIED CANNOT VOUCH FOR THE MEDIA TRANSPORT BESIDE IT.
      //
      // THE DEFECT THIS CLOSES (measured 2026-08-29, wifi pulled on a phone).
      // The rejoin restored the session perfectly -- no heartbeat_timeout, the
      // participant stayed ACTIVE, the client came back unattended in 16s --
      // and the media never returned. The transport table said why: after
      // three rejoins the phone still had ONE transport, the original one from
      // before the outage, still marked OPEN and pointing at a Cloudflare
      // session that had died with the network. The other participant went on
      // subscribing to its tracks and collecting 404s and 410s forever.
      //
      // The cause is `usesStageTransport`, which is `_stage != null` --
      // PRESENCE, NOT HEALTH. `_ensureStageConnected` saw a non-null stage and
      // took the refresh path, so the dead transport was never replaced. It is
      // the same mistake as the recovery guard that asked whether a stage
      // existed rather than whether it was still THE one, and it produced the
      // worse half of the same outcome: session recovery that leaves the media
      // plane dead.
      //
      // Detaching first costs a re-open on a transport that might have
      // survived. Keeping a dead one costs the call.
      await _mediaService.detachStage();
      // No standalone connect() call here — _performJoin's own connect()
      // (delegating to RealtimeSocketService.ensureConnected(), single-
      // flight) is the sole transport-establishment owner. A second call
      // here would be redundant now, not harmful, but this repair's whole
      // point is exactly one owner per concern.
      await _performJoinWithRetry(trimmed);
      _transportFailureStreak = 0;
    } catch (error) {
      if (_terminating) return;
      if (_isRetryableConnectionError(error)) {
        _awaitingReconnectRejoin = true; // retry on next connect
        _transportFailureStreak++;
        if (_transportFailureStreak <= _maxSilentTransportCycles) {
          state = state.copyWith(
            connectionStatus: RealtimeConnectionStatus.reconnecting,
            infoMessage: 'Reconnecting…',
            clearErrorMessage: true,
          );
        } else {
          // Same bounded-truth semantics as join(): a rejoin loop must not
          // hide the establishment reason behind an endless banner either.
          final reason = error.toString().replaceFirst('Exception: ', '');
          // The streak counts ATTEMPTS; the budget counts TIME, and the
          // server revokes on time. A streak exhausted inside the budget is
          // still a call worth waiting for, so the shared budget has the
          // final word on what the person is shown.
          // A RECONNECTING CALL IS NOT AN ERROR, AND MUST NOT READ LIKE ONE.
          // The raw transport reason is deliberately truthful when the call
          // has genuinely failed, but showing it WHILE still reconnecting put
          // a DioException string on screen beside "Reconnecting…" -- founder,
          // 2026-08-28: "raw message in pixel was too odd and uggly beside
          // reconnecting". Truth is owed when there is bad news; during a
          // recovery that may still succeed, the honest state is simply that
          // we are trying.
          final status = _troubleStatus();
          final reconnecting = status == RealtimeConnectionStatus.reconnecting;
          state = state.copyWith(
            connectionStatus: status,
            joinState: RealtimeJoinState.idle,
            clearInfoMessage: !reconnecting,
            infoMessage: reconnecting ? 'Reconnecting…' : null,
            clearErrorMessage: reconnecting,
            errorMessage: reconnecting
                ? null
                : 'Live connection could not be re-established. ($reason)',
          );
        }
        return;
      }
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

      // A prior attempt's timeout raced with its own slow-but-successful
      // completion — by the time we're deciding whether to retry, the
      // authoritative joinState=joined transition (set BEFORE the slow
      // media/negotiation tail in _performJoin) may have already landed in
      // the background. Treat that as success instead of starting a
      // redundant, concurrent second attempt against an already-joined
      // session.
      if (state.isJoined && _isSameManagedSession(sessionId)) {
        return;
      }

      final myEpoch = ++_joinEpoch;
      try {
        await _performJoin(sessionId, myEpoch).timeout(perAttemptTimeout);
        return;
      } catch (error, stack) {
        if (myEpoch != _joinEpoch) {
          // This attempt was already superseded before it failed. A newer
          // attempt is responsible for the outcome now — don't let a stale
          // attempt's error bubble up and clobber a possibly-successful
          // newer one.
          return;
        }
        lastError = error;
        lastStack = stack;
        // ignore: avoid_print
        print('[rtc-diag] join attempt ${attempt + 1} failed: $error');

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
        //
        // 2026-08-14 — REMOVED the pre-retry "if not connected, reconnect"
        // step that used to live here. It was a SECOND, independent owner
        // of transport reconnection, racing against _performJoin's own
        // connect() call at the top of the next attempt — proven (live
        // device + backend log correlation) to tear down a sibling
        // attempt's in-progress socket before it could stabilize. The next
        // attempt's own `await connect()` inside _performJoin now goes
        // through RealtimeSocketService.ensureConnected(), which is
        // single-flight — it is the only place transport is established,
        // so there is nothing left for this loop to do here beyond
        // backing off before starting that next attempt.
        final base = baseDelays[attempt].inMilliseconds;
        final jittered = (base * (0.5 + rng.nextDouble())).round();
        await Future<void>.delayed(Duration(milliseconds: jittered));
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

  Future<void> _performJoin(String sessionId, int epoch) async {
    // ignore: avoid_print
    print('[rtc-diag] performJoin start session=$sessionId');
    await hydrateSession(sessionId);
    // ignore: avoid_print
    print('[rtc-diag] hydrated surface=${state.session?.surfaceType.name}'
        ' active=${state.session?.isActive}');

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

    // A newer attempt has started since this one began (this attempt ran
    // past its per-attempt timeout in _performJoinWithRetry, which does not
    // cancel it — it keeps running in the background). Stop before touching
    // shared state; the newer attempt owns the outcome now.
    if (epoch != _joinEpoch) return;

    final isMeetingSession = session.surfaceType == RealtimeSurfaceType.meeting;
    if (isMeetingSession) {
      state = state.copyWith(
        joinState: RealtimeJoinState.joined,
        clearIncomingCall: true,
        infoMessage: 'Waiting for guest to join.',
        clearErrorMessage: true,
      );
    }

    if (MeetingRealtimeSemantics.tolerateRestJoinFailure(session.surfaceType)) {
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

    // Superseded during the REST joinSession call above (which can be
    // slow)? Stop before touching transport — a newer attempt owns this
    // session now, and ensureConnected() below is single-flight-shared, so
    // proceeding here would be wasted work at best, not harmful, but there
    // is no reason to continue past this point once superseded.
    if (epoch != _joinEpoch) return;

    await connect();
    final meSocketId = _socketService.socketId ?? '';
    debugPrint(
      '[join-seq] 1 socket connected socketId=$meSocketId'
      ' sessionId=$sessionId isMeeting=$isMeetingSession',
    );

    // Transport readiness can only be declared by RealtimeSocketService
    // itself (isConnected requires connected AND a non-empty server-
    // assigned id — see that class for the proven race this closes). This
    // is the last checkpoint before the one event that must never fire
    // from a superseded attempt: a stale attempt emitting session:join
    // after a newer attempt has already taken over this session's join
    // state would create a second, unnecessary server-side registration.
    if (epoch != _joinEpoch) return;
    if (!_socketService.isConnected) {
      throw RealtimeTransportException(
        'Transport not ready after connect() returned — refusing to emit session:join.',
      );
    }

    debugPrint('[join-seq] 2 session join emitted sessionId=$sessionId');
    final Map<String, dynamic> joinAck = await _socketService.emitAck(
      'session:join',
      <String, dynamic>{'sessionId': sessionId},
    );
    debugPrint(
      '[join-seq] 3 session join ack received sessionId=$sessionId'
      ' ack=$joinAck',
    );

    // Same supersession check as above, re-evaluated after the socket round
    // trip: this is the authoritative ACCEPT/CONNECTED transition. Only the
    // current epoch may declare it — a superseded attempt reaching this
    // point late (its own session:join already acked server-side) must not
    // overwrite whatever the newer attempt has since done, and must not
    // start a second heartbeat/media/stats cycle.
    if (epoch != _joinEpoch) return;

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
      await _reconcileRtcPeers('join', refreshTurnCredentials: true);
      debugPrint('[join-seq] 8 media+negotiation complete sessionId=$sessionId');
    } catch (e, st) {
      debugPrint(
        '[join-seq] media/negotiation NON-FATAL error sessionId=$sessionId'
        ' err=$e\n$st',
      );
    }

    // Reliability services for the life of the room: quality sampling (feeds
    // adaptation + heartbeat evidence), TURN credential rotation, and the
    // mesh-aware bitrate cap.
    _startStatsTimer();
    _scheduleTurnRefresh();
    unawaited(
      _mediaService.applyParticipantScaling(state.participants.length),
    );
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
      _startStatsTimer();
      _scheduleTurnRefresh();
      await _reconcileRtcPeers('resume', refreshTurnCredentials: true);
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
    // One call, one report. Leaving retires the latch so the next call
    // reports its own media rather than inheriting this one's.
    _reportedMediaEstablished = false;
    if (_terminating) return;
    final sessionId = (state.sessionId ?? '').trim();
    if (sessionId.isEmpty) return;

    CallDiag.emit('call.leave', 'begin', data: {'session': sessionId});
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
    _resumeSessionId = null;
    _awaitingReconnectRejoin = false;
    _stopStatsTimer();
    _cancelTurnRefresh();
    _cancelSignalingGrace();
    for (final timer in _peerGraceTimers.values) {
      timer.cancel();
    }
    _peerGraceTimers.clear();
    _peerSocketByUserId.clear();
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

    CallDiag.emit('call.end', 'begin',
        data: {'session': _managedSessionId});
    final sessionId = _managedSessionId;
    final session = state.session;
    if (sessionId.isEmpty && session == null) {
      debugPrint('[ended-diag] endCall: no session context');
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
        debugPrint('[ended-diag] endCall: local teardown after host end');
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
    // but the next tick recovers. The server ignores heartbeats from
    // non-joined sockets, so the ticker is safe to keep running. The latest
    // quality sample rides along so the backend's meeting record holds real
    // evidence (rtt / jitter / loss / bitrate), not nulls.
    final quality = _lastQualitySample;
    unawaited(
      _socketService
          .emitAck('session:heartbeat', <String, dynamic>{
            'sessionId': sessionId,
            if (quality != null && quality.hasAny) ...<String, dynamic>{
              if (quality.packetLossPct != null)
                'packetLoss': quality.packetLossPct,
              if (quality.jitterMs != null) 'jitter': quality.jitterMs,
              if (quality.bitrateKbps != null)
                'bitrateKbps': quality.bitrateKbps,
              if (quality.rttMs != null) 'rtt': quality.rttMs,
              // The path the media ACTUALLY took. Omitted when the platform
              // does not expose it, so the session keeps UNKNOWN rather than
              // recording a guess.
              if (quality.selectedCandidateType != null)
                'selectedCandidateType': quality.selectedCandidateType,
              if (quality.transportProtocol != null)
                'transportProtocol': quality.transportProtocol,
              if (quality.networkType != null)
                'networkType': quality.networkType,
            },
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

    final requested = !state.cameraEnabled;

    // PUBLISH WHAT HAPPENED, NOT WHAT WAS ASKED FOR.
    //
    // This used to send `requested` to the session and patch the local
    // track with it, discarding whether the camera actually came on.
    // When acquisition had failed there was nothing to enable, and the
    // session was still told the camera was publishing: founder-observed
    // 2026-08-28, five VIDEO_STATE_CHANGED publishState=ON events with
    // zero outbound video RTP and a black self-view on the publisher.
    // Both the far side and the publisher were told video was on, and
    // neither was told the camera had never opened.
    final result = await _mediaService.setCameraEnabled(requested);
    final enabled = result.enabled;

    await _socketService.emitAck('session:video.set', <String, dynamic>{
      'sessionId': sessionId,
      'enabled': enabled,
    });
    _patchMyTrack(videoOn: enabled);

    // A re-acquired camera on a peer that never had a video sender changes
    // the m-lines, so it needs a re-offer — same contract as screen share.
    if (result.needsRenegotiation) {
      await _renegotiateExistingPeers();
    }

    // Asking for the camera and not getting it is a fact the person is
    // entitled to, rather than a silent no-op they retry forever.
    if (requested && !enabled) {
      state = state.copyWith(
        infoMessage:
            'Your camera could not be started. Close any other app or browser tab using it, then try again.',
        clearErrorMessage: true,
      );
    }
  }

  /// Thread/DM speaker toggle (2026-08-14 repair). Local-only device
  /// routing — no signaling event, matching how Meetings' existing device
  /// picker calls `setAudioOutput` directly with no socket round-trip.
  /// Resolved fresh per call: `RealtimeMediaService` never persists this
  /// beyond the current session.
  Future<void> toggleSpeakerphone() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    await _mediaService.setSpeakerphoneEnabled(!state.speakerphoneEnabled);
  }

  /// I1: Start broadcasting the local screen. Replaces the video track on
  /// peers that carry one; on audio-only peers the track is ADDED, which
  /// requires renegotiation — handled here so screen share works in audio
  /// meetings too.
  Future<void> startScreenShare() async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    final needsRenegotiation = await _mediaService.startScreenShare();

    unawaited(
      _socketService
          .emitAck('session:screen.set', <String, dynamic>{
            'sessionId': sessionId,
            'enabled': true,
          })
          .catchError((Object _) => <String, dynamic>{}),
    );

    if (needsRenegotiation) {
      await _renegotiateExistingPeers();
    }
  }

  /// Renegotiate with every peer we already hold a connection to (track
  /// added/removed). Fresh offers on EXISTING connections — perfect
  /// negotiation resolves any collision.
  Future<void> _renegotiateExistingPeers() async {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty || !state.isJoined) return;
    for (final participant in state.participants) {
      final peerKey = (participant.runtimeDeviceId ?? '').trim();
      if (peerKey.isEmpty || !_mediaService.hasPeer(peerKey)) continue;
      try {
        await _sendOfferToSocket(peerKey: peerKey, targetSocketId: peerKey);
      } catch (error) {
        debugPrint('[rtc] renegotiate failed peerKey=$peerKey err=$error');
      }
    }
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
    final callMode =
        callModeForSessionKind(sessionKind, fallback: state.callMode);

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
    // Intentional teardown — do NOT auto-rejoin.
    _resumeSessionId = null;
    _awaitingReconnectRejoin = false;
    _stopHeartbeat();
    _stopStatsTimer();
    _stageRecoveryReset?.cancel();
    _cancelTurnRefresh();
    _cancelSignalingGrace();
    for (final timer in _peerGraceTimers.values) {
      timer.cancel();
    }
    _peerGraceTimers.clear();
    _peerSocketByUserId.clear();

    final session = state.session;
    final sessionId = _managedSessionId;

    // LEAVING THE CALL IS THE OTHER END OF THE CALL.
    //
    // Every local teardown funnels through here, and until now none of them
    // told CallKit. The system therefore kept the call in its active list
    // after the person had already left, and — with one call group configured
    // — that stale entry refused the NEXT incoming call outright. The phone
    // simply stopped ringing, with nothing logged anywhere.
    //
    // This is the honest counterpart to clearAccepted(): accepting a call must
    // not end it, and ending a call must actually end it. Both are required;
    // build 30 shipped only the first half.
    if (sessionId.isNotEmpty) {
      unawaited(IosCallKit.instance.reportEnded(sessionId, reason: 'ended'));
      // Track C — ending a call must actually end it on both call stacks. A
      // system call left open holds audio focus for a conversation that is
      // over.
      unawaited(AndroidTelecom.instance.reportEnded(sessionId, reason: 'ended'));
    }

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
      // LIVE viewer (founder charter 2026-08-17): receive-only is a
      // ROLE fact, never derived from who started the session — in an
      // escalated call EVERY existing participant keeps publishing; only
      // OBSERVER-role rows (public viewers admitted while the session is
      // in the LIVE lifecycle state) are receive-only: no capture, no
      // permission prompt, no published tracks. Remote media still
      // renders (answering an offer needs no local stream, same as
      // audio-only screen-share peers). The roster is hydrated by the
      // REST join before media setup, so my own row is present here.
      var receiveOnly = false;
      final liveOrStage =
          (state.session?.liveState ?? '') == 'LIVE' ||
          (state.session?.accessMode ?? '') == 'PUBLIC_STAGE';
      if (liveOrStage) {
        final myId = (await (_readMyUserId?.call() ?? Future.value('')))
            .trim();
        if (myId.isNotEmpty) {
          for (final p in state.participants) {
            if (p.userId == myId) {
              receiveOnly = p.role == RealtimeParticipantRole.observer;
              break;
            }
          }
        }
      }

      final wantsAudio = !receiveOnly && (state.policy?.audioAllowed ?? true);
      final wantsVideo =
          !receiveOnly &&
          state.isVideoMode &&
          (state.policy?.videoAllowed ?? true);

      // THE CAMERA AND THE ICE SERVERS HAVE NOTHING TO SAY TO EACH OTHER.
      //
      // These two ran in series: fetch TURN credentials over the network, and
      // only then open the microphone and camera. getUserMedia does not need
      // an ICE server and the credential fetch does not need a track, so the
      // second was simply waiting on the first for no reason.
      //
      // Measured on a real answered call (session cmtf7np66, 2026-08-29): the
      // participant was joined at :18 and the SFU transport did not begin
      // opening until :20 — two seconds in which the call was established and
      // completely silent. Everything downstream inherits that delay, because
      // the stage transport refuses to attach until media is ready:
      //
      //     :18  joined, participants=2, attach-skipped no_local_media
      //     :20  seq=1 OPEN      (1895ms)
      //     :21  seq=2 SUBSCRIBE (waited 1884ms behind OPEN) -> first video
      //
      // Starting capture here lets it run THROUGH the credential fetch and the
      // two intent emits below instead of after them. The role decision is
      // unchanged and still happens first, so an OBSERVER is never prompted
      // for a device it must not open.
      //
      // ensureLocalMedia() already coalesces concurrent callers, so anything
      // else asking for media during the overlap joins this same acquisition
      // rather than starting a competing getUserMedia.
      Future<void>? capture;
      if (!state.isMediaReady && !receiveOnly) {
        capture = _mediaService.ensureLocalMedia(
          audio: wantsAudio,
          video: wantsVideo,
        );
        // If the credential fetch below throws, we never reach the await and
        // an abandoned failure would surface as an unhandled async error.
        // Attaching a handler makes it observed; the real await still rethrows
        // into this method's catch, where it becomes honest mediaError state.
        unawaited(capture.catchError((Object _) {}));
      }

      final configuration = await _resolveRtcConfiguration(
        sessionId,
        refreshTurnCredentials: refreshTurnCredentials,
      );

      // These announce INTENT — what this participant will send — which is
      // already decided above and does not depend on the camera having
      // opened. Emitting them here rather than after the capture await keeps
      // two more server round-trips inside the same overlap.
      await _socketService.emitAck('session:audio.set', <String, dynamic>{
        'sessionId': sessionId,
        'enabled': wantsAudio,
      });
      await _socketService.emitAck('session:video.set', <String, dynamic>{
        'sessionId': sessionId,
        'enabled': wantsVideo,
      });

      if (capture != null) {
        await capture;
        // 2026-08-14 — default output routing, applied once when media
        // first becomes ready (not on every reconnect/renegotiation, so a
        // manual toggle mid-call is never silently overridden). Video
        // calls default to speaker — a video call is normally held away
        // from the ear. Audio calls default to earpiece, matching a
        // normal phone call, with the explicit speaker toggle available
        // to switch. No-ops on web/desktop (no speakerphone concept
        // there — the OS/browser's own output routing is untouched).
        if (wantsVideo) {
          unawaited(_mediaService.setSpeakerphoneEnabled(true));
        }
      }

      state = state.copyWith(
        isMediaBusy: false,
        isMediaReady: true,
        microphoneEnabled: wantsAudio,
        cameraEnabled: wantsVideo,
      );

      _rtcConfiguration = configuration;
      _rtcConfigurationSessionId = sessionId;
    } catch (error) {
      // TRANSPORT CONFIGURATION FAILURE IS NOT A MEDIA FAILURE.
      //
      // Only the backend may say what Aura is permitted to connect with. When
      // it cannot issue that configuration there is nothing for this client to
      // substitute — no retired relay, no client-owned policy, no ungoverned
      // transport. `CLIENT_TRANSPORT_FALLBACK_AUTHORITY = 0`.
      //
      // What it must not do is what it did: catch the failure into a
      // diagnostic string and carry on as though the room were merely quiet.
      // Nothing displayed that string, no peer connection was ever
      // constructed, and both people sat on "Connecting…" indefinitely. An
      // infrastructure failure had become an unexplained silence.
      if (error is TransportConfigurationUnavailable) {
        state = state.copyWith(
          isMediaBusy: false,
          connectionFailure: CallConnectionFailure.transportUnavailable,
          clearInfoMessage: true,
        );
        return;
      }
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

    // No fallback, deliberately. If this throws, the call fails visibly; it
    // does not quietly proceed on a configuration nobody authorised.
    final Map<String, dynamic> issued;
    try {
      issued = await _repository.issueTurnCredentials(sessionId);
    } catch (error) {
      // Typed, so every caller can tell "Aura is not permitted to connect
      // right now" apart from "this device's microphone failed" — which need
      // opposite answers and must never share one catch. A flag would go
      // stale; the type travels with the failure it describes.
      throw TransportConfigurationUnavailable(error);
    }
    final rawIceServers = issued['iceServers'];
    final configuration = <String, dynamic>{
      'iceServers': rawIceServers is List ? rawIceServers : const <dynamic>[],
      'sdpSemantics': 'unified-plan',
    };

    final rawTtl = issued['ttlSeconds'];
    final ttl = rawTtl is num ? rawTtl.toInt() : int.tryParse('$rawTtl') ?? 0;
    if (ttl > 0) _turnTtlSeconds = ttl;

    _rtcConfiguration = configuration;
    _rtcConfigurationSessionId = sessionId;
    return configuration;
  }

  // ── TURN credential rotation ─────────────────────────────────────────────

  void _scheduleTurnRefresh() {
    _turnRefreshTimer?.cancel();
    final seconds = (_turnTtlSeconds * 0.8).round().clamp(60, 24 * 3600);
    _turnRefreshTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_refreshTurnCredentials());
    });
  }

  Future<void> _refreshTurnCredentials() async {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty || !state.isJoined) return;
    try {
      final configuration = await _resolveRtcConfiguration(
        sessionId,
        refreshTurnCredentials: true,
      );
      await _mediaService.updateIceConfiguration(configuration);
    } catch (_) {
      // Transient failure — retry on a short fuse rather than letting the
      // credentials lapse silently.
      _turnRefreshTimer?.cancel();
      _turnRefreshTimer = Timer(const Duration(minutes: 2), () {
        unawaited(_refreshTurnCredentials());
      });
      return;
    }
    _scheduleTurnRefresh();
  }

  void _cancelTurnRefresh() {
    _turnRefreshTimer?.cancel();
    _turnRefreshTimer = null;
  }

  // ── Quality evidence loop ────────────────────────────────────────────────

  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(_statsInterval, (_) {
      if (!state.isJoined) return;
      unawaited(
        _mediaService.collectQualitySample().then((sample) {
          _lastQualitySample = sample;
        }).catchError((Object _) {}),
      );
    });
  }

  void _stopStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _lastQualitySample = null;
  }

  // ── Peer transport recovery ──────────────────────────────────────────────

  void _handlePeerHealth(RealtimePeerHealthEvent event) {
    switch (event.health) {
      case RealtimePeerHealth.recovered:
        _clearReconnectingByPeerKey(event.peerKey);
        return;
      case RealtimePeerHealth.needsRestart:
        unawaited(_performIceRestart(event.peerKey));
        return;
      case RealtimePeerHealth.dead:
        unawaited(_onPeerTransportDead(event.peerKey));
        return;
    }
  }

  /// In-place transport recovery: fresh TURN credentials + an ICE-restart
  /// offer on the EXISTING peer connection. Tracks, renderers, and the
  /// participant's tile all survive; only the transport renegotiates.
  Future<void> _performIceRestart(String peerKey) async {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty || !state.isJoined || _terminating) return;
    _markReconnectingByPeerKey(peerKey);
    try {
      final configuration = await _resolveRtcConfiguration(
        sessionId,
        refreshTurnCredentials: true,
      );
      final offer = await _mediaService.restartIce(
        peerKey: peerKey,
        configuration: configuration,
      );
      if (offer == null) return;
      await _socketService.emitAck('session:offer', <String, dynamic>{
        'sessionId': sessionId,
        'targetSocketId': peerKey,
        'sdp': <String, dynamic>{'sdp': offer.sdp, 'type': offer.type},
      });
    } catch (error) {
      debugPrint('[rtc] ice-restart send failed peerKey=$peerKey err=$error');
    }
  }

  /// The restart budget is spent — rebuild the connection from zero: drop the
  /// dead peer and offer fresh to the same socket. The participant stays on
  /// the roster ("Reconnecting…") throughout.
  Future<void> _onPeerTransportDead(String peerKey) async {
    if (!state.isJoined || _terminating) return;
    _markReconnectingByPeerKey(peerKey);
    await _mediaService.removePeer(peerKey);
    final stillPresent = state.participants.any(
      (p) => (p.runtimeDeviceId ?? '').trim() == peerKey,
    );
    if (stillPresent) {
      _queueOfferTarget(peerKey: peerKey, targetSocketId: peerKey);
      await _flushPendingOffers(refreshTurnCredentials: true);
    }
  }

  // ── Roster reconnect grace ───────────────────────────────────────────────

  String? _userIdForPeerKey(String peerKey) {
    for (final participant in state.participants) {
      if ((participant.runtimeDeviceId ?? '').trim() == peerKey) {
        return participant.userId;
      }
    }
    return null;
  }

  void _markReconnectingByPeerKey(String peerKey) {
    final userId = _userIdForPeerKey(peerKey);
    if (userId == null || userId.isEmpty) return;
    if (state.reconnectingUserIds.contains(userId)) return;
    state = state.copyWith(
      reconnectingUserIds: <String>{...state.reconnectingUserIds, userId},
    );
  }

  void _clearReconnectingByPeerKey(String peerKey) {
    final userId = _userIdForPeerKey(peerKey);
    if (userId == null) return;
    _clearReconnectingUser(userId);
  }

  void _clearReconnectingUser(String userId) {
    _peerGraceTimers.remove(userId)?.cancel();
    if (!state.reconnectingUserIds.contains(userId)) return;
    state = state.copyWith(
      reconnectingUserIds: <String>{...state.reconnectingUserIds}..remove(userId),
    );
  }

  void _startPeerGrace(String userId, String? peerKey) {
    if (userId.isEmpty) return;
    state = state.copyWith(
      reconnectingUserIds: <String>{...state.reconnectingUserIds, userId},
    );
    _peerGraceTimers.remove(userId)?.cancel();
    _peerGraceTimers[userId] = Timer(_peerGrace, () {
      _peerGraceTimers.remove(userId);
      _expirePeerGrace(userId, peerKey);
    });
  }

  void _expirePeerGrace(String userId, String? peerKey) {
    if (_terminating) return;
    final updatedParticipants = state.participants
        .where((participant) => participant.userId != userId)
        .toList();
    state = state.copyWith(
      participants: updatedParticipants,
      reconnectingUserIds: <String>{...state.reconnectingUserIds}
        ..remove(userId),
    );
    final key = (peerKey ?? '').isNotEmpty
        ? peerKey!
        : (_peerSocketByUserId[userId] ?? '');
    if (key.isNotEmpty) {
      _removePendingOfferTarget(key);
      unawaited(_mediaService.removePeer(key));
    }
    _peerSocketByUserId.remove(userId);

    // The room-empties decision runs only AFTER the grace expired — a
    // transient drop never ends the meeting for whoever stayed.
    if (updatedParticipants.length <= 1 && state.isJoined) {
      final isMeeting = MeetingRealtimeSemantics.waitsForParticipantReturnWhenAlone(
        state.session?.surfaceType,
      );
      if (isMeeting) {
        state = state.copyWith(
          infoMessage: 'Waiting for the other participant to return…',
          clearErrorMessage: true,
        );
      } else {
        debugPrint(
          '[ended-diag] peer grace expired: participants=${updatedParticipants.length} '
          'isJoined=${state.isJoined} leftUserId=$userId',
        );
        unawaited(
          _terminateSession(
            keepSocketConnected: true,
            infoMessage: 'Call ended.',
            alsoCallRepository: false,
          ),
        );
      }
    }
  }

  // ── Signaling grace (socket loss without media loss) ─────────────────────

  void _startSignalingGrace() {
    _signalingGraceTimer?.cancel();
    _signalingGraceTimer = Timer(_signalingGrace, () {
      _signalingGraceTimer = null;
      if (_terminating || state.isConnected) return;
      // The rejoin did not land inside the grace window — now, and only now,
      // the media plane is released and the room returns to idle.
      _clearPendingOfferTargets();
      unawaited(_mediaService.resetSessionMedia());
      state = _copyWithDetachedMediaState(
        connectionStatus: RealtimeConnectionStatus.disconnected,
        joinState: RealtimeJoinState.idle,
        clearSessionContext: true,
        infoMessage: 'The connection could not be restored.',
      );
    });
  }

  void _cancelSignalingGrace() {
    _signalingGraceTimer?.cancel();
    _signalingGraceTimer = null;
  }

  /// User-chosen device handover: continue the meeting on THIS device after
  /// it was replaced by another one.
  Future<void> useHereInstead() async {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty) return;
    state = state.copyWith(clearErrorMessage: true, clearInfoMessage: true);
    await join(sessionId);
  }

  /// TRY THIS CALL AGAIN.
  ///
  /// The recovery offered alongside a visible connection failure. It clears
  /// the failure, asks the backend afresh for the configuration it is willing
  /// to authorise — refreshed, never the cached one that just failed — and
  /// re-runs negotiation. It does NOT end the call, so a transient
  /// infrastructure problem does not cost somebody their call.
  ///
  /// If it fails again the failure simply reappears, which is the honest
  /// outcome. Nothing here retries silently or on a loop.
  Future<void> retryConnection() async {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty) return;
    _rtcConfiguration = null;
    _rtcConfigurationSessionId = null;
    _connectionWindowTimer?.cancel();
    _connectionWindowTimer = null;
    _connectionWindowSessionId = null;
    state = state.copyWith(
      clearConnectionFailure: true,
      clearErrorMessage: true,
      clearMediaError: true,
    );
    await _ensureMediaReady(sessionId, refreshTurnCredentials: true);
    if (state.connectionFailure != null) return;
    await _reconcileRtcPeers('join', refreshTurnCredentials: true);
  }

  /// Re-attempt media acquisition after a permission denial or device
  /// failure, without leaving the room.
  Future<void> retryMedia() async {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty || !state.isJoined) return;
    state = state.copyWith(clearMediaError: true, clearErrorMessage: true);
    await _ensureMediaReady(sessionId, refreshTurnCredentials: true);
    await _reconcileRtcPeers('track-change');
  }

  // ── JOINED_LOST_MID_CALL — observation, not repair ────────────────────────
  //
  // Founder ruling §D. A long call drops to "connecting" and re-hydrates, and
  // the minimised call falls back to its passive representation. Measured
  // 2026-08-28 with both ends observed at the same moment: the SERVER had this
  // participant ACTIVE with a heartbeat six seconds old and all three
  // Cloudflare transports open and carrying media, while THIS client rendered
  // "Connecting… Setting up your session".
  //
  //     FIRST_BROKEN_ARROW = server participant ACTIVE
  //                          -> client believes it is not joined
  //
  // So the question is not "did the transport fail" — it demonstrably did not.
  // It is "what moved this client's own joinState", and no server record can
  // answer that. This records the transition and what was true around it.
  //
  // Deliberately NOT a fix. Two changes shipped into this path yesterday on
  // green static checks alone and both had to be reverted; the next change
  // here gets made against evidence.
  AppLifecycleState? _lastLifecycleState;
  int _lifecycleReports = 0;

  /// Bounded so a pathological flap cannot become a firehose. Transitions are
  /// rare by nature; if this cap is ever reached that is itself the finding.
  static const int _maxLifecycleReports = 60;

  // ── THE CONNECTION WINDOW ────────────────────────────────────────────────
  //
  // A call that has been answered is either going to carry audio shortly or it
  // is not. Waiting forever is the one answer that is never true, and it is
  // what both sides used to get: the callee sat on "Connecting…" for the whole
  // life of the session with nothing said.
  //
  // Ninety seconds is deliberately generous — far beyond any healthy
  // negotiation, which completes in low single-digit seconds, and beyond a
  // slow mobile network renegotiating after a handover. It is a bound on
  // silence, not a performance target: it must never fire on a call that was
  // about to work.
  //
  // It bounds this CLIENT's presentation only. Nothing here writes call state,
  // and the outcome still comes from the authority when the call ends —
  // answered-with-no-media ends ACCEPTED_NOT_CONNECTED because that is what
  // happened, not because a timer said so.
  static const Duration _connectionWindow = Duration(seconds: 90);
  Timer? _connectionWindowTimer;
  String? _connectionWindowSessionId;

  void _updateConnectionWindow(RealtimeState next) {
    final sessionId = next.sessionId;
    final phase = next.session?.call?.phase;
    final needsWindow =
        sessionId != null &&
        sessionId.isNotEmpty &&
        (phase == CallPhase.accepted || phase == CallPhase.connecting);

    if (!needsWindow) {
      _connectionWindowTimer?.cancel();
      _connectionWindowTimer = null;
      _connectionWindowSessionId = null;
      return;
    }

    // Already armed for this call. The clock must NOT restart on every state
    // change, or a chatty session would keep pushing the deadline away and the
    // bound would never arrive.
    if (_connectionWindowSessionId == sessionId &&
        _connectionWindowTimer != null) {
      return;
    }

    _connectionWindowTimer?.cancel();
    _connectionWindowSessionId = sessionId;
    _connectionWindowTimer = Timer(_connectionWindow, () {
      if (!mounted) return;
      final now = state;
      // Re-read at fire time: the call may have connected or ended while this
      // was pending, and a stale timer must never accuse a working call.
      if (now.sessionId != sessionId) return;
      final live = now.session?.call?.phase;
      if (live != CallPhase.accepted && live != CallPhase.connecting) return;
      if (now.connectionFailure != null) return;
      state = now.copyWith(
        connectionFailure: CallConnectionFailure.notEstablished,
      );
    });
  }

  @override
  set state(RealtimeState value) {
    _updateConnectionWindow(value);
    RealtimeState? previous;
    if (mounted) {
      previous = super.state;
    }
    super.state = value;
    if (previous == null) return;
    _observeJoinTransition(previous, value);
  }

  void _observeJoinTransition(RealtimeState before, RealtimeState after) {
    final joinChanged = before.joinState != after.joinState;
    final connectionChanged = before.connectionStatus != after.connectionStatus;
    if (!joinChanged && !connectionChanged) return;
    if (_lifecycleReports >= _maxLifecycleReports) return;

    final sessionId = _managedSessionId;
    if (sessionId.isEmpty) return;
    _lifecycleReports += 1;

    // `lastSocketEvent` is the closest thing this controller has to a cause:
    // almost every transition here is driven by a socket event, and the name
    // of the last one narrows the trigger to a handful of code paths without
    // shipping a stack trace to the server.
    unawaited(_repository.reportStageDiagnostic(
      sessionId,
      phase: 'lifecycle',
      code: joinChanged ? 'join_state' : 'connection_state',
      message: 'join=${before.joinState.name}->${after.joinState.name} '
          'conn=${before.connectionStatus.name}->${after.connectionStatus.name} '
          'lastEvent=${after.lastSocketEvent ?? 'none'} '
          'socket=${_socketService.isConnected} '
          'mediaReady=${after.isMediaReady} '
          'participants=${after.participants.length} '
          'lifecycle=${_lastLifecycleState?.name ?? 'unknown'} '
          'terminating=$_terminating '
          'awaitingRejoin=$_awaitingReconnectRejoin',
      platform: _clientPlatform,
    ).catchError((_) {}));
  }

  @override
  // The base signature names this `state`, which would shadow the
  // StateNotifier's own `state` used inside — the rename is deliberate.
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // Recorded for every transition, not only `resumed` — a call that breaks
    // while the tab is hidden needs the hidden state in the record, and the
    // early return below would otherwise discard exactly that.
    _lastLifecycleState = lifecycleState;
    if (lifecycleState != AppLifecycleState.resumed) return;
    if (!state.isJoined || _terminating) return;
    // Wake-from-sleep / tab-foreground: the socket may have survived while
    // every ICE transport died. Check both planes.
    if (!_socketService.isConnected) {
      final sid = _resumeSessionId?.trim() ?? '';
      if (sid.isNotEmpty) {
        _awaitingReconnectRejoin = false;
        unawaited(_rejoinAfterReconnect(sid));
      }
    } else {
      unawaited(_mediaService.checkPeersHealth());
    }
  }

  void _clearRtcConfiguration() {
    _rtcConfiguration = null;
    _rtcConfigurationSessionId = null;
  }

  /// One-shot: the far side's media arrived on a call this device placed.
  ///
  /// CallKit needs a connected timestamp or the call register shows an
  /// outgoing entry with no duration. Native decides whether this session was
  /// outgoing at all and ignores it otherwise, so this hook does not need to
  /// know the direction — which matters, because the media layer below is the
  /// same code for a call received and a call placed.
  bool _reportedMediaEstablished = false;

  void _handleMediaSnapshot(RealtimeMediaSnapshot snapshot) {
    state = state.copyWith(
      isMediaReady: snapshot.ready,
      localRenderer: snapshot.localRenderer,
      remoteRenderers: snapshot.remoteRenderers,
      remoteRenderersByParticipant: snapshot.remoteRenderersByParticipant,
      microphoneEnabled: snapshot.micEnabled,
      cameraEnabled: snapshot.cameraEnabled,
      speakerphoneEnabled: snapshot.speakerphoneEnabled,
      mediaError: snapshot.error,
      isScreenSharing: snapshot.isScreenSharing,
    );

    if (snapshot.ready && state.isJoined) {
      unawaited(_reconcileRtcPeers('media-ready'));
    }

    // THIS DEVICE CAN NOW HEAR THE OTHER SIDE.
    //
    // Only an endpoint can observe that, which is why it is reported from
    // here — but it is reported as EVIDENCE, not as a verdict. The backend
    // decides whether the call is connected, and only once BOTH sides have
    // said this. One endpoint alone hears silence and would otherwise have
    // been told the call had connected.
    if (!_reportedMediaEstablished && _hasRemoteMedia(snapshot)) {
      final sessionId = _managedSessionId;
      if (sessionId.isNotEmpty) {
        _reportedMediaEstablished = true;
        unawaited(_reportMediaEstablished(sessionId, snapshot));

        unawaited(
          IosCallKit.instance
              .reportOutgoingConnected(sessionId)
              .catchError((_) {}),
        );
        // Track C — remote media present is the moment a placed call became a
        // conversation on Android too. Without it the system call stays in
        // "connecting" for its whole life and any history entry has no
        // duration.
        unawaited(
          AndroidTelecom.instance.reportConnected(sessionId).catchError((_) {}),
        );
      }
    }
  }

  /// A USABLE MEDIA PATH WITH THE REMOTE PEER, ON EITHER TRANSPORT.
  ///
  /// This previously read `remoteRenderers` alone — the device-keyed map the
  /// MESH transport fills. On an SFU call that map stays permanently empty and
  /// the stage populates `remoteRenderersByParticipant` instead, so on every
  /// SFU call the one hook that noticed remote media never fired at all.
  ///
  /// Audio is enough. A video call whose remote camera is off is still a
  /// conversation, and waiting for a remote video track would hold a working
  /// call at "Connecting" indefinitely.
  bool _hasRemoteMedia(RealtimeMediaSnapshot snapshot) =>
      snapshot.remoteRenderers.isNotEmpty ||
      snapshot.remoteRenderersByParticipant.isNotEmpty;

  /// Describe what was actually observed, so a CONNECTED call can be audited
  /// rather than trusted. Free text: nothing branches on it.
  String _mediaEvidence(RealtimeMediaSnapshot snapshot) {
    final parts = <String>[];
    if (snapshot.remoteRenderers.isNotEmpty) {
      parts.add('mesh-remote-renderers=${snapshot.remoteRenderers.length}');
    }
    if (snapshot.remoteRenderersByParticipant.isNotEmpty) {
      parts.add(
        'stage-remote-participants='
        '${snapshot.remoteRenderersByParticipant.length}',
      );
    }
    if (snapshot.onTrackAudioSeen) parts.add('onTrack:audio');
    if (snapshot.onTrackVideoSeen) parts.add('onTrack:video');
    return parts.join(' ');
  }

  Future<void> _reportMediaEstablished(
    String sessionId,
    RealtimeMediaSnapshot snapshot,
  ) async {
    try {
      await _repository.reportMediaEstablished(
        sessionId,
        evidence: _mediaEvidence(snapshot),
      );
    } catch (_) {
      // Reporting evidence must never break a call in progress. The person can
      // still hear the other side; what is lost is the server's ability to
      // mark the call connected from this end, and the next read of the
      // session will still carry whatever phase the backend did reach.
      _reportedMediaEstablished = false;
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

    // Negotiation watchdog: a lost ANSWER previously stalled the connection
    // forever (the offer relay is fire-and-forget). One retry after 8s if
    // the peer still hasn't answered; perfect negotiation absorbs any
    // duplicate on the other side.
    _armAnswerWatchdog(peerKey: peerKey, targetSocketId: targetSocketId);
  }

  final Set<String> _answerWatchdogRetried = <String>{};

  void _armAnswerWatchdog({
    required String peerKey,
    required String targetSocketId,
  }) {
    Timer(const Duration(seconds: 8), () {
      if (_terminating || !state.isJoined) return;
      if (!_mediaService.isAwaitingAnswer(peerKey)) {
        _answerWatchdogRetried.remove(peerKey);
        return;
      }
      if (_answerWatchdogRetried.contains(peerKey)) return;
      _answerWatchdogRetried.add(peerKey);
      debugPrint('[rtc] answer watchdog RE-OFFER peerKey=$peerKey');
      unawaited(
        _sendOfferToSocket(peerKey: peerKey, targetSocketId: targetSocketId)
            .catchError((Object _) {}),
      );
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
        _cancelSignalingGrace();
        // Recovered: the NEXT problem gets a fresh budget rather than
        // inheriting a spent one from an incident already survived.
        _clearTrouble();
        state = state.copyWith(
          connectionStatus: RealtimeConnectionStatus.connected,
          lastSocketEvent: event.name,
        );
        // RECONNECT RESILIENCE: the socket came back while we were still in the
        // room — silently rejoin (rehydrate → socket session:join → media →
        // heartbeat → renegotiation → room restored). Uses a dedicated path
        // because join() early-returns for the same session while joinState is
        // still `joined` (which we kept so the room UI persisted through the
        // gap).
        if (_awaitingReconnectRejoin &&
            (_resumeSessionId?.trim().isNotEmpty ?? false) &&
            state.isCallRoomVisible &&
            !_terminating) {
          _awaitingReconnectRejoin = false;
          final sid = _resumeSessionId!.trim();
          unawaited(_rejoinAfterReconnect(sid));
        }
        return;
      case 'socket:disconnected':
        _stopHeartbeat();
        final canResume = (_resumeSessionId?.trim().isNotEmpty ?? false) &&
            state.isCallRoomVisible &&
            !_terminating &&
            state.joinState != RealtimeJoinState.replaced;
        if (canResume) {
          // MEDIA CONTINUITY: the signaling socket is not the media plane's
          // life support. Peer connections and local media stay alive through
          // the gap — WebRTC keeps flowing if the network itself is fine (the
          // common case: proxy idle-close, engine.io ping timeout, server
          // deploy). The rejoin on 'socket:connected' resyncs roster state;
          // only the signaling-grace expiry releases media.
          _awaitingReconnectRejoin = true;
          _startSignalingGrace();
          state = state.copyWith(
            joinState: RealtimeJoinState.joined,
            connectionStatus: RealtimeConnectionStatus.reconnecting,
            infoMessage: 'Reconnecting…',
            clearErrorMessage: true,
            lastSocketEvent: event.name,
          );
        } else {
          _clearPendingOfferTargets();
          unawaited(_mediaService.resetSessionMedia());
          if (state.joinState == RealtimeJoinState.replaced) {
            // Deliberate handover — keep the parked "continue here" surface.
            state = state.copyWith(
              connectionStatus: RealtimeConnectionStatus.disconnected,
              lastSocketEvent: event.name,
            );
            return;
          }
          state = _copyWithDetachedMediaState(
            connectionStatus: RealtimeConnectionStatus.disconnected,
            joinState: RealtimeJoinState.idle,
            clearSessionContext: true,
            lastSocketEvent: event.name,
          );
        }
        return;
      case 'session:server.restarting':
        // Heads-up from a deploying server: the disconnect that follows is a
        // restart, not a failure. Pre-arm the grace so the room holds calm.
        if (state.isJoined && !_terminating) {
          state = state.copyWith(
            infoMessage: 'Reconnecting…',
            lastSocketEvent: event.name,
          );
        }
        return;
      case 'socket:connect_error':
      case 'socket:error':
        // A transport error DURING A LIVE CALL is a reconnect, not a verdict.
        // socket.io keeps retrying on its own, and both stage recovery and
        // the server are still holding the call open at this point; showing
        // error here is what put a recovering call on an error/retry screen
        // after 25 seconds.
        final socketStatus = _troubleStatus();
        final socketReconnecting =
            socketStatus == RealtimeConnectionStatus.reconnecting;
        state = state.copyWith(
          connectionStatus: socketStatus,
          clearErrorMessage: socketReconnecting,
          errorMessage: socketReconnecting
              ? null
              : event.payload['message']?.toString(),
          clearInfoMessage: !socketReconnecting,
          infoMessage: socketReconnecting ? 'Reconnecting…' : null,
          lastSocketEvent: event.name,
        );
        return;
      case 'session:participant.joined':
      case 'session:participant.resumed':
        final joinedUserId = _participantUserIdFromPayload(event.payload);
        final joinedSocketId = _transportPeerKeyFromPayload(event.payload);

        // THE SERVER NAMES THE SOCKETS THIS ARRIVAL REPLACES.
        //
        // `replacedSocketIds` has been on this payload all along and NOTHING
        // consumed it. The local `_peerSocketByUserId` fallback below only
        // works when this client happened to learn the previous socket from a
        // live broadcast; a roster hydrated over REST never carries one, and a
        // transport loss can clear it. In those cases the returning person was
        // added BESIDE their own dead peer -- founder-observed 2026-08-28 as a
        // fourth tile in a three-party call after a reload.
        //
        // Honouring the server's list first makes the retirement independent
        // of what this client happened to remember. The local fallback stays
        // for older payloads.
        for (final replaced in _replacedSocketIdsFromPayload(event.payload)) {
          if (replaced.isEmpty || replaced == joinedSocketId) continue;
          _removePendingOfferTarget(replaced);
          unawaited(_mediaService.removePeer(replaced));
        }

        // A rejoin inside the grace window: the seat was held; release the
        // "Reconnecting…" flag and retire the stale peer connection so the
        // fresh negotiation binds to the new socket cleanly.
        if (joinedUserId.isNotEmpty) {
          _clearReconnectingUser(joinedUserId);
          final previousSocketId = _peerSocketByUserId[joinedUserId];
          if (previousSocketId != null &&
              previousSocketId.isNotEmpty &&
              previousSocketId != joinedSocketId) {
            _removePendingOfferTarget(previousSocketId);
            unawaited(_mediaService.removePeer(previousSocketId));
          }
          if (joinedSocketId.isNotEmpty) {
            _peerSocketByUserId[joinedUserId] = joinedSocketId;
          }
        }

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
        unawaited(
          _mediaService.applyParticipantScaling(state.participants.length),
        );

        // Lifecycle-based negotiation (replaces the socket-id initiator rule).
        // The EXISTING peer offers to the NEWCOMER whose socketId we just
        // learned from this participant.joined event. The newcomer does NOT
        // initiate to existing roster peers (it has no reliable socketId for
        // them — the REST roster need not carry runtimeDeviceId); it only
        // answers. One-directional, so no glare, and the offerer always has a
        // valid target socketId.
        if (state.isJoined) {
          // Convergence-based negotiation. The merge above put the newcomer
          // (with its live socketId from this broadcast) into state.participants;
          // as the EXISTING peer we now offer to it. The newcomer running the
          // same reconcile has us WITHOUT a live socketId (REST/hydrate) and is
          // filtered out, so it only answers — one-directional, no arbitration.
          unawaited(_reconcileRtcPeers('participant.joined'));
        }
        return;
      case 'session:participant.left':
        final leavingUserId = _participantUserIdFromPayload(event.payload);
        final leavingPeerKey = _transportPeerKeyFromPayload(event.payload);
        final leftReason =
            (event.payload['reason'] ?? '').toString().trim().toLowerCase();
        final appliesReconnectGrace =
            MeetingRealtimeSemantics.appliesReconnectGraceOnParticipantLeft(
          surfaceType: state.session?.surfaceType,
          leftReason: leftReason,
        );

        // The SAME rule applies to the grace path, at its source. A grace
        // started for somebody this client never had would expire into
        // `_expirePeerGrace`, whose own emptiness test would then end a call
        // for a departure that was never ours — the founder's defect again,
        // merely delayed by the length of the grace window.
        if (appliesReconnectGrace &&
            leavingUserId.isNotEmpty &&
            state.participants.any((p) => p.userId == leavingUserId)) {
          // RECONNECT GRACE: an involuntary drop does not empty the seat. The
          // participant stays on the roster ("Reconnecting…"), their peer
          // connection stays alive — media often continues flowing while only
          // the signaling socket blipped — and the seat is released only when
          // the grace window expires without a rejoin.
          state = state.copyWith(lastSocketEvent: event.name);
          _startPeerGrace(
            leavingUserId,
            leavingPeerKey.isNotEmpty ? leavingPeerKey : null,
          );
          return;
        }

        // WAS THIS SOMEBODY WE ACTUALLY HAD? Read BEFORE the roster changes.
        //
        // Founder-observed 2026-08-25: *"before connecting, immediately after
        // accept, there was a call ended banner"*. A departure event that
        // arrives while joining found a roster containing only ME — the other
        // party's row had not landed yet — and the emptiness test below read
        // that as everyone having left.
        //
        // A roster of one during a join means "I have not learned who else is
        // here", not "they have all gone". So a departure may only empty a
        // room if the person departing was someone this client actually had on
        // the roster; a leaver we never knew tells us nothing about emptiness.
        // This is the same rule the shared roster already applies to identity:
        // an entry that identifies nobody is never authoritative.
        final knewLeaver = leavingUserId.isNotEmpty &&
            state.participants.any((p) => p.userId == leavingUserId);

        final updatedParticipants = state.participants
            .where((participant) => participant.userId != leavingUserId)
            .toList();

        state = state.copyWith(
          participants: updatedParticipants,
          reconnectingUserIds: <String>{...state.reconnectingUserIds}
            ..remove(leavingUserId),
          lastSocketEvent: event.name,
        );
        _peerGraceTimers.remove(leavingUserId)?.cancel();
        _peerSocketByUserId.remove(leavingUserId);

        if (leavingPeerKey.isNotEmpty) {
          _removePendingOfferTarget(leavingPeerKey);
          unawaited(_mediaService.removePeer(leavingPeerKey));
        } else if (leavingUserId.isNotEmpty) {
          _removePendingOfferTarget(leavingUserId);
          unawaited(_mediaService.removePeer(leavingUserId));
        }

        if (knewLeaver && updatedParticipants.length <= 1 && state.isJoined) {
          if (MeetingRealtimeSemantics.waitsForParticipantReturnWhenAlone(
            state.session?.surfaceType,
          )) {
            state = state.copyWith(
              infoMessage: 'Waiting for the other participant…',
              clearErrorMessage: true,
            );
          } else {
            debugPrint(
              '[ended-diag] participant-left event: participants='
              '${updatedParticipants.length} isJoined=${state.isJoined}',
            );
            unawaited(
              _terminateSession(
                keepSocketConnected: true,
                infoMessage: 'Call ended.',
                alsoCallRepository: false,
              ),
            );
          }
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
          // Map this peer's renderer (keyed by peerKey) to its roster identity,
          // so the newcomer can name/label the existing peer's tile.
          _backfillPeerSocket(_participantUserIdFromPayload(event.payload), peerKey);
          // Perfect-negotiation politeness: the LOWER raw socket id is polite
          // (yields on a glare collision). Deterministic and symmetric, so both
          // ends agree on who yields without any extra signaling.
          final meSocketId = _socketService.socketId ?? '';
          final polite =
              _rawSocket(meSocketId).compareTo(_rawSocket(fromSocketId)) < 0;
          final answer = await _mediaService.handleRemoteOffer(
            peerKey: peerKey,
            targetSocketId: fromSocketId,
            polite: polite,
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
          if (answer == null) {
            // Glare: the impolite peer ignored this offer and keeps its own.
            return;
          }
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
        // Deliberate device handover — NOT a reconnect. Auto-rejoining here
        // made two devices of the same user replace each other forever. This
        // device parks calmly; the user can continue here explicitly.
        _resumeSessionId = null;
        _awaitingReconnectRejoin = false;
        _cancelSignalingGrace();
        _stopHeartbeat();
        _stopStatsTimer();
        _clearPendingOfferTargets();
        unawaited(_mediaService.resetSessionMedia());
        state = _copyWithDetachedMediaState(
          joinState: RealtimeJoinState.replaced,
          infoMessage: 'This meeting is now active on another device.',
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
      case 'call:phase':
        // WHERE THE CALL IS, FROM THE ONLY THING THAT DECIDES IT.
        //
        // This is a projection of a phase the backend has already committed,
        // so it is applied to the call we hold rather than used to derive a
        // new one. `applyPhaseEvent` refuses to move backwards: these arrive
        // over an unreliable transport, out of order and more than once, and a
        // late "connecting" must never rewrite a conversation that connected.
        final phaseSessionId = (event.payload['sessionId'] ?? '')
            .toString()
            .trim();
        final session = state.session;
        if (session == null) return;
        if (phaseSessionId.isNotEmpty && phaseSessionId != session.id) return;

        final existing = session.call;
        if (existing == null) {
          // A session we hold with no call — a meeting, a stage, or a call
          // whose session we have not re-read since it began. Nothing is
          // invented here; the next read of the session carries the call.
          state = state.copyWith(lastSocketEvent: event.name);
          return;
        }

        state = state.copyWith(
          session: session.withCall(existing.applyPhaseEvent(event.payload)),
          lastSocketEvent: event.name,
        );
        return;
      case 'call:accepted':
        // Authoritative ACCEPT truth, emitted the moment the backend's
        // first-action-wins ACCEPT transaction committed — independent of
        // whether the accepting party's realtime/media join has completed.
        // This deliberately does NOT touch `participants`/`joinState`: it
        // moves the caller out of indefinite ringing into an ACCEPTED/
        // JOINING state, but `session:participant.joined` remains the sole
        // proof of actual connection. Must not be collapsed with CONNECTED.
        final acceptedSessionId = (event.payload['sessionId'] ?? '')
            .toString()
            .trim();
        if (acceptedSessionId.isNotEmpty &&
            state.session?.id != null &&
            acceptedSessionId != state.session!.id) {
          return;
        }
        state = state.copyWith(
          acceptedByPeer: true,
          lastSocketEvent: event.name,
        );
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
        if (MeetingRealtimeSemantics.discardsOutOfOrderEndedEvent(
          surfaceType: state.session?.surfaceType,
          terminalReason: terminalReason,
          terminalCallState: terminalCallState,
        )) {
          state = state.copyWith(lastSocketEvent: event.name);
          return;
        }
        _clearPendingOfferTargets();
        _cancelSignalingGrace();
        _stopStatsTimer();
        _cancelTurnRefresh();
        for (final timer in _peerGraceTimers.values) {
          timer.cancel();
        }
        _peerGraceTimers.clear();
        _peerSocketByUserId.clear();
        _answerWatchdogRetried.clear();
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
        if (MeetingRealtimeSemantics.suppressesStaleDisconnectSignal(
          state.session?.surfaceType,
        )) {
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
      // SOMEBODY'S PUBLISHED MEDIA CHANGED. THAT IS ITS OWN FACT.
      //
      // Re-subscription used to happen only when the roster changed, and a
      // roster change is a different event from a publication. A participant
      // who joined and published four seconds later was reconciled against
      // BEFORE they had anything to offer, and nothing ever asked again:
      // measured 2026-08-28 in a three-party call where all three transports
      // were open and one person's media reached nobody.
      //
      // The reconciliation is idempotent, so this needs no de-duplication of
      // its own: the transport subscribes only track ids it has not already
      // subscribed to, and the media service replaces renderers only when the
      // resolved tracks actually differ.
      case 'session:media.published':
        if (state.joinState == RealtimeJoinState.idle) {
          state = state.copyWith(lastSocketEvent: event.name);
          return;
        }
        // THE PUBLISHER RECONCILES TOO, AND THAT IS FINE.
        //
        // Suppressing it would need this controller to know its own
        // participant id, which it does not hold today — and the work saved
        // is nothing: `listSubscribableTracks` already excludes the caller's
        // own tracks, so a publisher's reconcile finds only what it may
        // already have, `fresh` comes back empty, and the transport returns
        // without calling the provider at all. Plumbing an identity through
        // to skip a no-op would be the more expensive mistake.
        state = state.copyWith(lastSocketEvent: event.name);
        unawaited(_reconcileRtcPeers('media.published'));
        return;
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

  String _rawSocket(String s) =>
      s.startsWith('socket:') ? s.substring('socket:'.length) : s;

  /// SINGLE convergence-based RTC negotiation entry point. Every source that can
  /// change presence or local media routes through here (join, hydrate,
  /// media-ready, camera/mic/screen toggle, participant.joined, reconnect,
  /// resume) — negotiation never depends on the participant.joined event alone.
  ///
  /// Invariant (dictated by the backend join contract): the EXISTING peer offers
  /// to the NEWCOMER; the newcomer only answers. We only ever hold a peer's LIVE
  /// Sockets the server says this arrival replaces.
  ///
  /// Tolerant of shape: the payload has carried a plain list, and a rejoin
  /// after a continuity gap is exactly the case where getting this wrong
  /// leaves a permanent duplicate participant on screen.
  List<String> _replacedSocketIdsFromPayload(Map<String, dynamic> payload) {
    final raw = payload['replacedSocketIds'];
    if (raw is! List) return const <String>[];
    return raw
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  /// socketId if we learned it from a participant.joined broadcast — i.e. we
  /// were already in the room when they joined. A newcomer sees existing peers
  /// only via the REST/hydrate roster, WITHOUT a live socketId, so it is
  /// filtered out below and never offers. Therefore "I hold this peer's live
  /// socketId and have no peer yet" ≡ "I am the existing peer for them" ≡ "I
  /// offer". Reconnect races where both briefly hold each other's socket are
  /// resolved by perfect-negotiation in the media service's handleRemoteOffer,
  /// NOT by any arbitration here.
  /// Bring up, or refresh, the stage transport for this session.
  ///
  /// Deliberately idempotent and reason-driven, mirroring how mesh
  /// reconciliation is called: the first pass attaches and publishes, every
  /// later pass re-resolves who else is publishing. Remote binding is
  /// deterministic, so a roster change is the only trigger needed — there is
  /// no callback to wait on.
  /// Which client reported a diagnostic — web, android, windows, ios.
  String get _clientPlatform =>
      kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// THE LAST UNLIT STRETCH: canonical map → state → widget → tile → mount.
  ///
  /// Every arrow before this one is now evidenced. Cloudflare returns valid
  /// bindings, the client binds them, the media service creates and holds a
  /// renderer, and the track decodes at ~30fps — and on web the tile is not
  /// drawn. Server records cannot see any of the remaining steps, and reading
  /// the widget tree by hand has twice produced a plausible wrong answer.
  ///
  /// So the grid states what it saw and what it decided, once per distinct
  /// observation. Deduplicated because `build` runs on every frame and an
  /// undeduplicated report would be a firehose, not evidence.
  String? _lastGridObservation;

  void reportGridObservation(String message) {
    if (message == _lastGridObservation) return;
    // DO NOT SPEND THE DEDUPE KEY ON AN OBSERVATION THAT WAS NEVER SENT.
    //
    // The first version stamped `_lastGridObservation` before checking the
    // session id, so an observation made in the instant before the session
    // was known counted as "already reported" — and if the state then held
    // steady, the identical message was suppressed for ever and the probe
    // stayed silent for the whole call. That happened on 2026-08-28: Chrome
    // produced no grid report at all for a session it was plainly in.
    //
    // Instrumentation that can silently stop reporting is worse than none,
    // because its silence reads as "nothing to say".
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty) return;
    _lastGridObservation = message;
    unawaited(_repository.reportStageDiagnostic(
      sessionId,
      phase: 'grid',
      code: 'grid_state',
      message: message,
      platform: _clientPlatform,
    ));
  }

  /// Canonical trigger label for the stage trace (§6).
  static String _stageTrigger(String reason) {
    switch (reason) {
      case 'join':
      case 'resume':
        return 'JOIN';
      case 'hydrate':
      case 'hydrate-live':
        return 'HYDRATE';
      case 'media-ready':
        return 'MEDIA_READY';
      case 'participant.joined':
        return 'PARTICIPANT_CHANGE';
      default:
        return reason.toUpperCase();
    }
  }

  /// How many times this session has rebuilt a lost stage transport.
  ///
  /// Bounded on purpose. A network that is genuinely gone will fail every
  /// attempt, and a client that retries forever burns the battery, hammers
  /// the provider, and still cannot connect. Three tries, widening, then stop
  /// and say so.
  int _stageRecoveries = 0;
  bool _recoveringStage = false;
  Timer? _stageRecoveryReset;
  static const List<Duration> _stageRecoveryBackoff = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 6),
    Duration(seconds: 15),
  ];

  /// Rebuild a stage transport that died mid-call.
  ///
  /// THE GAP THIS CLOSES (2026-08-28). Nothing on the stage path detected a
  /// dead transport and nothing rebuilt one. Three calls died identically in
  /// one evening -- transport lost, sixty seconds of silence, then
  /// `heartbeat_timeout` -- while the person sat looking at a frozen call.
  ///
  /// Rebuilding rather than ICE-restarting in place is deliberate. The server
  /// now RECLAIMS a participant's previous transport instead of refusing the
  /// new one, so open-over-a-dead-one is a supported act; and a rebuild
  /// re-publishes and re-subscribes, which converges the whole registry
  /// instead of only repairing connectivity.
  ///
  /// THIS LOOPS, AND THE FIRST VERSION DID NOT. That version made ONE attempt
  /// and returned, trusting `onLost` to call it again -- but `onLost` fires
  /// once per transport, and by then the transport had been destroyed. So the
  /// three-attempt budget was unreachable, and a first attempt made while the
  /// network was still down ended recovery permanently. Measured on a real
  /// call 2026-08-28: wifi off on the phone, one doomed attempt, then nothing
  /// watching when the network came back, and video stayed frozen.
  ///
  /// The lesson generalises: recovery cannot depend on being re-triggered by
  /// the thing that failed. It has to drive itself until it succeeds or its
  /// budget runs out.
  /// ONE PATIENCE BUDGET FOR THE WHOLE CALL.
  ///
  /// THE DEFECT THIS CLOSES (founder-observed 2026-08-28): during a network
  /// outage the call "was redirected to error/retry almost after 25 sec".
  /// That is `_establishTimeout` (20s) plus `_idAssignmentMaxWait` (5s) in
  /// the socket service — and it fired while stage recovery was still
  /// working and while the server was still holding the participant.
  ///
  /// THREE COMPONENTS EACH DECIDED WHEN THE CALL WAS DEAD, AND DISAGREED:
  ///
  ///     socket establishment   25s   -> error/retry on screen
  ///     stage recovery         ~41s  (18s detect + 2/6/15 backoff)
  ///     server revoke          60s
  ///
  /// The SHORTEST answer owned what the person saw, so a call that was being
  /// recovered correctly still looked broken — and the error path could tear
  /// down the very controller doing the recovering. Making the transport
  /// recoverable is worth nothing while the UI gives up first.
  ///
  /// The ordering has to run the other way: the person sees "reconnecting"
  /// until recovery has genuinely had its chance, and only then error. This
  /// budget sits ABOVE stage recovery's ~41s so recovery is never cut off
  /// mid-attempt, and BELOW the server's 60s revoke so we never promise a
  /// call the server has already given up on.
  ///
  /// It is not infinite patience: a call outside its budget, or with no live
  /// session at all, still reports the real failure. Truth over hope, only
  /// later than before.
  /// Sits just UNDER the server's 120s revoke (founder ruling 2026-08-28),
  /// so the UI never keeps promising a call the server has already ended,
  /// and never stops promising one it is still holding.
  static const Duration _reconnectPatience = Duration(seconds: 110);
  DateTime? _troubleSince;

  /// What a connection failure should LOOK like right now.
  RealtimeConnectionStatus _troubleStatus() {
    // No live call to be patient about — a failure is simply a failure.
    final inCall = (state.sessionId ?? '').isNotEmpty &&
        (state.isJoined || state.joinState == RealtimeJoinState.joining) &&
        !_terminating &&
        !_endingCall;
    if (!inCall) return RealtimeConnectionStatus.error;

    final since = _troubleSince ??= DateTime.now();
    if (DateTime.now().difference(since) < _reconnectPatience) {
      return RealtimeConnectionStatus.reconnecting;
    }
    return RealtimeConnectionStatus.error;
  }

  /// The call is healthy again: the next problem starts its own budget.
  void _clearTrouble() => _troubleSince = null;

  Future<void> _recoverStage(
    String reason,
    Object lost,
    bool iceHealthy,
  ) async {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty || !state.isJoined || _terminating || _endingCall) {
      return;
    }
    // Leaving is not losing, and one recovery at a time.
    if (_recoveringStage) return;
    // Already replaced by another path — nothing to recover.
    if (!_mediaService.ownsStage(lost)) return;

    // MEDIA STOPPED, BUT THE PATH IS FINE.
    //
    // Media stopping proves only that nothing is arriving; it does not say
    // whose fault that is. When ICE is still connected, MY transport is
    // healthy and the silence is the other participant leaving, sleeping, or
    // losing their own network. Rebuilding here would tear down my own
    // publication and interrupt everyone else in the call to fix a problem I
    // do not have. Re-resolving who is publishing is the proportionate act,
    // and it is what picks their media back up when they return.
    if (iceHealthy) {
      _reportRecovery(sessionId, 'stage_recovery_resubscribe', 'reason=$reason');
      try {
        await _mediaService.refreshStageRemoteMedia(trigger: 'RECOVER');
      } catch (error) {
        _reportRecovery(
            sessionId, 'stage_recovery_resubscribe_failed', 'err=$error');
      }
      return;
    }

    _recoveringStage = true;

    try {
      for (var attempt = _stageRecoveries + 1;
          attempt <= _stageRecoveryBackoff.length;
          attempt += 1) {
        _stageRecoveries = attempt;
        _reportRecovery(sessionId, 'stage_recovery_start',
            'reason=$reason attempt=$attempt');

        await Future<void>.delayed(_stageRecoveryBackoff[attempt - 1]);
        // Conditions change while backing off: the person may be leaving, or
        // an unrelated path may have re-attached the stage already.
        if (!mounted || !state.isJoined || _terminating || _endingCall) return;
        // MOOT MEANS REPLACED, NOT MERELY PRESENT. This asked
        // `usesStageTransport` -- which is `_stage != null` -- so a DEAD
        // transport still counted as "someone already fixed it" and recovery
        // declared itself unnecessary every single time. Detection worked,
        // recovery never ran, and the call died. Measured 2026-08-28:
        // media_stalled_18s, then stage_recovery_moot three seconds later.
        if (!_mediaService.ownsStage(lost)) {
          _reportRecovery(sessionId, 'stage_recovery_moot',
              'reason=$reason attempt=$attempt');
          _armRecoveryBudgetReset();
          return;
        }

        try {
          await _mediaService.detachStage();
          await _ensureStageConnected('recover');
        } catch (error) {
          _reportRecovery(sessionId, 'stage_recovery_failed',
              'reason=$reason attempt=$attempt err=$error');
          continue;
        }

        if (_mediaService.usesStageTransport) {
          _reportRecovery(sessionId, 'stage_recovery_done',
              'reason=$reason attempt=$attempt');
          _armRecoveryBudgetReset();
          return;
        }
        // attachStage swallowed its own failure and left no stage. Keep going
        // rather than reporting a success that did not happen.
        _reportRecovery(sessionId, 'stage_recovery_incomplete',
            'reason=$reason attempt=$attempt');
      }

      _reportRecovery(sessionId, 'stage_recovery_exhausted',
          'reason=$reason attempts=$_stageRecoveries');
    } finally {
      _recoveringStage = false;
    }
  }

  void _reportRecovery(String sessionId, String code, String message) {
    unawaited(_repository.reportStageDiagnostic(
      sessionId,
      phase: 'recover',
      code: code,
      message: message,
      platform: _clientPlatform,
    ));
  }

  /// GIVE THE BUDGET BACK, BUT ONLY FOR A CALL THAT ACTUALLY RECOVERED.
  ///
  /// A long call that loses its transport once, recovers, and hits an
  /// unrelated problem an hour later should not find its budget already spent.
  /// But a network that flaps -- recover, fail, recover, fail -- must not win
  /// an unlimited supply of attempts by briefly succeeding. Sustained health
  /// is the difference, so the reset waits for it.
  void _armRecoveryBudgetReset() {
    _stageRecoveryReset?.cancel();
    _stageRecoveryReset = Timer(const Duration(seconds: 60), () {
      _stageRecoveries = 0;
    });
  }

  Future<void> _ensureStageConnected(String reason) async {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty) return;
    if (!state.isMediaReady) {
      // THE SILENT CASE. This early return produced no signal at all, and it
      // is the most likely reason a receiver ends up in a connected call with
      // nothing published: no capture, so no attach, so no publish and no
      // subscribe. It is reported rather than merely skipped.
      unawaited(_repository.reportStageDiagnostic(
        sessionId,
        phase: 'attach-skipped',
        code: 'no_local_media',
        message: 'reason=$reason joinState=${state.joinState.name} '
            'participants=${state.participants.length} '
            'mediaError=${state.mediaError ?? 'none'}',
        platform: _clientPlatform,
      ));
      return;
    }
    try {
      final trigger = _stageTrigger(reason);
      if (!_mediaService.usesStageTransport) {
        late final SfuRealtimeTransport transport;
        transport = SfuRealtimeTransport(
          _repository,
          // The transport identifies ITSELF, so recovery can tell whether the
          // thing that died is still the live one.
          onLost: (reason, iceHealthy) =>
              unawaited(_recoverStage(reason, transport, iceHealthy)),
          // REMOTE MEDIA IS ACTUALLY ARRIVING — bytes of inbound RTP, decoded
          // by this device. The strongest evidence a client can produce that
          // these two people can hear each other, and stronger than the
          // renderer-presence check the snapshot path uses.
          onMediaFlowing: (bytes) {
            final id = _managedSessionId;
            if (id.isEmpty || _reportedMediaEstablished) return;
            _reportedMediaEstablished = true;
            unawaited(
              _repository
                  .reportMediaEstablished(
                    id,
                    evidence: 'stage-inbound-rtp-bytes=$bytes',
                  )
                  .catchError((_) {
                    // The person can still hear the other side; what is lost is
                    // the server's ability to mark CONNECTED from this end, and
                    // the next read of the session still carries whatever phase
                    // the backend did reach.
                    _reportedMediaEstablished = false;
                  }),
            );
          },
        );
        await _mediaService.attachStage(
          transport,
          sessionId: sessionId,
          trigger: trigger,
        );
      } else {
        await _mediaService.refreshStageRemoteMedia(trigger: trigger);
      }

    } catch (e) {
      // Never let a transport failure take the call down silently — the
      // product should show honest state rather than a frozen screen. But
      // silent to the USER must not mean invisible to us.
      debugPrint('[rtc] stage connect failed reason=$reason err=$e');
      unawaited(_repository.reportStageDiagnostic(
        sessionId,
        phase: _mediaService.usesStageTransport ? 'refresh' : 'attach',
        code: 'stage_connect_failed',
        message: 'reason=$reason err=$e',
        platform: _clientPlatform,
      ));
    }
  }

  Future<void> _reconcileRtcPeers(
    String reason, {
    bool refreshTurnCredentials = false,
  }) async {
    final sessionId = _managedSessionId;
    if (sessionId.isEmpty || !state.isJoined) return;

    // TRANSPORT IS THE SERVER'S DECISION (§2).
    //
    // A stage session has no peers to reconcile: there is ONE peer connection
    // for the whole call, so the mesh loop below — which builds an offer per
    // remote device — has nothing to do and must not run. Falling through
    // would create mesh peers alongside the stage transport and duplicate both
    // this participant's media and their tile.
    if (state.session?.usesStageTransport ?? false) {
      await _ensureStageConnected(reason);
      return;
    }

    final meSocketId = _socketService.socketId;
    if (meSocketId == null || meSocketId.isEmpty) return;
    final myRaw = _rawSocket(meSocketId);

    // An EXISTING peer is only re-offered on a local media change (a track was
    // added/removed). enabled-toggles don't need SDP renegotiation.
    const renegotiationReasons = {
      'camera-toggle',
      'mic-toggle',
      'screen-toggle',
      'track-change',
    };
    final allowRenegotiate = renegotiationReasons.contains(reason);

    for (final participant in state.participants) {
      final peerSocketId = (participant.runtimeDeviceId ?? '').trim();
      if (peerSocketId.isEmpty) continue; // REST-only roster entry: no live socket
      final peerRaw = _rawSocket(peerSocketId);
      if (peerRaw.isEmpty || peerRaw == myRaw) continue; // self

      final hasPeer = _mediaService.hasPeer(peerSocketId);
      final shouldOffer = !hasPeer || allowRenegotiate;
      if (!shouldOffer) continue;
      if (_pendingOfferTargets.containsKey(peerSocketId)) continue;
      _queueOfferTarget(peerKey: peerSocketId, targetSocketId: peerSocketId);
    }

    if (_pendingOfferTargets.isNotEmpty) {
      await _flushPendingOffers(refreshTurnCredentials: refreshTurnCredentials);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _stopStatsTimer();
    _cancelTurnRefresh();
    _cancelSignalingGrace();
    _connectionWindowTimer?.cancel();
    for (final timer in _peerGraceTimers.values) {
      timer.cancel();
    }
    _peerGraceTimers.clear();
    _subscription?.cancel();
    _mediaSubscription?.cancel();
    _peerHealthSubscription?.cancel();
    // OWNERSHIP: _mediaService and _socketService are app-lifetime singletons
    // owned by their providers (realtimeMediaServiceProvider /
    // realtimeSocketServiceProvider), which dispose them via ref.onDispose at
    // container teardown. This controller must NOT dispose them: when the
    // controller provider rebuilt (TokenStore notifyListeners → ref.watch), the
    // outgoing controller disposed the SHARED services while their providers
    // kept serving the same instances — permanently killing realtime transport
    // for the rest of the app session (root cause of the production
    // 'socket service is disposed' / silent connect no-op failure).
    super.dispose();
  }
}
