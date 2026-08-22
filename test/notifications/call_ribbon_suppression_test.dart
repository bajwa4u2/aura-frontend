import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/application/incoming_call_projection.dart';

// THE GLOBAL RIBBON NEVER ANNOUNCES A CALL.
//
// Founder-observed on the attendee side, 2026-08-22: accepting a call showed a
// transient ribbon announcing the call they had just joined.
//
// The suppression required `attention == 'INTERRUPT'` in the payload, and NO
// real call payload carries that key — production rows carry sessionId,
// threadId, spaceId, mediaMode, contextName, realtimeType, notificationKind and
// nothing else. So the guard never fired.
//
// Calls are presented canonically at every stage: the ringing card, the room,
// the PiP, and the Activity list as history. A four-second ribbon duplicates
// the first three and contradicts them right after accept.
void main() {
  test('the kinds a call arrives as are recognised as calls', () {
    for (final kind in ['LIVE', 'CALL', 'REALTIME', 'CALL_RINGING', 'LIVE_RINGING']) {
      expect(isCallKind(kind), isTrue, reason: '$kind must be suppressed');
    }
  });

  test('a non-call kind is still presented', () {
    for (final kind in ['MESSAGE', 'FOLLOW', 'SAVE']) {
      expect(isCallKind(kind), isFalse,
          reason: 'suppressing calls must not silence ordinary attention');
    }
  });

  test('call suppression does not depend on an attention key', () {
    final bridge =
        File('lib/core/notifications/notification_bridge.dart').readAsStringSync();
    final start = bridge.indexOf('bool _isLiveInterrupt(');
    expect(start, greaterThan(-1));
    final body = bridge.substring(start, bridge.indexOf('}', start));

    expect(body.contains('attention'), isFalse,
        reason: 'no real call payload carries `attention`, so gating on it is '
            'the same as not suppressing at all');
    expect(body.contains('isCallKind'), isTrue);
  });
}
