/// Realtime Architecture Correction — Phase 0 canonical contract.
///
/// State precedence / invalidation rules. Dart mirror of
/// aura-backend/src/realtime/canonical/precedence.ts. Governs what
/// happens when an incoming signal might be STALE relative to already-
/// applied state — the exact class of bug this chapter chased (a stale
/// join-failure outliving a real connected, a stale participant-left
/// outliving a real reconnect, etc).
///
/// PHASE 0 SCOPE: pure, isolated, not wired into production.
library;

import 'participant_lifecycle.dart';
import 'session_lifecycle.dart';

class SequencedParticipantEvent {
  final int sequence;
  final CanonicalParticipantStatus status;

  const SequencedParticipantEvent({required this.sequence, required this.status});
}

class ParticipantReconciliationState {
  final CanonicalParticipantStatus status;
  final int lastAppliedSequence;

  const ParticipantReconciliationState({
    required this.status,
    required this.lastAppliedSequence,
  });
}

class ParticipantReconciliationResult {
  final bool applied;
  final ParticipantReconciliationState next;
  final String? reason;

  const ParticipantReconciliationResult({
    required this.applied,
    required this.next,
    this.reason,
  });
}

/// The single reconciliation entry point every participant-status write
/// must pass through. Encodes every invariant named in Part E: a stale
/// join-failure cannot outlive a newer connected; expired cannot
/// override accepted-or-later; duplicate delivery is a safe no-op;
/// terminal is absorbing.
ParticipantReconciliationResult reconcileParticipantEvent(
  ParticipantReconciliationState current,
  SequencedParticipantEvent incoming,
) {
  if (incoming.sequence == current.lastAppliedSequence && incoming.status == current.status) {
    return ParticipantReconciliationResult(
      applied: false,
      next: current,
      reason: 'duplicate_delivery',
    );
  }

  if (incoming.sequence < current.lastAppliedSequence) {
    return ParticipantReconciliationResult(
      applied: false,
      next: current,
      reason: 'stale_out_of_order',
    );
  }

  if (isTerminalParticipantStatus(current.status)) {
    return ParticipantReconciliationResult(
      applied: false,
      next: current,
      reason: 'already_terminal',
    );
  }

  if (incoming.status == CanonicalParticipantStatus.expired &&
      current.status != CanonicalParticipantStatus.invited) {
    return ParticipantReconciliationResult(
      applied: false,
      next: current,
      reason: 'expired_after_accept_rejected',
    );
  }

  return ParticipantReconciliationResult(
    applied: true,
    next: ParticipantReconciliationState(
      status: incoming.status,
      lastAppliedSequence: incoming.sequence,
    ),
  );
}

class SequencedSessionEvent {
  final int sequence;
  final CanonicalSessionStatus status;

  const SequencedSessionEvent({required this.sequence, required this.status});
}

class SessionReconciliationState {
  final CanonicalSessionStatus status;
  final int lastAppliedSequence;

  const SessionReconciliationState({required this.status, required this.lastAppliedSequence});
}

class SessionReconciliationResult {
  final bool applied;
  final SessionReconciliationState next;
  final String? reason;

  const SessionReconciliationResult({required this.applied, required this.next, this.reason});
}

/// Session-level counterpart. Protects the session-status axis from
/// stale/out-of-order writes. Does NOT itself reach into participant
/// state — enforcing "ended cannot coexist with active joining" is a
/// caller-level (Phase 1 production orchestration) obligation.
SessionReconciliationResult reconcileSessionEvent(
  SessionReconciliationState current,
  SequencedSessionEvent incoming,
) {
  if (incoming.sequence == current.lastAppliedSequence && incoming.status == current.status) {
    return SessionReconciliationResult(applied: false, next: current, reason: 'duplicate_delivery');
  }
  if (incoming.sequence < current.lastAppliedSequence) {
    return SessionReconciliationResult(applied: false, next: current, reason: 'stale_out_of_order');
  }
  if (isTerminalSessionStatus(current.status)) {
    return SessionReconciliationResult(applied: false, next: current, reason: 'already_terminal');
  }
  return SessionReconciliationResult(
    applied: true,
    next: SessionReconciliationState(
      status: incoming.status,
      lastAppliedSequence: incoming.sequence,
    ),
  );
}
