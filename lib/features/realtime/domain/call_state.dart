import 'package:flutter/foundation.dart';

/// WHERE A CALL ACTUALLY IS.
///
/// Mirrors the backend's `CallPhase` exactly, and is the only call-state
/// vocabulary the client is allowed to use. Aura previously had no such thing:
/// each surface assembled its own answer out of whatever was nearest — a socket
/// being open, a roster having two rows, a route being mounted, a local camera
/// having started — and they disagreed with each other and with the server.
///
/// The order matters. A call moves forward or it ends.
enum CallPhase {
  /// Someone asked for a conversation. Nothing has rung.
  initiated,

  /// An invitation exists. Still nothing has rung.
  invited,

  /// A device actually presented the call and began alerting a person. This,
  /// and only this, is "Ringing".
  alerting,

  /// A person deliberately answered. Not a connection.
  accepted,

  /// Answered, and the media path is being established.
  connecting,

  /// Both sides have a usable media path. The duration clock starts here.
  connected,

  /// Over.
  ended,
}

/// WHY A CALL ENDED. Mirrors the backend's `CallOutcome`.
enum CallOutcome {
  declined,

  /// Their phone genuinely rang and nobody answered.
  missed,

  /// Nothing ever rang them. Deliberately NOT [missed] — telling someone they
  /// ignored a call their phone never announced is a lie about them.
  notPresented,

  canceledBeforeAnswer,

  /// They answered, but no usable media path was ever established.
  acceptedNotConnected,

  failed,

  /// A conversation that actually happened.
  connectedEnded,

  /// A call recorded before this authority existed.
  unknownLegacy,
}

/// WHAT A PERSON IS ACTUALLY LOOKING AT.
///
/// The phase says where the call is; this says what to show, which is not the
/// same question — the same phase reads differently depending on which end of
/// the call you are on. ALERTING is "Ringing…" to the caller and an incoming
/// call to the person being rung.
///
/// Derived ONCE, here, and consumed by web, Android, iOS and Windows alike.
/// Aura previously had no such thing, so each surface assembled its own answer
/// from whatever was nearest — a socket being open, a roster having two rows, a
/// route being mounted — and they disagreed with each other and with the
/// server. `CLIENT_CALL_STATE_AUTHORITIES = 1` means this enum is the only
/// vocabulary a call surface may branch on.
enum CallProductState {
  /// Placed, nothing has rung. The caller's "Calling…".
  calling,

  /// A real device is really alerting a real person. The caller sees
  /// "Ringing…"; the callee is being offered the call.
  ringing,

  /// Incoming, from the callee's side, before they have answered.
  incoming,

  /// Answered by a human; the media path is still being established.
  connecting,

  /// Both sides have a usable media path. The only state with a timer.
  connected,

  /// Over. [CallState.outcome] says why.
  ended,
}

/// ONE PERSON IN A CALL — never a device.
///
/// Someone with a phone, a laptop and a tablet is one participant. Their
/// devices are the backend's business; what reaches the client is what the
/// PERSON did.
@immutable
class CallParticipantState {
  const CallParticipantState({
    required this.userId,
    required this.isCaller,
    this.alertedAt,
    this.acceptedAt,
    this.declinedAt,
  });

  final String userId;
  final bool isCaller;

  /// The first moment any of this person's devices began alerting them.
  final DateTime? alertedAt;
  final DateTime? acceptedAt;

  /// An explicit human refusal. A phone that failed to ring never sets this.
  final DateTime? declinedAt;

  static CallParticipantState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    final userId = (json['userId'] ?? '').toString().trim();
    if (userId.isEmpty) return null;
    return CallParticipantState(
      userId: userId,
      isCaller: (json['role'] ?? '').toString().trim().toUpperCase() == 'CALLER',
      alertedAt: _date(json['alertedAt']),
      acceptedAt: _date(json['acceptedAt']),
      declinedAt: _date(json['declinedAt']),
    );
  }
}

/// THE CALL, AS THE SERVER RECORDED IT.
///
/// Every field is a fact the backend wrote down, never something the client
/// worked out. `CLIENT_CALL_STATE_AUTHORITIES = 1` means: if a surface wants to
/// know whether a call is ringing, connected or over, it reads this — it does
/// not consult the socket, the roster, the renderers or the route.
///
/// Absent (`null`) means "this session is not a call" — a meeting, a stage —
/// which is a different thing from a call that has not connected yet, and the
/// two must not be collapsed.
@immutable
class CallState {
  const CallState({
    required this.id,
    required this.phase,
    required this.initiatorUserId,
    this.outcome,
    this.isVideo = false,
    this.initiatedAt,
    this.ringPresentedAt,
    this.acceptedAt,
    this.connectedAt,
    this.endedAt,
    this.participants = const [],
  });

  final String id;
  final CallPhase phase;
  final CallOutcome? outcome;
  final String initiatorUserId;
  final bool isVideo;

  final DateTime? initiatedAt;

  /// When a real device began alerting a real person. The caller is entitled to
  /// see "Ringing" from this moment and not before.
  final DateTime? ringPresentedAt;
  final DateTime? acceptedAt;

  /// THE ONLY LEGITIMATE START FOR A DURATION CLOCK.
  ///
  /// Written once by the backend, and only when both sides of the conversation
  /// have reported a usable media path. Everything the client used to anchor on
  /// — `startedAt`, `answeredAt`, `DateTime.now()` at mount — was set when the
  /// ROOM opened, which is why the clock used to run while the other phone was
  /// still ringing.
  final DateTime? connectedAt;

  final DateTime? endedAt;
  final List<CallParticipantState> participants;

  bool get isRinging => phase == CallPhase.alerting;
  bool get isConnected => phase == CallPhase.connected;
  bool get hasEnded => phase == CallPhase.ended;

  /// THE ONE PROJECTION EVERY SURFACE READS.
  ///
  /// Takes the recorded phase and the viewer's side of the call, and returns
  /// what that person is looking at. Nothing else in the client may decide
  /// this — not from a session being ACTIVE, a join state, a mounted route, a
  /// live socket, or a notification having arrived. Those are infrastructure
  /// facts; they can support a call but they are not one.
  CallProductState productStateFor(String viewerUserId) {
    final viewerIsCaller = isCaller(viewerUserId);
    switch (phase) {
      case CallPhase.initiated:
      case CallPhase.invited:
        // Nothing has rung yet. To the caller this is "Calling…"; the callee
        // has not been alerted, so there is nothing to show them at all.
        return viewerIsCaller ? CallProductState.calling : CallProductState.incoming;
      case CallPhase.alerting:
        return viewerIsCaller ? CallProductState.ringing : CallProductState.incoming;
      case CallPhase.accepted:
      case CallPhase.connecting:
        return CallProductState.connecting;
      case CallPhase.connected:
        return CallProductState.connected;
      case CallPhase.ended:
        return CallProductState.ended;
    }
  }

  /// Whether a duration should be running at all.
  ///
  /// CALLING_TIMER = 0, RINGING_TIMER = 0, CONNECTING_TIMER = 0.
  /// A clock that runs before a conversation exists is a lie about how long
  /// people have been talking.
  bool get hasRunningTimer => phase == CallPhase.connected;

  /// Whether this person still has an answer/decline decision to make.
  bool canAnswer(String viewerUserId) =>
      !isCaller(viewerUserId) &&
      phase == CallPhase.alerting &&
      participantOf(viewerUserId)?.acceptedAt == null &&
      participantOf(viewerUserId)?.declinedAt == null;

  /// True once a human has agreed to talk, whatever the media is doing.
  bool get isAccepted =>
      phase == CallPhase.accepted ||
      phase == CallPhase.connecting ||
      phase == CallPhase.connected;

  /// How long the conversation has been going, or null when there has not been
  /// one. A declined, missed or canceled call has no duration rather than a
  /// fabricated one.
  Duration? durationAt(DateTime now) {
    final started = connectedAt;
    if (started == null) return null;
    final end = endedAt ?? now;
    final d = end.difference(started);
    return d.isNegative ? Duration.zero : d;
  }

  CallParticipantState? participantOf(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return null;
    for (final p in participants) {
      if (p.userId == id) return p;
    }
    return null;
  }

  /// Whether [userId] placed this call. Which side of the call a person is on
  /// decides what they should be shown — "Ringing" is a caller's word and
  /// "Incoming" is a callee's — so it is read from the recorded initiator, not
  /// from who happens to have arrived first.
  bool isCaller(String userId) =>
      userId.trim().isNotEmpty && userId.trim() == initiatorUserId;

  static CallState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    final id = (json['id'] ?? '').toString().trim();
    final phase = _phase(json['phase']);
    if (id.isEmpty || phase == null) return null;

    return CallState(
      id: id,
      phase: phase,
      outcome: _outcome(json['outcome']),
      initiatorUserId: (json['initiatorUserId'] ?? '').toString().trim(),
      isVideo: (json['kind'] ?? '').toString().trim().toUpperCase() == 'VIDEO',
      initiatedAt: _date(json['initiatedAt']),
      ringPresentedAt: _date(json['ringPresentedAt']),
      acceptedAt: _date(json['acceptedAt']),
      connectedAt: _date(json['connectedAt']),
      endedAt: _date(json['endedAt']),
      participants: [
        for (final entry in (json['participants'] as List?) ?? const [])
          CallParticipantState.fromJson(entry),
      ].whereType<CallParticipantState>().toList(growable: false),
    );
  }

  /// Apply a `call:phase` broadcast onto the call we already hold.
  ///
  /// The broadcast is a PROJECTION of a decision the server already committed,
  /// so it is applied as-is — but only forwards. These events arrive over an
  /// unreliable transport, out of order and more than once, and a late
  /// "connecting" must never pull a connected conversation backwards.
  CallState applyPhaseEvent(Map<String, dynamic> json) {
    final next = _phase(json['phase']);
    if (next == null) return this;
    if (next.index < phase.index) return this;

    return CallState(
      id: id,
      phase: next,
      outcome: _outcome(json['outcome']) ?? outcome,
      initiatorUserId: initiatorUserId,
      isVideo: isVideo,
      initiatedAt: initiatedAt,
      ringPresentedAt: ringPresentedAt ??
          (next == CallPhase.alerting ? DateTime.now() : null),
      acceptedAt: acceptedAt,
      // First-write-wins, matching the backend: a repeat cannot move the moment
      // a conversation began.
      connectedAt: connectedAt ?? _date(json['connectedAt']),
      endedAt: endedAt ?? (next == CallPhase.ended ? DateTime.now() : null),
      participants: participants,
    );
  }

  static CallPhase? _phase(Object? raw) {
    switch ((raw ?? '').toString().trim().toUpperCase()) {
      case 'INITIATED':
        return CallPhase.initiated;
      case 'INVITED':
        return CallPhase.invited;
      case 'ALERTING':
        return CallPhase.alerting;
      case 'ACCEPTED':
        return CallPhase.accepted;
      case 'CONNECTING':
        return CallPhase.connecting;
      case 'CONNECTED':
        return CallPhase.connected;
      case 'ENDED':
        return CallPhase.ended;
      default:
        // An unknown phase is not guessed at. Holding the phase we already have
        // is honest; inventing one is how a call comes to claim it connected.
        return null;
    }
  }

  static CallOutcome? _outcome(Object? raw) {
    switch ((raw ?? '').toString().trim().toUpperCase()) {
      case 'DECLINED':
        return CallOutcome.declined;
      case 'MISSED':
        return CallOutcome.missed;
      case 'NOT_PRESENTED':
        return CallOutcome.notPresented;
      case 'CANCELED_BEFORE_ANSWER':
        return CallOutcome.canceledBeforeAnswer;
      case 'ACCEPTED_NOT_CONNECTED':
        return CallOutcome.acceptedNotConnected;
      case 'FAILED':
        return CallOutcome.failed;
      case 'CONNECTED_ENDED':
        return CallOutcome.connectedEnded;
      case 'UNKNOWN_LEGACY':
        return CallOutcome.unknownLegacy;
      default:
        return null;
    }
  }
}

/// Parse an instant, WITHOUT converting it to local time.
///
/// Nothing here displays a wall-clock time — a call's timestamps exist to be
/// subtracted from one another, and `DateTime.difference` is correct across
/// zones. Localising in the model would be new temporal drift for no benefit;
/// where a call time is ever shown to a person, the temporal authority does
/// that conversion at the point of presentation, once.
DateTime? _date(Object? raw) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}
