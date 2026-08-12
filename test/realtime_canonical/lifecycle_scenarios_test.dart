// Realtime Architecture Correction — Phase 0 deterministic scenarios.
//
// Dart mirror of aura-backend's
// src/realtime/canonical/__tests__/lifecycle-scenarios.spec.ts. Executes
// the same 29 required scenarios against the Dart LifecycleTestHarness,
// proving the frontend mirror stays behaviorally identical to the
// backend canonical contract. No widgets, no Riverpod, no real sockets.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura/core/realtime_canonical/participant_lifecycle.dart';
import 'package:aura/core/realtime_canonical/precedence.dart';
import 'package:aura/core/realtime_canonical/session_lifecycle.dart';
import 'package:aura/core/realtime_canonical/lifecycle_test_harness.dart';

void main() {
  group('Two-party lifecycle scenarios', () {
    test('1. invite -> ring -> accept -> joining -> connected', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.invited);

      expect(h.accept('callee').applied, true);
      h.transitionSession(CanonicalSessionStatus.active);
      expect(h.session.status, CanonicalSessionStatus.active);

      expect(h.startJoining('callee').applied, true);
      expect(h.connect('callee').applied, true);
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.connected);
    });

    test('2. decline', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      expect(h.decline('callee').applied, true);
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.declined);
      expect(h.accept('callee').applied, false);
    });

    test('3. caller cancel (session cancelled before anyone accepts)', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      expect(h.transitionSession(CanonicalSessionStatus.cancelled).applied, true);
      expect(h.session.status, CanonicalSessionStatus.cancelled);
    });

    test('4. natural expiry — last actionable invite reconciles the session (missed/no-answer)', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      expect(h.expireInvite('callee').applied, true);
      final evaluation = h.evaluateSession();
      expect(evaluation.transitioned, true);
      expect(evaluation.to, CanonicalSessionStatus.ended);
    });

    test('5. transport loss during join -> definitive FAILED after deadline (explicit failJoin, not a timer)', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee');
      h.startJoining('callee');
      expect(h.failJoin('callee').applied, true);
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.failed);
    });

    test('6. reconnect after a transient transport loss restores CONNECTED, not a fresh JOINING', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee');
      h.startJoining('callee');
      h.connect('callee');
      expect(h.transportLost('callee').applied, true);
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.temporarilyDisconnected);
      expect(h.reconnect('callee').applied, true);
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.connected);
    });

    test('7. permanent transport failure never resolves to CONNECTED again (terminal-absorbing)', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee');
      h.startJoining('callee');
      h.failJoin('callee');
      expect(h.connect('callee').applied, false);
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.failed);
    });

    test('8. connected participant leaves', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee');
      h.startJoining('callee');
      h.connect('callee');
      expect(h.leave('callee').applied, true);
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.left);
    });

    test('9. stale FAILED event after CONNECTED is rejected — the exact founder-observed contradiction', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee');
      h.startJoining('callee');
      final connectResult = h.connect('callee');
      expect(connectResult.applied, true);
      final p = h.participants['callee']!;
      final staleSequence = p.state.lastAppliedSequence - 1;
      final reconciled = reconcileParticipantEvent(
        p.state,
        SequencedParticipantEvent(sequence: staleSequence, status: CanonicalParticipantStatus.failed),
      );
      expect(reconciled.applied, false);
      expect(reconciled.reason, 'stale_out_of_order');
      expect(p.state.status, CanonicalParticipantStatus.connected);
    });

    test('10. stale RINGING/INVITED presentation after ACCEPTED never resurfaces (illegal transition, rejected outright)', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee');
      expect(h.applyParticipantForTest('callee', CanonicalParticipantStatus.invited).applied, false);
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.accepted);
    });
  });

  group('Multi-device scenarios', () {
    test('11. two devices receive the invitation (two device bindings on one participant)', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.addDevice('callee', 'phone');
      h.addDevice('callee', 'laptop');
      expect(h.participants['callee']!.deviceBindings.length, 2);
    });

    test('12. first ACCEPT wins across two devices racing', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.addDevice('callee', 'phone');
      h.addDevice('callee', 'laptop');
      final outcome = h.firstActionWins('callee', [
        CanonicalParticipantStatus.accepted,
        CanonicalParticipantStatus.accepted,
      ]);
      expect(outcome.winner, CanonicalParticipantStatus.accepted);
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.accepted);
      expect(h.accept('callee').applied, false);
    });

    test('13. first DECLINE wins across two devices racing', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      final outcome = h.firstActionWins('callee', [CanonicalParticipantStatus.declined]);
      expect(outcome.winner, CanonicalParticipantStatus.declined);
      expect(h.accept('callee').applied, false);
    });

    test('14. losing device action is reconciled (rejected), not silently duplicated', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee'); // device A wins
      final late = h.decline('callee'); // device B's decline, arriving after
      expect(late.applied, false);
      expect(late.reason, contains('Illegal'));
    });

    test('15. one socket disappears, human remains (second device still live)', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.addDevice('callee', 'phone');
      h.addDevice('callee', 'laptop');
      h.connectSocket('callee', 'phone', 's1');
      h.connectSocket('callee', 'laptop', 's2');
      h.dropSocket('callee', 'phone');
      expect(h.hasLiveOrRecoverableSocket('callee', 60000), true);
    });

    test('16. media-owner binding remains singular even with multiple devices', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.addDevice('callee', 'phone');
      h.addDevice('callee', 'laptop');
      h.claimMediaOwnership('callee', 'phone');
      var owners = h.participants['callee']!.deviceBindings.where((b) => b.isMediaOwner).toList();
      expect(owners.length, 1);
      expect(owners.first.deviceId, 'phone');

      final stillPhone = h.claimMediaOwnership('callee', 'laptop', 60000);
      expect(stillPhone, 'phone');
      owners = h.participants['callee']!.deviceBindings.where((b) => b.isMediaOwner).toList();
      expect(owners.length, 1);
    });
  });

  group('Multi-party scenarios', () {
    LifecycleTestHarness threeParty() {
      final h = LifecycleTestHarness();
      h.invite('a');
      h.invite('b');
      h.invite('c');
      return h;
    }

    test('17. one accepts', () {
      final h = threeParty();
      expect(h.accept('a').applied, true);
      expect(h.participants['a']!.state.status, CanonicalParticipantStatus.accepted);
      expect(h.participants['b']!.state.status, CanonicalParticipantStatus.invited);
    });

    test('18. one declines', () {
      final h = threeParty();
      expect(h.decline('b').applied, true);
      expect(h.participants['a']!.state.status, CanonicalParticipantStatus.invited);
    });

    test('19. one expires', () {
      final h = threeParty();
      expect(h.expireInvite('c').applied, true);
      final evaluation = h.evaluateSession();
      expect(evaluation.transitioned, false);
    });

    test('20. all decline/expire without anyone joining -> session terminates', () {
      final h = threeParty();
      h.decline('a');
      h.expireInvite('b');
      h.decline('c');
      final evaluation = h.evaluateSession();
      expect(evaluation.transitioned, true);
      expect(evaluation.to, CanonicalSessionStatus.ended);
    });

    test('21. one participant joins while another invite remains pending — session must NOT terminate', () {
      final h = threeParty();
      h.accept('a');
      h.startJoining('a');
      h.connect('a');
      final evaluation = h.evaluateSession();
      expect(evaluation.transitioned, false);
    });

    test('22. expiry of a non-joined invite does not end an active session', () {
      final h = threeParty();
      h.accept('a');
      h.startJoining('a');
      h.connect('a');
      h.expireInvite('b');
      h.decline('c');
      final evaluation = h.evaluateSession();
      expect(evaluation.transitioned, false);
      expect(h.participants['a']!.state.status, CanonicalParticipantStatus.connected);
    });

    test('23. joined participant leaves while another participant remains -> session stays active', () {
      final h = threeParty();
      h.accept('a');
      h.startJoining('a');
      h.connect('a');
      h.accept('b');
      h.startJoining('b');
      h.connect('b');
      h.decline('c');
      h.leave('a');
      final evaluation = h.evaluateSession();
      expect(evaluation.transitioned, false);
    });
  });

  group('Recovery / ordering scenarios', () {
    test('24. duplicate event delivery is a safe no-op', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee');
      final p = h.participants['callee']!;
      final sequence = p.state.lastAppliedSequence;
      final duplicate = reconcileParticipantEvent(
        p.state,
        SequencedParticipantEvent(sequence: sequence, status: CanonicalParticipantStatus.accepted),
      );
      expect(duplicate.applied, false);
      expect(duplicate.reason, 'duplicate_delivery');
      expect(p.state.status, CanonicalParticipantStatus.accepted);
    });

    test('25. out-of-order stale event is rejected, not applied', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee'); // sequence 1
      h.startJoining('callee'); // sequence 2
      h.connect('callee'); // sequence 3
      final p = h.participants['callee']!;
      final stale = reconcileParticipantEvent(
        p.state,
        const SequencedParticipantEvent(sequence: 2, status: CanonicalParticipantStatus.joining),
      );
      expect(stale.applied, false);
      expect(stale.reason, 'stale_out_of_order');
      expect(p.state.status, CanonicalParticipantStatus.connected);
    });

    test('26. a reconnect event after a definitive terminal LEFT is rejected — terminal is absorbing', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee');
      h.startJoining('callee');
      h.connect('callee');
      h.leave('callee');
      expect(h.reconnect('callee').applied, false);
      expect(h.participants['callee']!.state.status, CanonicalParticipantStatus.left);
    });

    test('27. a superseded join attempt cannot declare CONNECTED after a newer attempt already has', () {
      final h = LifecycleTestHarness();
      h.invite('callee');
      h.accept('callee');
      h.startJoining('callee');
      final connected = h.connect('callee');
      expect(connected.applied, true);
      final p = h.participants['callee']!;
      final winningSequence = p.state.lastAppliedSequence;
      final lateSuperseded = reconcileParticipantEvent(
        p.state,
        SequencedParticipantEvent(sequence: winningSequence - 1, status: CanonicalParticipantStatus.connected),
      );
      expect(lateSuperseded.applied, false);
    });

    test('28. JOINING has exactly two legal exits — CONNECTED or FAILED — never an indefinite spinner', () {
      final legalExits = participantTransitions[CanonicalParticipantStatus.joining]!;
      expect(
        legalExits,
        containsAll(<CanonicalParticipantStatus>[
          CanonicalParticipantStatus.connected,
          CanonicalParticipantStatus.failed,
        ]),
      );
      expect(legalExits.length, 2);
    });

    test('29. session terminal truth invalidates pending presentation — documents the Phase 1 forcing obligation', () {
      final h = LifecycleTestHarness();
      h.invite('a');
      h.invite('b');
      h.accept('a');
      h.startJoining('a');
      h.expireInvite('b');
      h.transitionSession(CanonicalSessionStatus.active);
      final ended = h.transitionSession(CanonicalSessionStatus.ended);
      expect(ended.applied, true);
      expect(h.session.status, CanonicalSessionStatus.ended);
      // Phase 0's pure harness deliberately does NOT force non-terminal
      // participants to LEFT when the session ends — that atomic forcing
      // is Phase 1 production orchestration. This assertion pins down
      // that gap as the exact obligation Phase 1 inherits.
      expect(h.participants['a']!.state.status, CanonicalParticipantStatus.joining);
    });
  });
}
