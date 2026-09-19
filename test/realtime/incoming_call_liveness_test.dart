import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/updates/incoming_call_bridge.dart';

/// A LATE PUSH MUST NOT RING A CALL THAT IS OVER (founder, 2026-09-19).
///
/// Production, session …8gdacp, 2026-09-16:
///
///     04:23:22.8  ring pushes sent (FCM x3, APNS x1)
///     04:23:41    caller cancelled
///     04:24:48.7  callee device presented an actionable incoming call
///                 — 85s after the ring, 67s after the cancel — then tried
///                 to join the dead session and failed twice.
///
/// The two guards that existed were both LOCAL: `expiresAt` had not passed,
/// and the precedence guard only knows terminal events this device actually
/// received while it was awake. A cancelled call passes both, which is why
/// the phone rang at a call nobody was making any more.
Map<String, dynamic> _incoming(
  String id,
  String sessionId, {
  DateTime? expiresAt,
}) => <String, dynamic>{
  'id': id,
  'data': <String, dynamic>{
    'sessionId': sessionId,
    if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
  },
};

void main() {
  group('presentation asks whether the call is still ringing for me', () {
    test('a cancelled call is retracted even though its ring window is open', () async {
      final asked = <String>[];
      final notifier = IncomingCallBridgeNotifier(
        verifyResolved: (sessionId) async {
          asked.add(sessionId);
          return true; // the server: this invitation has resolved
        },
      );

      // The 85-second case: still 4 seconds of ring window left, so every
      // local guard admits it.
      notifier.addIncoming(
        _incoming(
          'n1',
          's-cancelled',
          expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 4)),
        ),
      );
      expect(notifier.state, hasLength(1), reason: 'admitted, as before');

      await Future<void>.delayed(Duration.zero);

      expect(asked, ['s-cancelled']);
      expect(
        notifier.state,
        isEmpty,
        reason: 'the server said it is over, so the card goes',
      );
    });

    test('a live call is admitted and left alone', () async {
      final notifier = IncomingCallBridgeNotifier(
        verifyResolved: (_) async => false,
      );

      notifier.addIncoming(_incoming('n1', 's-live'));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, hasLength(1));
      expect((notifier.state.first['data'] as Map)['sessionId'], 's-live');
    });

    test('an unanswerable probe leaves the ring alone — the window still wins', () async {
      // `isCallResolvedForUser` deliberately answers false when it cannot
      // tell, so a network blip can never dismiss a legitimate call. A probe
      // that throws must behave the same way.
      final notifier = IncomingCallBridgeNotifier(
        verifyResolved: (_) async => throw StateError('offline'),
      );

      notifier.addIncoming(_incoming('n1', 's-unknown'));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, hasLength(1));
    });

    test('a retried push for the same session asks once, not twice', () async {
      var asks = 0;
      final completer = Completer<bool>();
      final notifier = IncomingCallBridgeNotifier(
        verifyResolved: (_) {
          asks++;
          return completer.future;
        },
      );

      notifier.addIncoming(_incoming('n1', 's1'));
      notifier.addIncoming(_incoming('n1-retry', 's1'));
      completer.complete(false);
      await Future<void>.delayed(Duration.zero);

      expect(asks, 1);
      expect(notifier.state, hasLength(1));
    });

    test('the healthy path is unchanged when no probe is wired', () {
      // Every existing construction site passes no probe; presentation must
      // behave exactly as it did.
      final notifier = IncomingCallBridgeNotifier();
      notifier.addIncoming(_incoming('n1', 's1'));
      expect(notifier.state, hasLength(1));
    });

    test('a retraction tombstones the session, so a later push cannot resurrect it', () async {
      final notifier = IncomingCallBridgeNotifier(
        verifyResolved: (_) async => true,
      );

      notifier.addIncoming(_incoming('n1', 's1'));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, isEmpty);

      // The second FCM copy of the same ring, arriving after the retraction.
      notifier.addIncoming(_incoming('n2', 's1'));
      expect(notifier.state, isEmpty);
    });
  });
}
