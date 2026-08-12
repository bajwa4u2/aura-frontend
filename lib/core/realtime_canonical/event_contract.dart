/// Realtime Architecture Correction — Phase 0 canonical contract, Part D.
///
/// Dart mirror of aura-backend/src/realtime/canonical/event-contract.ts.
/// Typed canonical realtime event contract + legacy event compatibility
/// map. PHASE 0 SCOPE: type definitions and the mapping table only — no
/// socket wiring, no dual-emit implementation.
library;

enum CanonicalRealtimeEvent {
  sessionCreated,
  inviteIssued,
  inviteRinging,
  inviteAccepted,
  inviteDeclined,
  inviteExpired,
  sessionCancelled,
  participantJoining,
  participantConnected,
  participantTransportLost,
  participantReconnected,
  participantLeft,
  sessionEnding,
  sessionEnded,
  joinFailed,
}

/// Every canonical event carries these identity fields at minimum.
class CanonicalEventEnvelope<TPayload> {
  final CanonicalRealtimeEvent name;
  final String sessionId;
  /// Present for participant-scoped events; absent for pure session-scoped events.
  final String? participantId;
  /// The user who caused this event, where meaningful.
  final String? actorUserId;
  /// The user this event is ABOUT, where different from the actor.
  final String? subjectUserId;
  final String? deviceId;
  final String? socketId;
  /// Monotonic, per-(sessionId, participantId) — see precedence.dart.
  final int sequence;
  /// True if this event is written to a durable log before/as it is broadcast.
  final bool durable;
  /// True if replaying this event against current state is safe (idempotent).
  final bool replayable;
  final TPayload payload;

  const CanonicalEventEnvelope({
    required this.name,
    required this.sessionId,
    this.participantId,
    this.actorUserId,
    this.subjectUserId,
    this.deviceId,
    this.socketId,
    required this.sequence,
    required this.durable,
    required this.replayable,
    required this.payload,
  });
}

enum LegacyEventDisposition {
  keep,
  narrow,
  rename,
  dualEmitTemporarily,
  retire,
}

class LegacyEventMapping {
  final String legacyName;
  final LegacyEventDisposition disposition;
  final CanonicalRealtimeEvent? canonical;
  final String notes;

  const LegacyEventMapping({
    required this.legacyName,
    required this.disposition,
    required this.canonical,
    required this.notes,
  });
}

/// The classification the architecture doc's Part D asked for — kept in
/// lockstep with the backend's LEGACY_EVENT_MAP (event-contract.ts). This
/// table is the compatibility-contract source of truth for Phase 2's
/// dual-emit work; Phase 0 does not implement dual-emit.
const List<LegacyEventMapping> legacyEventMap = [
  LegacyEventMapping(
    legacyName: 'call:accepted',
    disposition: LegacyEventDisposition.dualEmitTemporarily,
    canonical: CanonicalRealtimeEvent.inviteAccepted,
    notes:
        'Already correctly scoped and already documented as "not proof of connection" in code. Rename target is semantic clarity only.',
  ),
  LegacyEventMapping(
    legacyName: 'call:declined',
    disposition: LegacyEventDisposition.dualEmitTemporarily,
    canonical: CanonicalRealtimeEvent.inviteDeclined,
    notes:
        'Existing client handler only reconciles when isJoined==true (a proven gap). Canonical handling in Phase 3 must close this, not just rename the event.',
  ),
  LegacyEventMapping(
    legacyName: 'call:terminal',
    disposition: LegacyEventDisposition.narrow,
    canonical: null,
    notes:
        'Overloaded across HOST_ENDED/AUTO_ENDED/NO_ANSWER/EXPIRED via a free-form reason field. NARROW means: split into sessionEnded (host/auto end) and inviteExpired (no-answer/expiry) as separate canonical events.',
  ),
  LegacyEventMapping(
    legacyName: 'session:participant.joined',
    disposition: LegacyEventDisposition.rename,
    canonical: CanonicalRealtimeEvent.participantConnected,
    notes:
        'Tighten on rename: canonical participantConnected must mean BOTH transport AND media proof, not just socket join.',
  ),
  LegacyEventMapping(
    legacyName: 'session:participant.left',
    disposition: LegacyEventDisposition.narrow,
    canonical: CanonicalRealtimeEvent.participantLeft,
    notes:
        'NARROW: today fires for BOTH transient transport drops and definitive departure, distinguished only by an often-ignored reason field. Canonical participantLeft must fire ONLY for definitive departure.',
  ),
  LegacyEventMapping(
    legacyName: 'CALL_RINGING',
    disposition: LegacyEventDisposition.retire,
    canonical: CanonicalRealtimeEvent.inviteRinging,
    notes:
        'Retire as a client-business-logic-visible payload type once the notification-projection layer is the sole consumer.',
  ),
  LegacyEventMapping(
    legacyName: 'CALL_CANCELLED',
    disposition: LegacyEventDisposition.retire,
    canonical: CanonicalRealtimeEvent.sessionCancelled,
    notes: 'Same retirement path as CALL_RINGING.',
  ),
  LegacyEventMapping(
    legacyName: 'session:ended',
    disposition: LegacyEventDisposition.dualEmitTemporarily,
    canonical: CanonicalRealtimeEvent.sessionEnded,
    notes:
        'Already reasonably well-scoped; rename target is consolidation with call:terminal\'s HOST_ENDED/AUTO_ENDED cases so there is exactly one terminal-session event, not two competing ones.',
  ),
];
