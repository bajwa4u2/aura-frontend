import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// TAPPING CALL PLACES THE CALL.
///
/// ── WHAT THIS FILE USED TO ASSERT, AND WHY IT NO LONGER DOES ────────────
///
/// It held an ordering invariant: call intent → preflight → device readiness →
/// the person proceeds → session created → the other party is rung. A modal
/// sheet checked the microphone and camera and asked for confirmation before
/// `startLive()` created the session.
///
/// That gate was added for a real reason. Before it, pressing Call woke
/// somebody up before the caller knew whether they had a working microphone,
/// and the OS permission prompt arrived mid-join with nothing explaining it.
///
/// It answered that by taxing EVERY call with an extra screen and an extra tap,
/// including the overwhelming majority where the devices were fine and nobody
/// needed telling. Founder ruling, 2026-09-05: no phone works that way, and it
/// did not read as care — it read as the app getting in the way of a phone
/// call. The sheet is deleted.
///
/// The original concern is now met where it belongs, INSIDE the call: the
/// permission prompt appears over the calling screen, which is its own
/// explanation, and a genuine device problem surfaces there with an action
/// beside it rather than blocking the call from starting. `CallReadiness` still
/// owns that judgement and is unchanged.
///
/// So this now guards the replacement, because a test that keeps asserting a
/// removed design does not protect anything — it blocks the fix. That already
/// happened once in this repository, to the media-report latch.
void main() {
  late String startCall;
  late String screen;

  setUpAll(() {
    screen = File(
      'lib/features/conversation/presentation/conversation_screen.dart',
    ).readAsStringSync();

    final begin = screen.indexOf('Future<void> _startCall(');
    expect(begin, greaterThan(-1),
        reason: '_startCall was renamed; re-establish this invariant against '
            'whatever replaced it rather than deleting the test');
    final rest = screen.substring(begin);
    final end = rest.indexOf('\n  Future<');
    startCall = end > 0 ? rest.substring(0, end) : rest;
  });

  test('nothing is awaited before the call is placed', () {
    // The defining property of the new behaviour: pressing Call reaches
    // startLive without waiting on a person to answer a question first.
    final live = startCall.indexOf('.startLive(');
    expect(live, greaterThan(-1), reason: 'startLive must still be the act');

    final before = startCall.substring(0, live);
    for (final blocker in const [
      'showModalBottomSheet',
      'showDialog',
      'CallPreflightSheet',
    ]) {
      expect(before.contains(blocker), isFalse,
          reason: 'a call must not wait on "$blocker" before it is placed');
    }
  });

  test('the preflight sheet is gone from the product entirely', () {
    expect(
      File('lib/core/media/call_preflight_sheet.dart').existsSync(),
      isFalse,
      reason: 'the gate was deleted, not merely bypassed — leaving it behind '
          'invites it back',
    );
    expect(screen.contains('call_preflight_sheet'), isFalse);
  });

  test('device readiness still exists, because the concern was real', () {
    // Removing the GATE must not remove the JUDGEMENT. CallReadiness classifies
    // a refused permission, a missing device and a device held by another app
    // differently, and a call surface needs that to say anything useful.
    expect(File('lib/core/media/call_readiness.dart').existsSync(), isTrue);
    final readiness =
        File('lib/core/media/call_readiness.dart').readAsStringSync();
    // The bounded probe stays: getUserMedia is not guaranteed to settle, and an
    // unanswered permission prompt must become an honest answer rather than a
    // screen that never changes.
    expect(readiness, contains('_probeTimeout'));
    expect(readiness, contains('DevicePermissionState.unknown'));
  });
}
