import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/application/incoming_call_projection.dart';

// Realtime Architecture Correction — Phase 4, Part P. Pure-function coverage
// for the ONE frontend projection authority. Scenario numbers reference the
// founder directive's test matrix where a 1:1 mapping exists.

void main() {
  group('projectCallPresentationEvent', () {
    test('P1 — call:incoming projects show', () {
      expect(projectCallPresentationEvent('call:incoming'), CallPresentationIntent.show);
    });

    test('P1 — canonical invite.issued projects show identically to the legacy name', () {
      expect(projectCallPresentationEvent('invite.issued'), CallPresentationIntent.show);
    });

    test('P3-P7 — every terminal wire name (legacy and canonical) projects clear', () {
      const clearing = <String>[
        'call:terminal',
        'call:declined',
        'session:ended',
        'session:removed',
        'realtime:removed',
        'participant.accepted',
        'participant.declined',
        'participant.expired',
        'session.cancelled', // SESSION_CANCELLED's wire name (session-scoped, Phase 4 Gate 2 correction)
        'session.ended',
        'session.failed',
      ];
      for (final name in clearing) {
        expect(
          projectCallPresentationEvent(name),
          CallPresentationIntent.clear,
          reason: 'expected $name to clear',
        );
      }
    });

    test('Phase 4 Gate 2 amendment — the retired "participant.cancelled" name (a pre-existing backend wire-name inconsistency, corrected to session-scoped "session.cancelled") is not treated as a clear signal', () {
      expect(projectCallPresentationEvent('participant.cancelled'), CallPresentationIntent.noAction);
    });

    test('unrelated events project noAction', () {
      expect(projectCallPresentationEvent('session:participant.joined'), CallPresentationIntent.noAction);
      expect(projectCallPresentationEvent('meeting.state_changed'), CallPresentationIntent.noAction);
      expect(projectCallPresentationEvent('socket:connected'), CallPresentationIntent.noAction);
    });
  });

  group('isTerminalCallPayload / isCallInterruptPayload', () {
    test('a fresh ringing invite is an interrupt candidate, not terminal', () {
      final payload = <String, dynamic>{
        'notificationKind': 'LIVE',
        'attention': 'INTERRUPT',
        'data': <String, dynamic>{'sessionId': 's1', 'callState': 'ACTIVE'},
      };
      expect(isTerminalCallPayload(payload), isFalse);
      expect(isCallInterruptPayload(payload), isTrue);
    });

    test('structured CANCELLED callState is terminal and not an interrupt candidate', () {
      final payload = <String, dynamic>{
        'notificationKind': 'LIVE',
        'attention': 'INTERRUPT',
        'data': <String, dynamic>{'sessionId': 's1', 'callState': 'CANCELLED'},
      };
      expect(isTerminalCallPayload(payload), isTrue);
      expect(isCallInterruptPayload(payload), isFalse);
    });

    test('free-text fallback still catches "ended a call" — the phrase only incoming_live_overlay.dart previously had', () {
      final payload = <String, dynamic>{
        'title': 'Someone ended a call',
        'data': <String, dynamic>{'sessionId': 's1'},
      };
      expect(isTerminalCallPayload(payload), isTrue);
    });

    test('free-text fallback still catches "call cancelled" — the phrase notification_bridge.dart previously had', () {
      final payload = <String, dynamic>{
        'body': 'Call cancelled',
        'data': <String, dynamic>{'sessionId': 's1'},
      };
      expect(isTerminalCallPayload(payload), isTrue);
    });

    test('non-call kind is never an interrupt candidate regardless of attention', () {
      final payload = <String, dynamic>{
        'notificationKind': 'MESSAGE_RECEIVED',
        'attention': 'INTERRUPT',
        'data': <String, dynamic>{'sessionId': 's1'},
      };
      expect(isCallInterruptPayload(payload), isFalse);
    });
  });

  group('IncomingCallPrecedenceGuard — session-scoped idempotency/precedence (Part G)', () {
    test('P8 — a session cleared once refuses a later show for the exact same session', () {
      final guard = IncomingCallPrecedenceGuard();
      expect(guard.shouldShow('s1'), isTrue);
      guard.recordClear('s1');
      expect(guard.shouldShow('s1'), isFalse);
    });

    test('P9/P10 — late show after EXPIRED/SESSION_CANCELLED clear is refused identically to ACCEPTED', () {
      final guard = IncomingCallPrecedenceGuard();
      guard.recordClear('s-expired');
      guard.recordClear('s-cancelled');
      expect(guard.shouldShow('s-expired'), isFalse);
      expect(guard.shouldShow('s-cancelled'), isFalse);
    });

    test('P11 — duplicate clear delivery for the same session is harmless (idempotent)', () {
      final guard = IncomingCallPrecedenceGuard();
      guard.recordClear('s1');
      guard.recordClear('s1');
      guard.recordClear('s1');
      expect(guard.shouldShow('s1'), isFalse);
    });

    test('P20 — one session terminal truth never affects a different session', () {
      final guard = IncomingCallPrecedenceGuard();
      guard.recordClear('s1');
      expect(guard.shouldShow('s2'), isTrue);
    });

    test('an empty session id is never blocked (malformed-payload safety net)', () {
      final guard = IncomingCallPrecedenceGuard();
      expect(guard.shouldShow(''), isTrue);
    });

    test('reset clears every tombstone', () {
      final guard = IncomingCallPrecedenceGuard();
      guard.recordClear('s1');
      guard.recordClear('s2');
      guard.reset();
      expect(guard.shouldShow('s1'), isTrue);
      expect(guard.shouldShow('s2'), isTrue);
    });

    test('tombstone set is bounded — oldest entries evict once the cap is exceeded', () {
      final guard = IncomingCallPrecedenceGuard(maxTombstones: 3);
      guard.recordClear('s1');
      guard.recordClear('s2');
      guard.recordClear('s3');
      guard.recordClear('s4'); // evicts s1
      expect(guard.shouldShow('s1'), isTrue);
      expect(guard.shouldShow('s2'), isFalse);
      expect(guard.shouldShow('s3'), isFalse);
      expect(guard.shouldShow('s4'), isFalse);
    });
  });
}
