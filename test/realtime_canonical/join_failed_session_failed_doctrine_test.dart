// Realtime Architecture Correction — Phase 0 closeout, Part A.
//
// Founder-frozen doctrine (2026-08-14): PARTICIPANT FAILED / JOIN_FAILED
// is participant-scoped and must never by itself transition the whole
// session to CanonicalSessionStatus.failed. SESSION FAILED is reserved
// for genuine session-level failure, applied explicitly, never derived
// automatically from participant state. Dart mirror of aura-backend's
// join-failed-session-failed-doctrine.spec.ts.

import 'package:flutter_test/flutter_test.dart';
import 'package:aura/core/realtime_canonical/participant_lifecycle.dart';
import 'package:aura/core/realtime_canonical/session_lifecycle.dart';
import 'package:aura/core/realtime_canonical/lifecycle_test_harness.dart';

void main() {
  group('JOIN_FAILED / SESSION_FAILED doctrine (frozen 2026-08-14)', () {
    test('one participant JOIN_FAILED does not fail a viable multi-party session with another actionable invite', () {
      final h = LifecycleTestHarness();
      h.invite('a');
      h.invite('b');
      h.invite('c');

      h.accept('a');
      h.startJoining('a');
      expect(h.failJoin('a').applied, true);
      expect(h.participants['a']!.state.status, CanonicalParticipantStatus.failed);

      final evaluation = h.evaluateSession();
      expect(evaluation.transitioned, false);
      expect(h.session.status, isNot(CanonicalSessionStatus.failed));
    });

    test('one participant JOIN_FAILED does not fail a session with another CONNECTED participant', () {
      final h = LifecycleTestHarness();
      h.invite('a');
      h.invite('b');
      h.invite('c');

      h.accept('b');
      h.startJoining('b');
      h.connect('b');

      h.accept('a');
      h.startJoining('a');
      h.failJoin('a');

      h.decline('c');

      final evaluation = h.evaluateSession();
      expect(evaluation.transitioned, false);
      expect(h.session.status, isNot(CanonicalSessionStatus.failed));
      expect(h.participants['b']!.state.status, CanonicalParticipantStatus.connected);
      expect(h.participants['a']!.state.status, CanonicalParticipantStatus.failed);
    });

    test('aggregate session evaluation never derives SESSION FAILED from participant state — even when every participant individually fails, the outcome is ENDED, not FAILED', () {
      final h = LifecycleTestHarness();
      h.invite('a');
      h.invite('b');

      h.accept('a');
      h.startJoining('a');
      h.failJoin('a');

      h.accept('b');
      h.startJoining('b');
      h.failJoin('b');

      final evaluation = h.evaluateSession();
      expect(evaluation.transitioned, true);
      expect(evaluation.to, CanonicalSessionStatus.ended);
      expect(evaluation.to, isNot(CanonicalSessionStatus.failed));
    });

    test('a genuine session-level FAILED remains representable as an explicit, non-derived transition', () {
      final h = LifecycleTestHarness();
      h.invite('a');
      h.accept('a');
      final result = h.transitionSession(CanonicalSessionStatus.failed);
      expect(result.applied, true);
      expect(h.session.status, CanonicalSessionStatus.failed);
    });
  });
}
