/// Realtime Architecture Correction — Phase 0 deterministic test harness.
///
/// Dart mirror of aura-backend/src/realtime/canonical/lifecycle-test-harness.ts.
/// A pure, in-memory simulation of the canonical session + participant +
/// device-binding contracts, with NO Riverpod, NO Socket.IO, NO real
/// clock. Exists so the 29 required scenarios can be executed and
/// asserted deterministically on the frontend side too, proving the Dart
/// mirror stays behaviorally identical to the backend contract.
///
/// PHASE 0 SCOPE: test infrastructure only. Not wired into, and does not
/// replace, any production controller/service.
library;

import 'device_socket_binding.dart';
import 'participant_lifecycle.dart';
import 'precedence.dart';
import 'session_lifecycle.dart';

class HarnessParticipant {
  final String userId;
  ParticipantReconciliationState state;
  List<CanonicalDeviceBinding> deviceBindings;

  HarnessParticipant({required this.userId, required this.state, required this.deviceBindings});
}

class FakeClock {
  int _now = 0;
  int now() => _now;
  void advance(int ms) => _now += ms;
}

enum HarnessLogKind { session, participant }

class HarnessLogEntry {
  final HarnessLogKind kind;
  final String? userId;
  final Object status;
  final int sequence;

  const HarnessLogEntry({required this.kind, this.userId, required this.status, required this.sequence});
}

class ApplyResult {
  final bool applied;
  final String? reason;

  const ApplyResult({required this.applied, this.reason});
}

class SessionEvaluationResult {
  final bool transitioned;
  final CanonicalSessionStatus? to;

  const SessionEvaluationResult({required this.transitioned, this.to});
}

class FirstActionWinsOutcome {
  final CanonicalParticipantStatus? winner;

  const FirstActionWinsOutcome({this.winner});
}

class LifecycleTestHarness {
  SessionReconciliationState session = const SessionReconciliationState(
    status: CanonicalSessionStatus.created,
    lastAppliedSequence: 0,
  );
  final Map<String, HarnessParticipant> participants = {};
  final FakeClock clock = FakeClock();
  final List<HarnessLogEntry> log = [];

  final Map<String, int> _nextSeqByParticipant = {};
  int _nextSessionSeq = 1;

  int _nextParticipantSeq(String userId) {
    final seq = (_nextSeqByParticipant[userId] ?? 0) + 1;
    _nextSeqByParticipant[userId] = seq;
    return seq;
  }

  HarnessParticipant invite(String userId) {
    final participant = HarnessParticipant(
      userId: userId,
      state: const ParticipantReconciliationState(
        status: CanonicalParticipantStatus.invited,
        lastAppliedSequence: 0,
      ),
      deviceBindings: [],
    );
    participants[userId] = participant;
    return participant;
  }

  /// Registers a device for a participant, without a live socket yet.
  void addDevice(String userId, String deviceId) {
    final p = _require(userId);
    p.deviceBindings.add(CanonicalDeviceBinding(
      participantId: userId,
      deviceId: deviceId,
      socketId: null,
      isMediaOwner: false,
      lastSeenAt: clock.now(),
    ));
  }

  void connectSocket(String userId, String deviceId, String socketId) {
    final p = _require(userId);
    final index = p.deviceBindings.indexWhere((b) => b.deviceId == deviceId);
    if (index == -1) throw StateError('Unknown device $deviceId for $userId');
    p.deviceBindings[index] =
        p.deviceBindings[index].copyWith(socketId: socketId, lastSeenAt: clock.now());
  }

  void dropSocket(String userId, String deviceId) {
    final p = _require(userId);
    final index = p.deviceBindings.indexWhere((b) => b.deviceId == deviceId);
    if (index == -1) throw StateError('Unknown device $deviceId for $userId');
    p.deviceBindings[index] = p.deviceBindings[index].copyWith(clearSocketId: true);
  }

  String claimMediaOwnership(String userId, String deviceId, [int staleAfterMs = 60000]) {
    final p = _require(userId);
    final result = resolveMediaOwnershipClaim(p.deviceBindings, deviceId, clock.now(), staleAfterMs);
    p.deviceBindings = result.bindings;
    return result.ownerDeviceId;
  }

  /// Applies a single-candidate participant transition through the full
  /// reconcile pipeline, appending to the log iff applied.
  ApplyResult _applyParticipant(String userId, CanonicalParticipantStatus status, [int? sequenceOverride]) {
    final p = _require(userId);
    final legality = applyParticipantTransition(p.state.status, status);
    if (!legality.ok) {
      return ApplyResult(applied: false, reason: legality.error);
    }
    final sequence = sequenceOverride ?? _nextParticipantSeq(userId);
    final result = reconcileParticipantEvent(
      p.state,
      SequencedParticipantEvent(sequence: sequence, status: status),
    );
    if (result.applied) {
      p.state = result.next;
      log.add(HarnessLogEntry(kind: HarnessLogKind.participant, userId: userId, status: status, sequence: sequence));
    }
    return ApplyResult(applied: result.applied, reason: result.reason);
  }

  ApplyResult accept(String userId, [int? sequenceOverride]) =>
      _applyParticipant(userId, CanonicalParticipantStatus.accepted, sequenceOverride);
  ApplyResult decline(String userId, [int? sequenceOverride]) =>
      _applyParticipant(userId, CanonicalParticipantStatus.declined, sequenceOverride);
  ApplyResult expireInvite(String userId, [int? sequenceOverride]) =>
      _applyParticipant(userId, CanonicalParticipantStatus.expired, sequenceOverride);
  ApplyResult startJoining(String userId, [int? sequenceOverride]) =>
      _applyParticipant(userId, CanonicalParticipantStatus.joining, sequenceOverride);
  ApplyResult connect(String userId, [int? sequenceOverride]) =>
      _applyParticipant(userId, CanonicalParticipantStatus.connected, sequenceOverride);
  ApplyResult transportLost(String userId, [int? sequenceOverride]) =>
      _applyParticipant(userId, CanonicalParticipantStatus.temporarilyDisconnected, sequenceOverride);
  ApplyResult reconnect(String userId, [int? sequenceOverride]) =>
      _applyParticipant(userId, CanonicalParticipantStatus.connected, sequenceOverride);
  ApplyResult leave(String userId, [int? sequenceOverride]) =>
      _applyParticipant(userId, CanonicalParticipantStatus.left, sequenceOverride);
  ApplyResult failJoin(String userId, [int? sequenceOverride]) =>
      _applyParticipant(userId, CanonicalParticipantStatus.failed, sequenceOverride);

  /// Escape hatch for tests asserting rejection of an arbitrary/illegal
  /// target status not covered by a named helper above.
  ApplyResult applyParticipantForTest(String userId, CanonicalParticipantStatus status, [int? sequenceOverride]) =>
      _applyParticipant(userId, status, sequenceOverride);

  /// First-action-wins across N candidate concurrent actions for the SAME participant.
  FirstActionWinsOutcome firstActionWins(String userId, List<CanonicalParticipantStatus> candidates) {
    final p = _require(userId);
    final outcome = resolveFirstActionWins(p.state.status, candidates);
    if (outcome.result.ok && outcome.winner != null) {
      final sequence = _nextParticipantSeq(userId);
      final reconciled = reconcileParticipantEvent(
        p.state,
        SequencedParticipantEvent(sequence: sequence, status: outcome.winner!),
      );
      if (reconciled.applied) {
        p.state = reconciled.next;
        log.add(HarnessLogEntry(
            kind: HarnessLogKind.participant, userId: userId, status: outcome.winner!, sequence: sequence));
      }
    }
    return FirstActionWinsOutcome(winner: outcome.winner);
  }

  /// Re-evaluates and, if warranted, applies a session-level transition
  /// based on current aggregate participant state.
  SessionEvaluationResult evaluateSession() {
    final values = participants.values.toList();
    final hasActiveOrRecoverable = values.any((p) => const {
          CanonicalParticipantStatus.accepted,
          CanonicalParticipantStatus.joining,
          CanonicalParticipantStatus.connected,
          CanonicalParticipantStatus.temporarilyDisconnected,
        }.contains(p.state.status));
    final hasActionableInvite =
        values.any((p) => p.state.status == CanonicalParticipantStatus.invited);
    final evaluation = evaluateSessionActivity(
      currentStatus: session.status,
      hasActiveOrRecoverableParticipant: hasActiveOrRecoverable,
      hasActionableInvite: hasActionableInvite,
    );
    if (evaluation.shouldTransitionTo == null) return const SessionEvaluationResult(transitioned: false);
    final sequence = _nextSessionSeq++;
    final result = reconcileSessionEvent(
      session,
      SequencedSessionEvent(sequence: sequence, status: evaluation.shouldTransitionTo!),
    );
    if (result.applied) {
      session = result.next;
      log.add(HarnessLogEntry(kind: HarnessLogKind.session, status: evaluation.shouldTransitionTo!, sequence: sequence));
      return SessionEvaluationResult(transitioned: true, to: evaluation.shouldTransitionTo);
    }
    return const SessionEvaluationResult(transitioned: false);
  }

  /// Explicit session transitions not derivable from the aggregate evaluator.
  ApplyResult transitionSession(CanonicalSessionStatus to) {
    final sequence = _nextSessionSeq++;
    final result = reconcileSessionEvent(session, SequencedSessionEvent(sequence: sequence, status: to));
    if (result.applied) {
      session = result.next;
      log.add(HarnessLogEntry(kind: HarnessLogKind.session, status: to, sequence: sequence));
    }
    return ApplyResult(applied: result.applied, reason: result.reason);
  }

  bool hasLiveOrRecoverableSocket(String userId, int graceMs) {
    final p = _require(userId);
    return hasAnyLiveOrRecoverableSocket(p.deviceBindings, clock.now(), graceMs);
  }

  HarnessParticipant _require(String userId) {
    final p = participants[userId];
    if (p == null) throw StateError('Unknown participant: $userId');
    return p;
  }
}
