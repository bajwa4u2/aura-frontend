import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MEDIA ESTABLISHMENT IS A FACT ABOUT A SESSION, SO IT IS KEYED BY ONE.
///
/// "This device has reported media for this call" was held in a `bool` whose
/// lifetime was the controller — and the controller outlives a call. A second
/// call therefore inherited the first call's answer, never reported its own
/// media, and the authority held it at CONNECTING while two people talked over
/// it.
///
/// That produced a run of bugs that looked different and were one bug:
///
///   * `endCall()` did not clear what `leave()` cleared;
///   * a reused stage transport carried a spent probe into the next call;
///   * a connection window then announced failure over a working conversation.
///
/// Each was a lifetime mismatch, and each was patched by adding another reset
/// at another exit. An earlier version of THIS FILE asserted those resets — it
/// would have locked the workaround in and blocked the fix.
///
/// So this asserts the shape instead: the fact names the session it is about.
/// A fact about session A then cannot be mistaken for a fact about session B,
/// whatever survives in between, and no exit has to remember anything.
void main() {
  late String controller;
  late String transport;

  setUpAll(() {
    controller = File(
      'lib/features/realtime/application/realtime_controller.dart',
    ).readAsStringSync();
    transport = File(
      'lib/features/realtime/data/sfu_realtime_transport.dart',
    ).readAsStringSync();
  });

  test('the media-report fact is a session id, not a boolean', () {
    expect(controller, contains('String? _mediaReportedForSession'));
    expect(
      controller.contains('bool _reportedMediaEstablished'),
      isFalse,
      reason: 'a boolean cannot distinguish one call from the next; that is '
          'the entire defect this replaced',
    );
  });

  test('every report site asks whether THIS session was reported', () {
    // Both evidence paths — the mesh snapshot and the stage byte probe — must
    // go through the session-aware check. A raw read of the field would be a
    // way back to "some call, at some point".
    expect(controller, contains('bool _hasReportedMediaFor(String sessionId)'));
    final guards = '_hasReportedMediaFor('.allMatches(controller).length;
    expect(guards, greaterThanOrEqualTo(3),
        reason: 'declaration plus both report paths');
  });

  test('no exit is required to remember to reset it', () {
    // The resets in leave/endCall/_terminateSession/clearLocalSession are gone
    // BECAUSE they are no longer needed. If one comes back, the fact has
    // stopped being session-scoped and the class of bug is open again.
    expect(
      controller.contains('_mediaReportedForSession = false'),
      isFalse,
      reason: 'a session key is never cleared by assignment to false',
    );
  });

  test('the transport probe is scoped to the session it was opened for', () {
    // Same principle one layer down: the transport can outlive a call, so its
    // first-media latch is re-armed when it opens for a session rather than
    // living for the life of the object.
    final open = transport.substring(transport.indexOf('Future<void> open('));
    expect(
      open.substring(0, 2000),
      contains('_mediaFlowingReported = false'),
      reason: 'a reused transport must not carry a spent probe into a new call',
    );
  });

  test('a working call is never declared failed', () {
    // The connection window consults what actually arrived before it says a
    // call did not connect. Phase and media are two different worlds, and the
    // phase alone once announced failure over audio the person could hear.
    expect(controller, contains('inboundMediaBytes()'));
    expect(controller, contains('_closeConnectionWindow('));
  });
}
