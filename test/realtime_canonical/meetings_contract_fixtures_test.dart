// Realtime Architecture Correction — Phase 0, Meetings contract fixtures.
//
// Dart mirror of aura-backend's
// src/realtime/canonical/__tests__/meetings-contract-fixtures.spec.ts.
// Does NOT test any real Meetings code — meetings_provider.dart has no
// live-call controller today (Chapter D's audit finding). These fixtures
// exercise the same canonical contracts the two-party/multi-party
// scenarios use, pinning down the three boundary properties required
// before a future Meeting-specific orchestrator can be layered on top.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura/core/realtime_canonical/participant_lifecycle.dart';
import 'package:aura/core/realtime_canonical/session_lifecycle.dart';
import 'package:aura/core/realtime_canonical/lifecycle_test_harness.dart';

void main() {
  group('Meetings contract fixtures', () {
    test('admission (ACCEPTED) is durable and independent of transport', () {
      final h = LifecycleTestHarness();
      h.invite('attendee');
      expect(h.accept('attendee').applied, true);
      expect(h.participants['attendee']!.state.status, CanonicalParticipantStatus.accepted);
      expect(h.participants['attendee']!.deviceBindings, isEmpty);
      expect(h.hasLiveOrRecoverableSocket('attendee', 0), false);
    });

    test('socket loss on an admitted attendee does not by itself move them to LEFT', () {
      final h = LifecycleTestHarness();
      h.invite('attendee');
      h.accept('attendee');
      h.addDevice('attendee', 'laptop');
      h.connectSocket('attendee', 'laptop', 's1');
      h.dropSocket('attendee', 'laptop');
      expect(h.participants['attendee']!.state.status, CanonicalParticipantStatus.accepted);
    });

    test('socket loss on a CONNECTED attendee moves through TEMPORARILY_DISCONNECTED, not straight to LEFT', () {
      final h = LifecycleTestHarness();
      h.invite('attendee');
      h.accept('attendee');
      h.startJoining('attendee');
      h.connect('attendee');
      h.addDevice('attendee', 'laptop');
      h.connectSocket('attendee', 'laptop', 's1');
      h.dropSocket('attendee', 'laptop');
      expect(h.transportLost('attendee').applied, true);
      expect(h.participants['attendee']!.state.status, CanonicalParticipantStatus.temporarilyDisconnected);
      expect(h.reconnect('attendee').applied, true);
    });

    test('a Meeting session with a host attendee and pending late-joiners does not terminate while the host is connected', () {
      final h = LifecycleTestHarness();
      h.invite('host');
      h.invite('late-joiner');
      h.accept('host');
      h.startJoining('host');
      h.connect('host');
      h.expireInvite('late-joiner');
      final evaluation = h.evaluateSession();
      expect(evaluation.transitioned, false);
      expect(h.session.status, isNot(CanonicalSessionStatus.ended));
    });
  });
}
