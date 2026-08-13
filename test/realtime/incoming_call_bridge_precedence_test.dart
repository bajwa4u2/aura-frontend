import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/updates/incoming_call_bridge.dart';

// Realtime Architecture Correction — Phase 4, Part G/P. Integration-level
// coverage of IncomingCallPrecedenceGuard actually wired into
// IncomingCallBridgeNotifier — the pure-function guard tests
// (incoming_call_projection_test.dart) prove the primitive; these prove the
// real consumer applies it correctly.

Map<String, dynamic> _incoming(String id, String sessionId) => <String, dynamic>{
  'id': id,
  'data': <String, dynamic>{'sessionId': sessionId},
};

void main() {
  group('IncomingCallBridgeNotifier precedence', () {
    test('P8 — a late addIncoming for a session already removed via removeBySession is refused', () {
      final notifier = IncomingCallBridgeNotifier();
      notifier.addIncoming(_incoming('n1', 's1'));
      expect(notifier.state, hasLength(1));

      notifier.removeBySession('s1');
      expect(notifier.state, isEmpty);

      // Late/reordered redelivery of the SAME session must not resurrect it.
      notifier.addIncoming(_incoming('n1-retry', 's1'));
      expect(notifier.state, isEmpty);
    });

    test('P11 — duplicate removeBySession for the same session is harmless', () {
      final notifier = IncomingCallBridgeNotifier();
      notifier.addIncoming(_incoming('n1', 's1'));
      notifier.removeBySession('s1');
      notifier.removeBySession('s1');
      notifier.removeBySession('s1');
      notifier.addIncoming(_incoming('n1-retry', 's1'));
      expect(notifier.state, isEmpty);
    });

    test('P20 — clearing one session does not block a genuinely different session', () {
      final notifier = IncomingCallBridgeNotifier();
      notifier.addIncoming(_incoming('n1', 's1'));
      notifier.removeBySession('s1');

      notifier.addIncoming(_incoming('n2', 's2'));
      expect(notifier.state, hasLength(1));
      expect(notifier.state.first['id'], 'n2');
    });

    test('a local ring-timeout removal via remove(id) also tombstones the session', () {
      final notifier = IncomingCallBridgeNotifier();
      notifier.addIncoming(_incoming('n1', 's1'));
      notifier.remove('n1');
      expect(notifier.state, isEmpty);

      notifier.addIncoming(_incoming('n1-retry', 's1'));
      expect(notifier.state, isEmpty);
    });

    test('clear() resets the precedence guard so a previously-tombstoned session id can show again after sign-out/sign-in', () {
      final notifier = IncomingCallBridgeNotifier();
      notifier.addIncoming(_incoming('n1', 's1'));
      notifier.removeBySession('s1');
      notifier.clear();

      notifier.addIncoming(_incoming('n1-again', 's1'));
      expect(notifier.state, hasLength(1));
    });

    test('multi-party — one session declined does not block a different concurrent session', () {
      final notifier = IncomingCallBridgeNotifier();
      notifier.addIncoming(_incoming('call-a', 'session-a'));
      notifier.addIncoming(_incoming('call-b', 'session-b'));
      expect(notifier.state, hasLength(2));

      notifier.removeBySession('session-a');
      expect(notifier.state, hasLength(1));
      expect(notifier.state.first['id'], 'call-b');

      // Late redelivery for the declined session must not resurrect it,
      // while the still-pending session is unaffected.
      notifier.addIncoming(_incoming('call-a-retry', 'session-a'));
      expect(notifier.state, hasLength(1));
      expect(notifier.state.first['id'], 'call-b');
    });
  });
}
