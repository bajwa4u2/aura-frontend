import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A LIVE SUBSCRIPTION IS LISTENED TO, NEVER REFRESHED.
///
/// `meetingStateChangedEventProvider` is a StreamProvider over the realtime
/// socket. The Meetings home both listened to it and, on every refresh,
/// invalidated it — which tore the subscription down and built a new one.
///
/// That closed a loop: an event fired _refresh(), _refresh() invalidated the
/// stream, the rebuilt stream notified the listener, and the listener called
/// _refresh() again. Every real meeting state change started a self-feeding
/// cycle of re-subscriptions and six-endpoint refetches, and a 30-second timer
/// dropped the realtime feed twice a minute besides.
///
/// Meetings is a protected certified surface and the whole existing suite
/// passed with this present, so the invariant is pinned here directly.
void main() {
  final source = File(
    'lib/features/meetings/presentation/meetings_home_screen.dart',
  ).readAsStringSync();

  /// Comments explain the invariant, so they legitimately name what the code
  /// must not do. Match code only.
  String codeOnly(String src) => src
      .split(String.fromCharCode(10))
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('///') && !t.startsWith('*');
      })
      .join(String.fromCharCode(10));

  final code = codeOnly(source);

  group('the meetings realtime feed is not torn down', () {
    test('the socket stream provider is never invalidated', () {
      expect(
        code.contains('invalidate(meetingStateChangedEventProvider)'),
        isFalse,
        reason: 'invalidating the stream re-subscribes the socket and loops '
            'with the listener in build()',
      );
    });

    test('it is still actually listened to', () {
      // The fix must not have quietly removed the realtime path instead of
      // repairing it — that would trade a loop for a dead feed.
      expect(code, contains('ref.listen(meetingStateChangedEventProvider'));
    });

    test('the fallback timer reconciles, it does not poll every 30 seconds',
        () {
      expect(code.contains('Duration(seconds: 30)'), isFalse);
      expect(code, contains('_reconcileEvery'));
      expect(code, contains('Duration(minutes: 5)'));
    });
  });
}
