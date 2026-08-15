/// Realtime Architecture Correction — Phase 0 canonical contract.
///
/// SESSION-LEVEL lifecycle truth. Dart mirror of
/// aura-backend/src/realtime/canonical/session-lifecycle.ts — kept in
/// lockstep with that file; do not let the two drift. Deliberately
/// separate from ParticipantStatus (see participant_lifecycle.dart) — a
/// session may remain active while individual participants decline,
/// expire, accept, join, reconnect, or leave.
///
/// PHASE 0 SCOPE: this file is pure, isolated, and NOT imported by any
/// production code path (deliberately placed under lib/core/ rather than
/// lib/features/realtime/ to make an accidental production import
/// visually obvious in review). It defines the target contract and is
/// proven by the tests in test/realtime_canonical/. Phase 1 wires this
/// into RealtimeController/RealtimeSocketService — that wiring does not
/// happen here.
///
/// RINGING is deliberately NOT a session-level state — it is derived:
/// a session "has ringing invitations" if any participant is invited.
library;

enum CanonicalSessionStatus {
  /// Session exists; no participant has reached accepted yet.
  created,
  /// At least one participant is accepted or later.
  active,
  /// Optional transient teardown state. May be skipped.
  ending,
  /// Terminal — natural or explicit conclusion, or created with zero accepts (missed/no-answer).
  ended,
  /// Terminal — caller withdrew before any participant ever reached accepted.
  cancelled,
  /// Terminal — genuine SESSION-LEVEL failure (e.g. transport/media
  /// infrastructure could not be provisioned for the session itself).
  ///
  /// FROZEN DOCTRINE (2026-08-14, founder decision, Phase 0 closeout):
  /// SESSION FAILED != PARTICIPANT FAILED/JOIN_FAILED. A single
  /// participant's [CanonicalParticipantStatus.failed] must NEVER by
  /// itself transition the session to this status — see that enum's
  /// matching doctrine comment. [evaluateSessionActivity] deliberately
  /// has no path deriving this status from participant state; it only
  /// ever derives [CanonicalSessionStatus.ended]. Even when every
  /// participant in a session ends up individually failed, that remains
  /// an ended outcome ("no one could connect"), not a session-level
  /// failure — a genuine session FAILED is an explicit caller decision
  /// via [applySessionTransition], never automatic.
  failed,
}

const Set<CanonicalSessionStatus> terminalSessionStatuses = {
  CanonicalSessionStatus.ended,
  CanonicalSessionStatus.cancelled,
  CanonicalSessionStatus.failed,
};

bool isTerminalSessionStatus(CanonicalSessionStatus status) =>
    terminalSessionStatuses.contains(status);

/// Legal transition map. A transition not listed here is illegal. Sole
/// source of truth for session-level legality.
///
/// FROZEN DOCTRINE, amended 2026-08-12 (Realtime Architecture Correction —
/// Phase 3, amended Gate 2). `active -> cancelled` added — mirrors
/// `aura-backend/src/realtime/canonical/session-lifecycle.ts`'s matching
/// amendment exactly; see that file's doc comment for the full mechanical
/// proof (production `RealtimeSession` rows are created already ACTIVE,
/// with the host auto-accepted, so canonical `created` is never actually
/// reached — the original `created -> cancelled`-only edge made
/// `cancelled` unreachable in production). Do not let this file drift
/// from the backend original.
final Map<CanonicalSessionStatus, Set<CanonicalSessionStatus>> sessionTransitions = {
  CanonicalSessionStatus.created: {
    CanonicalSessionStatus.active,
    CanonicalSessionStatus.cancelled,
    CanonicalSessionStatus.ended,
    CanonicalSessionStatus.failed,
  },
  CanonicalSessionStatus.active: {
    CanonicalSessionStatus.ending,
    CanonicalSessionStatus.ended,
    CanonicalSessionStatus.cancelled,
    CanonicalSessionStatus.failed,
  },
  CanonicalSessionStatus.ending: {
    CanonicalSessionStatus.ended,
    CanonicalSessionStatus.failed,
  },
  // Terminal states have no outgoing transitions.
};

class SessionTransitionResult {
  final bool ok;
  final CanonicalSessionStatus status;
  final String? error;

  const SessionTransitionResult({required this.ok, required this.status, this.error});
}

/// Pure transition function — sole authority for whether `from -> to` is
/// legal. Terminal states are absorbing.
SessionTransitionResult applySessionTransition(
  CanonicalSessionStatus from,
  CanonicalSessionStatus to,
) {
  if (isTerminalSessionStatus(from)) {
    return SessionTransitionResult(
      ok: false,
      status: from,
      error: 'Session already terminal ($from); cannot transition to $to.',
    );
  }
  final legal = sessionTransitions[from];
  if (legal == null || !legal.contains(to)) {
    return SessionTransitionResult(
      ok: false,
      status: from,
      error: 'Illegal session transition: $from -> $to.',
    );
  }
  return SessionTransitionResult(ok: true, status: to);
}

class SessionActivityEvaluation {
  final CanonicalSessionStatus? shouldTransitionTo;

  const SessionActivityEvaluation({this.shouldTransitionTo});
}

/// Multi-party aggregate evaluator — the canonical, pure generalization of
/// the backend's `maybeEndIdleSession`. Rule (frozen): a session may
/// become terminal only when no participant remains accepted-or-later AND
/// no invite remains actionable.
SessionActivityEvaluation evaluateSessionActivity({
  required CanonicalSessionStatus currentStatus,
  required bool hasActiveOrRecoverableParticipant,
  required bool hasActionableInvite,
}) {
  if (isTerminalSessionStatus(currentStatus)) {
    return const SessionActivityEvaluation();
  }
  if (hasActiveOrRecoverableParticipant || hasActionableInvite) {
    return const SessionActivityEvaluation();
  }
  return const SessionActivityEvaluation(shouldTransitionTo: CanonicalSessionStatus.ended);
}
