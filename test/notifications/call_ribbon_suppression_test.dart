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

  // WHY THIS TEST GREW, 2026-08-25.
  //
  // Everything above passed while the founder was still being shown a "Call
  // ended" toast over the call they had just accepted. The suppression asked
  // `isCallKind`, which means "is a call ARRIVING" — so CALL_ENDED was not a
  // call as far as the guard was concerned, and the notification refresh that
  // the accept itself triggers carried it straight to the ribbon.
  //
  // A test that only checks the ringing vocabulary cannot see that. These
  // check the question the ribbon actually needs answered.
  test('a call that is OVER is still a call, for suppression purposes', () {
    for (final kind in ['CALL_ENDED', 'CALL_MISSED', 'CALL_DECLINED']) {
      expect(isCallLifecycleKind(kind), isTrue,
          reason: '$kind must be suppressed: the Activity list is its history, '
              'and a four-second ribbon is not history');
    }
  });

  test('but a call that is over is NOT an arriving call', () {
    // The distinction the ringing layer depends on. Collapsing these would
    // make a missed call render as an incoming one.
    for (final kind in ['CALL_ENDED', 'CALL_MISSED', 'CALL_DECLINED']) {
      expect(isCallKind(kind), isFalse,
          reason: '$kind must never reach the incoming-call layer');
    }
  });

  test('an arriving call is covered by both questions', () {
    for (final kind in ['LIVE', 'CALL', 'REALTIME', 'CALL_RINGING', 'LIVE_RINGING']) {
      expect(isCallLifecycleKind(kind), isTrue);
    }
  });

  test('widening did not swallow ordinary attention', () {
    for (final kind in ['MESSAGE', 'FOLLOW', 'SAVE', 'REPLY', 'MENTION']) {
      expect(isCallLifecycleKind(kind), isFalse,
          reason: 'suppressing calls must not silence everything else');
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
    expect(body.contains('isCallLifecycleKind'), isTrue,
        reason: 'the ribbon must ask whether this BELONGS to calls, not '
            'whether one is arriving');
  });

  // EVERY PATH THAT CAN RAISE A RIBBON, NOT JUST THE ONE THAT WAS FIXED.
  //
  // 2026-08-25: the terminal-kind suppression was added to the POLLED path
  // and the founder still saw "Call ended" on the very next build — because
  // the FCM foreground handler has its OWN snackbar call, and it had no call
  // suppression at all. A guard on one of two doors is not a guard.
  //
  // This walks the bridge and asserts that every `_showForegroundSnackbar` /
  // `_showForegroundNotification` call site is preceded by a call-lifecycle
  // refusal, so a third path cannot be added later without one.
  test('no snackbar path can announce a call', () {
    final bridge =
        File('lib/core/notifications/notification_bridge.dart').readAsStringSync();

    // The handler that receives pushes while the app is in front.
    final fcmStart = bridge.indexOf('void _onFcmForeground(');
    expect(fcmStart, greaterThan(-1));
    final fcmEnd = bridge.indexOf('void _onFcmTap(', fcmStart);
    expect(fcmEnd, greaterThan(fcmStart));
    final fcmBody = bridge.substring(fcmStart, fcmEnd);

    expect(
      fcmBody.contains('isCallLifecycleKind'),
      isTrue,
      reason: 'the foreground PUSH path must refuse call kinds before it '
          'reaches a snackbar — terminal call pushes are not "interrupts", so '
          'the incoming-call branch above never claims them',
    );

    // The handler that receives polled notification rows.
    final pollStart = bridge.indexOf('void _handleNotificationUpdate(');
    expect(pollStart, greaterThan(-1));
    final pollEnd = bridge.indexOf('bool _isLiveInterrupt(', pollStart);
    expect(pollEnd, greaterThan(pollStart));

    expect(
      bridge.substring(pollStart, pollEnd).contains('_isLiveInterrupt('),
      isTrue,
      reason: 'the polled path must refuse call kinds too',
    );
  });
}
