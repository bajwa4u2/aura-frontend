import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/session_providers.dart';
import '../../updates/incoming_call_bridge.dart';
import '../../correspondence/data/correspondence_live_service.dart';
import '../domain/realtime_enums.dart';
import '../domain/realtime_state.dart';
import 'realtime_providers.dart';

/// ROOM AND TRANSPORT READINESS — DELIBERATELY NOT THE CALL.
///
/// This describes the state of the media room: whether this device has joined,
/// whether its transport is healthy, whether remote media has arrived. Those
/// are supporting infrastructure facts.
///
/// It is NOT the call lifecycle. It used to have a `connected` member derived
/// from renderers and local media readiness, which made it a second, quieter
/// answer to "are we on a call" — and one that could say yes when nobody had
/// answered, because starting your own camera satisfied it. That member is now
/// `mediaFlowing`, which is what it actually observed.
///
/// The call's own state is `CallState.productStateFor`, projected from the
/// server's Call authority. CLIENT_CALL_STATE_AUTHORITIES = 1.
enum ThreadCallLifecyclePhase {
  invited,
  joining,
  joined,
  mediaNegotiating,
  /// Remote media has arrived in the room. Says nothing about whether a human
  /// answered — that is the Call authority's answer.
  mediaFlowing,
  transportDegraded,
  ended,
}

enum ThreadCallLifecycleSource {
  none,
  incomingSocket,
  foregroundPush,
  caller,
  callee,
  route,
}

class ThreadCallLifecycleState {
  const ThreadCallLifecycleState({
    required this.phase,
    this.sessionId,
    this.userId,
    this.source = ThreadCallLifecycleSource.none,
    this.incomingCall,
    this.errorMessage,
    this.lastEvent,
  });

  final ThreadCallLifecyclePhase phase;
  final String? sessionId;
  final String? userId;
  final ThreadCallLifecycleSource source;
  final Map<String, dynamic>? incomingCall;
  final String? errorMessage;
  final String? lastEvent;

  factory ThreadCallLifecycleState.initial() {
    return const ThreadCallLifecycleState(
      phase: ThreadCallLifecyclePhase.ended,
    );
  }

  ThreadCallLifecycleState copyWith({
    ThreadCallLifecyclePhase? phase,
    String? sessionId,
    bool clearSessionId = false,
    String? userId,
    bool clearUserId = false,
    ThreadCallLifecycleSource? source,
    Map<String, dynamic>? incomingCall,
    bool clearIncomingCall = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? lastEvent,
  }) {
    return ThreadCallLifecycleState(
      phase: phase ?? this.phase,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      userId: clearUserId ? null : (userId ?? this.userId),
      source: source ?? this.source,
      incomingCall: clearIncomingCall
          ? null
          : (incomingCall ?? this.incomingCall),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }

  bool get hasActiveIntent =>
      phase != ThreadCallLifecyclePhase.ended &&
      (sessionId ?? '').trim().isNotEmpty;
}

class ThreadCallLifecycleController
    extends StateNotifier<ThreadCallLifecycleState> {
  ThreadCallLifecycleController(this._ref)
    : super(ThreadCallLifecycleState.initial());

  final Ref _ref;
  final Map<String, Future<void>> _joinFutures = <String, Future<void>>{};

  Future<void> boot() async {
    if (!_isAuthenticatedMember()) return;
    _ref.read(incomingCallBridgeProvider);
    await _ensureCorrespondenceConnected();
  }

  Future<void> onAppResumed() async {
    if (!_isAuthenticatedMember()) return;
    await _ensureCorrespondenceConnected();
    _ref.read(incomingCallBridgeProvider.notifier).evictExpired();
  }

  void syncIncomingCalls(List<Map<String, dynamic>> calls) {
    if (calls.isEmpty) {
      if (state.phase == ThreadCallLifecyclePhase.invited) {
        state = state.copyWith(
          phase: ThreadCallLifecyclePhase.ended,
          clearSessionId: true,
          clearIncomingCall: true,
          clearErrorMessage: true,
          source: ThreadCallLifecycleSource.none,
          lastEvent: 'incoming:cleared',
        );
      }
      return;
    }

    final call = calls.first;
    final sessionId = _sessionIdOf(call);
    if (sessionId.isEmpty) return;
    if (state.sessionId == sessionId &&
        state.phase != ThreadCallLifecyclePhase.ended) {
      return;
    }

    state = state.copyWith(
      phase: ThreadCallLifecyclePhase.invited,
      sessionId: sessionId,
      incomingCall: Map<String, dynamic>.from(call),
      source: _sourceOf(call),
      clearErrorMessage: true,
      lastEvent: 'call:incoming',
    );
  }

  void syncRealtimeState(RealtimeState realtime) {
    if (realtime.session?.surfaceType == RealtimeSurfaceType.meeting) {
      return;
    }

    final sessionId = (realtime.sessionId ?? realtime.session?.id ?? '').trim();
    if (sessionId.isEmpty) {
      if (state.hasActiveIntent &&
          state.phase != ThreadCallLifecyclePhase.invited) {
        state = state.copyWith(
          phase: ThreadCallLifecyclePhase.ended,
          clearSessionId: true,
          clearIncomingCall: true,
          clearErrorMessage: true,
          source: ThreadCallLifecycleSource.none,
          lastEvent: realtime.lastSocketEvent ?? 'realtime:cleared',
        );
      }
      return;
    }

    if (state.sessionId != null &&
        state.sessionId!.isNotEmpty &&
        state.sessionId != sessionId) {
      return;
    }

    final nextPhase = phaseForRealtime(realtime, currentPhase: state.phase);
    state = state.copyWith(
      phase: nextPhase,
      sessionId: nextPhase == ThreadCallLifecyclePhase.ended ? null : sessionId,
      clearSessionId: nextPhase == ThreadCallLifecyclePhase.ended,
      clearUserId: nextPhase == ThreadCallLifecyclePhase.ended,
      clearIncomingCall: nextPhase != ThreadCallLifecyclePhase.invited,
      source: nextPhase == ThreadCallLifecyclePhase.ended
          ? ThreadCallLifecycleSource.none
          : null,
      errorMessage: realtime.errorMessage,
      clearErrorMessage: realtime.errorMessage == null,
      lastEvent: realtime.lastSocketEvent,
    );
  }

  Future<String> startThreadCall({
    required String surfaceType,
    required String surfaceId,
    required String kind,
    required Map<String, dynamic> metadata,
  }) async {
    final userId = _readCurrentUserId();
    final sessionId = await _ref
        .read(realtimeControllerProvider.notifier)
        .ensureCorrespondenceLive(
          surfaceType: surfaceType,
          surfaceId: surfaceId,
          kind: kind,
          metadata: metadata,
          joinAfterCreate: false,
        );
    state = state.copyWith(
      phase: ThreadCallLifecyclePhase.joining,
      sessionId: sessionId,
      userId: userId,
      source: ThreadCallLifecycleSource.caller,
      clearIncomingCall: true,
      clearErrorMessage: true,
      lastEvent: 'thread-call:start',
    );
    _startJoin(sessionId, ThreadCallLifecycleSource.caller);
    return sessionId;
  }

  Future<void> acceptIncomingCall(Map<String, dynamic> payload) async {
    final sessionId = _sessionIdOf(payload);
    if (sessionId.isEmpty) return;
    final userId = _readCurrentUserId();
    state = state.copyWith(
      phase: ThreadCallLifecyclePhase.joining,
      sessionId: sessionId,
      userId: userId,
      incomingCall: Map<String, dynamic>.from(payload),
      source: ThreadCallLifecycleSource.callee,
      clearErrorMessage: true,
      lastEvent: 'thread-call:accept',
    );
    await joinThreadCallSession(
      sessionId,
      source: ThreadCallLifecycleSource.callee,
    );
    // ACCEPTED, not ended. removeBySession() reports the CallKit call ended,
    // which on iOS terminates the very call this method just joined.
    _ref.read(incomingCallBridgeProvider.notifier).clearAccepted(sessionId);
  }

  Future<void> joinThreadCallSession(
    String sessionId, {
    ThreadCallLifecycleSource source = ThreadCallLifecycleSource.route,
  }) async {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty) return;
    final userId = _readCurrentUserId();
    state = state.copyWith(
      phase: ThreadCallLifecyclePhase.joining,
      sessionId: trimmed,
      userId: userId,
      source: source,
      clearErrorMessage: true,
      lastEvent: 'thread-call:join-requested',
    );
    return _startJoin(trimmed, source);
  }

  void handleTerminal(String sessionId, {String? reason}) {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty) return;
    _joinFutures.remove(trimmed);
    _ref.read(incomingCallBridgeProvider.notifier).removeBySession(trimmed);
    if (state.sessionId != trimmed) return;
    state = state.copyWith(
      phase: ThreadCallLifecyclePhase.ended,
      clearSessionId: true,
      clearUserId: true,
      clearIncomingCall: true,
      clearErrorMessage: true,
      source: ThreadCallLifecycleSource.none,
      lastEvent: reason == null || reason.trim().isEmpty
          ? 'call:terminal'
          : 'call:terminal:${reason.trim()}',
    );
  }

  void clearForAuthDrop() {
    final sessionId = state.sessionId ?? '';
    if (sessionId.isNotEmpty) {
      _joinFutures.remove(sessionId);
      _ref.read(incomingCallBridgeProvider.notifier).removeBySession(sessionId);
    }
    state = ThreadCallLifecycleState.initial();
  }

  Future<void> _startJoin(String sessionId, ThreadCallLifecycleSource source) {
    final existing = _joinFutures[sessionId];
    if (existing != null) {
      debugPrint(
        '[join-diag] _startJoin returning EXISTING future for sessionId=$sessionId'
        ' (stale guard candidate if this never resolves)',
      );
      return existing;
    }
    debugPrint('[join-diag] _startJoin starting NEW future sessionId=$sessionId source=$source');

    late final Future<void> future;
    future = _ref
        .read(realtimeControllerProvider.notifier)
        .join(sessionId)
        .then((_) {
          // A SUCCESSFUL JOIN IS THE OPPOSITE OF A TERMINAL EVENT.
          // This fires on every join that works — caller, callee and
          // route alike — so routing it through the terminal choke point
          // meant every connected call reported itself ended to CallKit.
          _ref
              .read(incomingCallBridgeProvider.notifier)
              .clearAccepted(sessionId);
        })
        .catchError((Object error) {
          state = state.copyWith(
            phase: ThreadCallLifecyclePhase.joining,
            errorMessage: error.toString(),
            source: source,
            lastEvent: 'thread-call:join-error',
          );
          throw error;
        })
        .whenComplete(() {
          if (identical(_joinFutures[sessionId], future)) {
            _joinFutures.remove(sessionId);
          }
        });

    _joinFutures[sessionId] = future;
    return future;
  }

  static ThreadCallLifecyclePhase phaseForRealtime(
    RealtimeState realtime, {
    ThreadCallLifecyclePhase currentPhase = ThreadCallLifecyclePhase.ended,
  }) {
    switch (realtime.joinState) {
      case RealtimeJoinState.joining:
        return ThreadCallLifecyclePhase.joining;
      case RealtimeJoinState.joined:
        break;
      case RealtimeJoinState.replaced:
      case RealtimeJoinState.removed:
      case RealtimeJoinState.rejected:
      case RealtimeJoinState.banned:
      case RealtimeJoinState.locked:
      case RealtimeJoinState.failed:
        return ThreadCallLifecyclePhase.ended;
      case RealtimeJoinState.requested:
      case RealtimeJoinState.idle:
        return currentPhase == ThreadCallLifecyclePhase.invited
            ? ThreadCallLifecyclePhase.invited
            : ThreadCallLifecyclePhase.ended;
    }

    if (realtime.connectionStatus == RealtimeConnectionStatus.reconnecting ||
        realtime.connectionStatus == RealtimeConnectionStatus.disconnected ||
        realtime.connectionStatus == RealtimeConnectionStatus.error ||
        realtime.reconnectingUserIds.isNotEmpty) {
      return ThreadCallLifecyclePhase.transportDegraded;
    }

    final presentParticipants = realtime.participants
        .where((participant) => participant.isPresent)
        .length;
    if (presentParticipants <= 1) {
      return ThreadCallLifecyclePhase.joined;
    }
    if (realtime.isMediaBusy) {
      return ThreadCallLifecyclePhase.mediaNegotiating;
    }
    if (realtime.remoteRenderers.isNotEmpty ||
        realtime.remoteRenderersByParticipant.isNotEmpty) {
      // TRANSPORT READINESS, NOT CALL TRUTH. See the doc comment above: this
      // says the room's media is up, which is a supporting fact. Whether the
      // CALL is connected is Call.phase's answer and nothing else's.
      //
      // `isMediaReady` was previously accepted here too. It means the LOCAL
      // camera and microphone started — it says nothing whatever about the
      // remote peer — so a call with no one on the other end reached this
      // branch and called itself connected.
      return ThreadCallLifecyclePhase.mediaFlowing;
    }
    return ThreadCallLifecyclePhase.mediaNegotiating;
  }

  Future<void> _ensureCorrespondenceConnected() async {
    try {
      await _ref.read(correspondenceLiveServiceProvider).ensureConnected();
    } catch (_) {
      // Foreground call ownership is best-effort on transient transport errors;
      // the next app resume or auth transition retries.
    }
  }

  bool _isAuthenticatedMember() {
    final store = _ref.read(tokenStoreProvider);
    final token = store.accessToken?.trim() ?? '';
    return store.isLoaded && token.isNotEmpty && !isGuestAccessToken(token);
  }

  String? _readCurrentUserId() {
    try {
      final me = _ref.read(authMeDataProvider).valueOrNull ?? const {};
      final value =
          me['id'] ??
          me['userId'] ??
          (me['user'] is Map ? (me['user'] as Map)['id'] : null);
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  static String _sessionIdOf(Map<String, dynamic> payload) {
    final data = payload['data'];
    final map = data is Map ? data : const <String, dynamic>{};
    return _firstNonEmpty([
      map['realtimeSessionId'],
      map['sessionId'],
      payload['realtimeSessionId'],
      payload['sessionId'],
    ]);
  }

  static ThreadCallLifecycleSource _sourceOf(Map<String, dynamic> payload) {
    final source = payload['_auraLifecycleSource']?.toString().trim();
    if (source == 'foregroundPush') {
      return ThreadCallLifecycleSource.foregroundPush;
    }
    return ThreadCallLifecycleSource.incomingSocket;
  }

  static String _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

final threadCallLifecycleProvider =
    StateNotifierProvider<
      ThreadCallLifecycleController,
      ThreadCallLifecycleState
    >((ref) {
      final controller = ThreadCallLifecycleController(ref);

      ref.read(incomingCallBridgeProvider);

      ref.listen<bool>(isAuthedProvider, (previous, next) {
        if (next && !(previous ?? false)) {
          unawaited(controller.boot());
        }
        if ((previous ?? false) && !next) {
          controller.clearForAuthDrop();
        }
      });

      ref.listen<List<Map<String, dynamic>>>(
        incomingCallBridgeProvider,
        (_, next) => controller.syncIncomingCalls(next),
      );

      ref.listen<RealtimeState>(
        realtimeControllerProvider,
        (_, next) => controller.syncRealtimeState(next),
      );

      unawaited(controller.boot());
      return controller;
    });
