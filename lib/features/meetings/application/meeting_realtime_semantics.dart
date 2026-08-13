import '../../realtime/domain/realtime_enums.dart';

/// Realtime Architecture Correction — Phase 7, Meetings realtime
/// orchestration (frontend piece).
///
/// The frontend equivalent of the backend's `MeetingRealtimeOrchestratorService`
/// seam: `RealtimeController` is generic transport/lifecycle machinery
/// shared by Thread/DM/Space/Institution-Room/Meeting calls alike. Before
/// this chapter, a handful of genuinely Meeting-specific PRODUCT decisions
/// (not mere presentation) were open-coded inline as `if (isMeeting) {...}`
/// directly inside `RealtimeController`'s private state-transition methods —
/// this is the "generic realtime machinery knows Meeting product semantics"
/// problem Phase 7 exists to reconcile.
///
/// This class is the MINIMUM adapter contract: pure, stateless, testable
/// DECISION functions only. `RealtimeController` still owns and mutates its
/// own state (that coupling is legitimate and not moved — a Flutter
/// StateNotifier's private state machine cannot safely be externalized
/// without a much larger, higher-risk rewrite of a protected live-call
/// surface) — it now calls out to this class to ask "does Meeting-specific
/// behavior apply here" instead of inlining the surface-type check itself.
/// The AUTHORITY for what counts as Meeting-specific behavior lives here,
/// once, documented and tested — not scattered across `RealtimeController`.
///
/// Deliberately NOT migrated here: the many presentation-only
/// `isMeeting ? 'meeting text' : 'call text'` string/icon selections
/// throughout `realtime_controller.dart` and `realtime_room_screen.dart` —
/// per the founder's own explicit instruction, "the objective is authority
/// separation, not branch-count reduction," and these have zero lifecycle
/// authority implications. See the Phase 7 frontend classification in
/// `capability/AURA_RELEASE_CLIENT_CONSOLIDATED_ROADMAP.md` for the full
/// inventory and disposition of every occurrence.
class MeetingRealtimeSemantics {
  const MeetingRealtimeSemantics._();

  /// Meeting guests are not DB `RealtimeSessionParticipant` rows, so the
  /// member REST join (`POST /realtime/sessions/:id/join`, strict
  /// `@CurrentUserId`) 401s for them. A REST join failure must not abort
  /// the attempt for meetings — the socket `session:join` handshake that
  /// follows is authoritative for them instead (it registers guests
  /// in-memory and broadcasts). Thread/DM/Space calls have no guest
  /// concept, so a REST join failure there is a real, fatal error.
  static bool tolerateRestJoinFailure(RealtimeSurfaceType? surfaceType) {
    return surfaceType == RealtimeSurfaceType.meeting;
  }

  /// Reconnect grace: an involuntary transient drop (socket disconnect or
  /// missed heartbeat) does not immediately empty a Meeting seat — the
  /// participant stays on the roster while the grace window runs, since
  /// media often keeps flowing through a brief signaling blip. Thread/DM/
  /// Space calls do not currently get this grace (an already-approved,
  /// separately-scoped future generalization per the frozen architecture
  /// document's §4/§10 — NOT this phase's job to extend).
  static bool appliesReconnectGraceOnParticipantLeft({
    required RealtimeSurfaceType? surfaceType,
    required String leftReason,
  }) {
    final isMeeting = surfaceType == RealtimeSurfaceType.meeting;
    final transientDrop =
        leftReason == 'disconnect' || leftReason == 'heartbeat_timeout';
    return isMeeting && transientDrop;
  }

  /// When the room empties to one remaining participant, a Meeting waits
  /// (the room-empties decision runs only after grace expires — a
  /// transient drop never ends the meeting for whoever stayed); a
  /// Thread/DM/Space call ends immediately instead.
  static bool waitsForParticipantReturnWhenAlone(
    RealtimeSurfaceType? surfaceType,
  ) {
    return surfaceType == RealtimeSurfaceType.meeting;
  }

  /// A `session:stale` (heartbeat-timeout-imminent) signal is suppressed
  /// for Meetings — the same reconnect-grace doctrine as above, applied to
  /// this specific socket event, rather than tearing down the session.
  static bool suppressesStaleDisconnectSignal(
    RealtimeSurfaceType? surfaceType,
  ) {
    return surfaceType == RealtimeSurfaceType.meeting;
  }

  /// A `session:ended` event is discarded as stale/out-of-order for a
  /// Meeting when its payload's own reason/callState says the session is
  /// actually still active (`ACCEPTED`/`ACTIVE`) — an ended event racing
  /// behind a later accept must not tear down a call that has since
  /// connected. Thread/DM/Space calls do not currently get this
  /// precedence guard.
  static bool discardsOutOfOrderEndedEvent({
    required RealtimeSurfaceType? surfaceType,
    required String terminalReason,
    required String terminalCallState,
  }) {
    final isMeeting = surfaceType == RealtimeSurfaceType.meeting;
    final stillActive = terminalReason == 'ACCEPTED' || terminalCallState == 'ACTIVE';
    return isMeeting && stillActive;
  }
}
