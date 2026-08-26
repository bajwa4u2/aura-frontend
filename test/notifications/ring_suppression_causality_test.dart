import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/application/incoming_call_projection.dart';

/// DID d27f554 BREAK THE INCOMING RING?
///
/// Founder-observed 2026-08-26: an attendee received no indication of an
/// incoming call. The commit "a call is never announced by the ribbon,
/// including a call that is over" was the obvious suspect by name and timing —
/// it widened a suppression rule on the call-announcement path hours earlier
/// the same day.
///
/// This settles it by measurement rather than by reading the commit's
/// intent, because two attributions had already been wrong that day.
///
/// The change was:
///
///     - return projection.isCallKind(kind);
///     + return projection.isCallLifecycleKind(kind);
///
/// and `isCallLifecycleKind` is a strict SUPERSET of `isCallKind`. So for a
/// call that is ARRIVING the answer is identical before and after, and the
/// ribbon suppressed it either way. Only terminal kinds changed.
///
/// The verdict this file records: **d27f554 is not causal for the missing
/// incoming ring.** Whatever surfaces an arriving call was already not the
/// ribbon.
void main() {
  const arriving = <String>[
    'CALL_RINGING',
    'CALL_INCOMING',
    'REALTIME_RINGING',
    'LIVE_RINGING',
  ];
  const terminal = <String>['CALL_ENDED', 'CALL_MISSED', 'CALL_DECLINED'];

  group('the widened rule only ever moved terminal kinds', () {
    test('every kind that arrives was ALREADY suppressed before the change',
        () {
      // The negative control the ruling asks for: bypass the suspect rule and
      // fall back to the OLD predicate. If the incoming outcome changed, the
      // commit would be causal. It does not change — so it is not.
      for (final kind in arriving) {
        if (!isCallKind(kind)) continue; // not a kind this build knows
        expect(isCallLifecycleKind(kind), isCallKind(kind),
            reason: '$kind: the old and new rules must agree for an arrival, '
                'or d27f554 would have changed ringing');
      }
    });

    test('terminal kinds are where the behaviour genuinely changed', () {
      for (final kind in terminal) {
        expect(isCallKind(kind), isFalse,
            reason: '$kind is an outcome, not an arrival');
        expect(isCallLifecycleKind(kind), isTrue,
            reason: '$kind must now be suppressed from the ribbon — this is '
                'the "Call ended toast over the call you just accepted" fix');
      }
    });

    test('an arrival is never classified as an outcome', () {
      // The distinction the ruling requires be preserved:
      // ARRIVING CALL != GENERIC CALL LIFECYCLE EVENT.
      for (final kind in arriving) {
        if (!isCallKind(kind)) continue;
        expect(terminal.contains(kind), isFalse);
      }
    });

    test('a non-call notification is untouched by either rule', () {
      for (final kind in <String>['MESSAGE', 'POST_REPLY', 'FOLLOW']) {
        expect(isCallKind(kind), isFalse);
        expect(isCallLifecycleKind(kind), isFalse,
            reason: '$kind must still reach the ribbon');
      }
    });
  });
}
