import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// C-5 — BEING JOINED IS NOT THE SAME AS BEING IN A CALL.
///
/// Founder-observed, Film A capture 10: after the far end hung up, the web room
/// sat at *"Connecting… · 0 participants"* and never recovered.
///
/// Three things had to be true at once for that to be inescapable, and each one
/// looked reasonable on its own:
///
///   1. the room's truth poll stood down the moment `isJoined` went true, on
///      the reasoning that "the socket carries terminal truth live" — which it
///      does, when the event arrives;
///   2. the ended-session exit required `!state.isJoined`, so a client that had
///      joined could never take it;
///   3. the incoming-call suppression read the ADDRESS, so while stranded at
///      `/realtime/:id` the next call never rang either. That half is held by
///      `an_address_is_not_a_call_test.dart`.
///
/// Together: a client nominally joined to a session the server had already
/// ended had nothing left that would ever tell it, no way out, and no way for
/// anybody to reach it.
///
/// These assert the two conditions at the source. Both are one-word edits away
/// from returning — `if (current.isJoined) return;` reads like an obvious
/// optimisation, and `!state.isJoined` reads like an obvious safety guard.
void main() {
  final src = File(
    'lib/features/realtime/presentation/realtime_room_screen.dart',
  ).readAsStringSync();

  group('the truth poll stands down only for a call that is really live', () {
    test('it does not stand down on isJoined alone', () {
      expect(src, isNot(contains('if (current.isJoined) return;')),
          reason: 'a joined client parked on a dead session stops asking, and '
              'nothing else will ever tell it');
    });

    test('it stands down when somebody else is actually present', () {
      expect(
        src,
        contains('if (current.isJoined && _someoneElseIsPresent(current)) return;'),
      );
    });

    test('presence is judged by a present PEER, not by my own join', () {
      // The state's own doctrine, written beside `acceptedByPeer`:
      // "participants reflecting a present peer remains the sole evidence".
      expect(src, contains('bool _someoneElseIsPresent(RealtimeState state)'));
      expect(src, contains('if (!p.isPresent) continue;'));
      expect(src, contains('if (me.isNotEmpty && p.userId == me) continue;'),
          reason: 'counting myself would make every solo room look live');
    });
  });

  group('a client joined to an ended session can leave', () {
    /// The ended-session exit, from its comment anchor to the navigation call.
    final exit = (() {
      final start = src.indexOf('final hydratedSession = state.session;');
      if (start < 0) throw StateError('the ended-session exit is gone');
      return src.substring(start, start + 600);
    })();

    test('the exit no longer requires NOT being joined', () {
      expect(exit, isNot(contains('!state.isJoined')),
          reason: 'this is the clause that made the stranding inescapable');
    });

    test('it still turns on SERVER truth, not on silence', () {
      // `isActive` is `status not in {ENDED, CANCELLED, FAILED}`. Anything
      // weaker — a quiet transport, a brief reconnect — must never eject
      // somebody from a working call.
      expect(exit, contains('!hydratedSession.isActive'));
    });

    test('meetings keep their own exit semantics', () {
      expect(
        exit,
        contains('hydratedSession.surfaceType != RealtimeSurfaceType.meeting'),
      );
    });

    test('the reason is kept where the clause was', () {
      expect(src, contains('C-5 (2026-09-24): `!state.isJoined` came off'));
    });
  });
}
