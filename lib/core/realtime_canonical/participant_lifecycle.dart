/// Realtime Architecture Correction — Phase 0 canonical contract.
///
/// PARTICIPANT-LEVEL lifecycle truth — one instance per (session, user).
/// Dart mirror of aura-backend/src/realtime/canonical/participant-lifecycle.ts.
/// Deliberately separate from device/socket binding (see
/// device_socket_binding.dart): SOCKET LEAVE != PARTICIPANT LEFT.
///
/// PHASE 0 SCOPE: pure, isolated, not imported by production code.
library;

enum CanonicalParticipantStatus {
  /// Invite created, pending, not yet responded. "Ringing" presentation IS this state.
  invited,
  /// Durable accept committed (first-action-wins). Does NOT mean connected.
  accepted,
  /// Transport/media establishment in progress, following accepted.
  joining,
  /// Transport AND media proven.
  connected,
  /// Transport lost, within the durable reconnect-grace window. Not terminal.
  temporarilyDisconnected,
  /// Terminal — explicit decline.
  declined,
  /// Terminal — invite TTL passed without response.
  expired,
  /// Terminal — definitive departure: explicit leave, grace window exceeded, or host removal.
  left,
  /// Terminal — joining exceeded its recovery deadline without reaching connected.
  failed,
}

const Set<CanonicalParticipantStatus> terminalParticipantStatuses = {
  CanonicalParticipantStatus.declined,
  CanonicalParticipantStatus.expired,
  CanonicalParticipantStatus.left,
  CanonicalParticipantStatus.failed,
};

bool isTerminalParticipantStatus(CanonicalParticipantStatus status) =>
    terminalParticipantStatuses.contains(status);

/// True for states that count as "still holding a seat" for
/// session-activity purposes (session_lifecycle.dart's evaluateSessionActivity).
bool isActiveOrRecoverableParticipantStatus(CanonicalParticipantStatus status) {
  return status == CanonicalParticipantStatus.accepted ||
      status == CanonicalParticipantStatus.joining ||
      status == CanonicalParticipantStatus.connected ||
      status == CanonicalParticipantStatus.temporarilyDisconnected;
}

final Map<CanonicalParticipantStatus, Set<CanonicalParticipantStatus>> participantTransitions = {
  CanonicalParticipantStatus.invited: {
    CanonicalParticipantStatus.accepted,
    CanonicalParticipantStatus.declined,
    CanonicalParticipantStatus.expired,
    CanonicalParticipantStatus.left, // e.g. host removes an un-responded invitee
  },
  CanonicalParticipantStatus.accepted: {
    CanonicalParticipantStatus.joining,
    CanonicalParticipantStatus.left, // cancelled before transport ever started
  },
  CanonicalParticipantStatus.joining: {
    CanonicalParticipantStatus.connected,
    CanonicalParticipantStatus.failed,
  },
  CanonicalParticipantStatus.connected: {
    CanonicalParticipantStatus.temporarilyDisconnected,
    CanonicalParticipantStatus.left,
  },
  CanonicalParticipantStatus.temporarilyDisconnected: {
    CanonicalParticipantStatus.connected, // reconnect
    CanonicalParticipantStatus.left, // grace expired
  },
  // Terminal statuses have no outgoing transitions.
};

class ParticipantTransitionResult {
  final bool ok;
  final CanonicalParticipantStatus status;
  final String? error;

  const ParticipantTransitionResult({required this.ok, required this.status, this.error});
}

/// Pure transition function, same contract shape as
/// session_lifecycle.dart's applySessionTransition. Terminal statuses are
/// absorbing.
ParticipantTransitionResult applyParticipantTransition(
  CanonicalParticipantStatus from,
  CanonicalParticipantStatus to,
) {
  if (isTerminalParticipantStatus(from)) {
    return ParticipantTransitionResult(
      ok: false,
      status: from,
      error: 'Participant already terminal ($from); cannot transition to $to.',
    );
  }
  final legal = participantTransitions[from];
  if (legal == null || !legal.contains(to)) {
    return ParticipantTransitionResult(
      ok: false,
      status: from,
      error: 'Illegal participant transition: $from -> $to.',
    );
  }
  return ParticipantTransitionResult(ok: true, status: to);
}

class FirstActionWinsResult {
  final CanonicalParticipantStatus? winner;
  final ParticipantTransitionResult result;

  const FirstActionWinsResult({required this.winner, required this.result});
}

/// First-action-wins helper — the pure-logic generalization of
/// DeviceCommunicationPresenceAuthorityService's proven-correct pattern.
FirstActionWinsResult resolveFirstActionWins(
  CanonicalParticipantStatus current,
  List<CanonicalParticipantStatus> candidates,
) {
  for (final candidate in candidates) {
    final result = applyParticipantTransition(current, candidate);
    if (result.ok) {
      return FirstActionWinsResult(winner: candidate, result: result);
    }
  }
  return FirstActionWinsResult(
    winner: null,
    result: ParticipantTransitionResult(
      ok: false,
      status: current,
      error: 'No candidate action was legal.',
    ),
  );
}
