import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A ROOM THAT WAS NEVER POPULATED HAS NOT EMPTIED.
///
/// Founder-observed 2026-08-25, on a real answered call: *"before connecting,
/// immediately after accept, there was a call ended banner — its odd"*.
///
/// Traced to the socket `participant:left` handler in `RealtimeController`,
/// which ended the call whenever the roster fell to one person while joined.
/// During a join that test is unsafe: this client's roster legitimately holds
/// only ITSELF until the other party's row arrives, so a departure event
/// landing in that window reads a not-yet-populated roster as an emptied one.
///
/// It is the same collapse as the accept/decline truth doctrine forbids —
/// a pre-state mistaken for a post-state — one level down, on the roster
/// rather than the session:
///
///     NOT YET POPULATED  ≠  EMPTIED
///
/// The guard is that a departure may only empty a room if the departing person
/// was somebody this client actually had. That mirrors the rule the shared
/// roster already applies to identity in `lib/core/calls/call_roster.dart`: an
/// entry identifying nobody is never authoritative.
///
/// Structural, because the defect is WHICH CONDITION the handler tests, and it
/// lives inside a socket-event switch that no unit test can reach without
/// standing up the whole realtime stack. Same technique the repository already
/// uses for ordering invariants — see
/// `test/realtime/call_preflight_ordering_test.dart`.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/realtime/application/realtime_controller.dart',
    ).readAsStringSync();
  });

  test('the leaver is identified against the roster BEFORE it is rewritten',
      () {
    final knew = source.indexOf('final knewLeaver =');
    expect(knew, greaterThan(-1),
        reason: 'the guard was renamed or removed; re-establish the invariant '
            'against whatever replaced it rather than deleting this test');

    // The socket handler's own roster rewrite — the FIRST one after the guard.
    // (`_expirePeerGrace` has an identically-shaped line earlier in the file.)
    final rewrite =
        source.indexOf('final updatedParticipants = state.participants', knew);
    expect(rewrite, greaterThan(-1));

    // Order matters: computed after the roster is filtered, the leaver would
    // never be found and the guard would be permanently false.
    expect(knew, lessThan(rewrite),
        reason: 'knewLeaver must be read from the roster as it stood BEFORE '
            'the departing participant was filtered out of it');
  });

  test('emptiness can only end a call for a leaver we actually had', () {
    expect(
      source.contains(
        'if (knewLeaver && updatedParticipants.length <= 1 && state.isJoined)',
      ),
      isTrue,
      reason: 'a departure for somebody this client never had on the roster '
          'says nothing about whether the room emptied, and must not end a '
          'call that is still arriving',
    );
  });

  test('a reconnect grace is only ever started for somebody we had', () {
    // `_expirePeerGrace` ends the call on the same roster-count test, so an
    // unguarded grace would reintroduce the identical defect one grace window
    // later. Guarding at the source is what keeps that later test sound.
    expect(
      source.contains(
        'state.participants.any((p) => p.userId == leavingUserId)',
      ),
      isTrue,
      reason: 'a grace started for an unknown leaver expires into an emptiness '
          'test that would end a call that was never theirs to end',
    );
  });

  test('the reconnect grace itself is preserved, not weakened', () {
    // An involuntary drop must still hold the seat rather than empty it —
    // that rule predates this fix and this fix must not remove it.
    expect(source.contains('appliesReconnectGrace'), isTrue);
    expect(source.contains('_startPeerGrace('), isTrue);
  });
}
