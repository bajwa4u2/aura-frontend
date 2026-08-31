import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/updates/incoming_call_bridge.dart';

/// THE TRANSPORT RACE MUST BE INVISIBLE TO THE PERSON.
///
/// One incoming call reaches an iPhone by up to four routes — a PushKit VoIP
/// push, an ordinary APNs/FCM alert, the realtime socket, and a native
/// re-delivery on cold launch. They race, they retry, they arrive late, and
/// they arrive out of order. Whatever they do, the person is entitled to
/// exactly one ringing experience for one call, and to no ring at all once the
/// call is over.
///
/// This is the device-local half of the failure matrix, driven through the real
/// `IncomingCallBridgeNotifier` rather than through source inspection —
/// `IosCallKit` is inert off iOS, so the notifier can be exercised directly and
/// these are behavioural assertions, not wiring assertions.
///
/// The convergence identity is `(sessionId, installation)`: one process is one
/// installation, so within these tests the session id alone is the device-local
/// incoming-call identity.
Map<String, dynamic> _delivery(
  String notificationId,
  String sessionId, {
  String? expiresAt,
  String source = 'socket',
}) => <String, dynamic>{
  'id': notificationId,
  'notificationKind': 'CALL_RINGING',
  '_auraLifecycleSource': source,
  'data': <String, dynamic>{
    'sessionId': sessionId,
    'attention': 'INTERRUPT',
    'callState': 'RINGING',
    if (expiresAt != null) 'expiresAt': expiresAt,
  },
};

String _future() =>
    DateTime.now().toUtc().add(const Duration(seconds: 90)).toIso8601String();
String _past() =>
    DateTime.now().toUtc().subtract(const Duration(seconds: 5)).toIso8601String();

void main() {
  group('delivery races converge on one presentation', () {
    test('VoIP arrives, then the ordinary push — one card, not two', () {
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1', source: 'nativeCall'));
      n.addIncoming(_delivery('invite-1', 's1', source: 'foregroundPush'));
      expect(n.state, hasLength(1));
    });

    test('the ordinary push arrives first, then VoIP — still one card', () {
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1', source: 'foregroundPush'));
      n.addIncoming(_delivery('invite-1', 's1', source: 'nativeCall'));
      expect(n.state, hasLength(1));
    });

    test('socket before push, and push before socket, both collapse', () {
      for (final order in [
        ['socket', 'foregroundPush'],
        ['foregroundPush', 'socket'],
      ]) {
        final n = IncomingCallBridgeNotifier();
        for (final source in order) {
          n.addIncoming(_delivery('invite-1', 's1', source: source));
        }
        expect(n.state, hasLength(1), reason: 'order: $order');
      }
    });

    test('transports that disagree about the notification id still collapse', () {
      // A retry legitimately carries a different notification id. The session
      // is the canonical call identity and is what must dedupe.
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1'));
      n.addIncoming(_delivery('invite-1-retry', 's1'));
      expect(n.state, hasLength(1));
    });

    test('duplicate VoIP and duplicate ordinary push are each absorbed', () {
      final n = IncomingCallBridgeNotifier();
      for (var i = 0; i < 4; i++) {
        n.addIncoming(_delivery('invite-1', 's1', source: 'nativeCall'));
      }
      for (var i = 0; i < 4; i++) {
        n.addIncoming(_delivery('invite-1', 's1', source: 'foregroundPush'));
      }
      expect(n.state, hasLength(1));
    });

    test('two genuinely different calls are two presentations', () {
      // Deduplication must never silence a real second call.
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1'));
      n.addIncoming(_delivery('invite-2', 's2'));
      expect(n.state, hasLength(2));
    });
  });

  group('a resolved call cannot ring again, however late the delivery', () {
    test('late delivery after ACCEPT is refused', () {
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1'));
      n.clearAccepted('s1');
      expect(n.state, isEmpty);

      n.addIncoming(_delivery('invite-1-late', 's1'));
      expect(n.state, isEmpty, reason: 'a call being answered must not re-ring');
    });

    test('late delivery after DECLINE is refused', () {
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1'));
      n.remove('invite-1');
      expect(n.state, isEmpty);

      n.addIncoming(_delivery('invite-1-late', 's1'));
      expect(n.state, isEmpty);
    });

    test('late delivery after CALLER CANCEL is refused', () {
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1'));
      n.removeBySession('s1', reason: 'ended');
      n.addIncoming(_delivery('invite-1-late', 's1'));
      expect(n.state, isEmpty);
    });

    test('late delivery after ANSWERED ELSEWHERE is refused', () {
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1'));
      n.removeBySession('s1', reason: 'answeredElsewhere');
      n.addIncoming(_delivery('invite-1-late', 's1'));
      expect(n.state, isEmpty);
    });

    test('an EXPIRED invitation is never presented, however it arrives', () {
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1', expiresAt: _past()));
      expect(n.state, isEmpty);
    });

    test('a still-live invitation IS presented', () {
      // The mirror of the case above: suppression must be about expiry, not
      // about the presence of an expiry field.
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1', expiresAt: _future()));
      expect(n.state, hasLength(1));
    });

    test('resolving one call does not tombstone another', () {
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1'));
      n.clearAccepted('s1');
      n.addIncoming(_delivery('invite-2', 's2'));
      expect(n.state, hasLength(1));
    });
  });

  group('accepting is not ending', () {
    test('clearAccepted removes the card and tombstones the session', () {
      // The distinction that cost a real call: reporting a call ended tears
      // down the CallKit call and, after a lock-screen answer, the app's whole
      // reason to keep running. Accepting must clear the card and nothing else.
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1'));
      n.clearAccepted('s1');
      expect(n.state, isEmpty);
      n.addIncoming(_delivery('invite-1', 's1'));
      expect(n.state, isEmpty);
    });

    test('removeAccepted addressed by notification id behaves identically', () {
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('invite-1', 's1'));
      n.removeAccepted('invite-1');
      expect(n.state, isEmpty);
      n.addIncoming(_delivery('invite-1-late', 's1'));
      expect(n.state, isEmpty);
    });
  });

  group('the system presentation lapsing is not a terminal call state', () {
    test('an expired entry is evicted, a live one survives the sweep', () {
      // What `onSystemPresentationLapsed` runs: iOS retires its call UI on its
      // own schedule, shorter than the 90s invitation TTL. The recovery is to
      // drop what has genuinely expired and keep what has not — never to
      // fabricate a terminal state for a call the person can still answer.
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('live', 's-live', expiresAt: _future()));
      expect(n.state, hasLength(1));

      n.evictExpired();
      expect(
        n.state,
        hasLength(1),
        reason: 'a lapsed SYSTEM surface must not end a live CALL',
      );
    });

    test('a lapse does not tombstone the session, so the call stays answerable', () {
      final n = IncomingCallBridgeNotifier();
      n.addIncoming(_delivery('live', 's-live', expiresAt: _future()));
      n.evictExpired();
      // A subsequent legitimate re-delivery is still accepted.
      n.addIncoming(_delivery('live-2', 's-live', expiresAt: _future()));
      expect(n.state, hasLength(1));
    });
  });
}
