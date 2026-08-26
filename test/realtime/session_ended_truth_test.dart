import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/domain/realtime_models.dart';

/// WHAT "ENDED" MEANS, IN ONE PLACE.
///
/// Founder-observed 2026-08-25, on a real accepted call: *"before connecting,
/// immediately after accept, there was a call ended banner — its odd"*.
///
/// The server defines ended exactly once, in `decorateSession`:
///
///     isActive = status not in {ENDED, CANCELLED, FAILED}
///
/// The client had that rule scattered across four independent
/// `isActive == false` reads — a banner, a navigate-away, a join guard and a
/// PiP dismissal — each of which had to be understood as "terminal" rather
/// than the more obvious "not running". These tests pin the definition to one
/// named getter so the two sides cannot drift, and so the next reader is not
/// left inferring which of the two meanings a call site intended.
void main() {
  RealtimeSession session({String status = '', dynamic isActive}) =>
      RealtimeSession.fromJson(<String, dynamic>{
        'id': 's1',
        'surfaceType': 'CONVERSATION',
        'status': status,
        'kind': 'CALL',
        if (isActive != null) 'isActive': isActive,
      });

  group('ended is a statement about lifecycle status', () {
    test('ENDED', () => expect(session(status: 'ENDED').hasEnded, isTrue));
    test('CANCELLED',
        () => expect(session(status: 'CANCELLED').hasEnded, isTrue));
    test('FAILED', () => expect(session(status: 'FAILED').hasEnded, isTrue));

    test('a live call has not ended', () {
      expect(session(status: 'ACTIVE').hasEnded, isFalse);
    });

    test('a status the client does not recognise is not an ending', () {
      // A server that grows a new pre-active status must not make an older
      // client start declaring calls over.
      expect(session(status: 'SOMETHING_NEW').hasEnded, isFalse);
    });

    test('an absent status is not an ending', () {
      expect(session().hasEnded, isFalse);
    });
  });

  group('the client never invents a second definition of ended', () {
    // The failure this guards against is the client being STRICTER than the
    // server — declaring a call over on some additional signal of its own,
    // which is how a call that is merely still arriving gets buried.
    for (final status in const ['ACTIVE', 'RINGING', 'CREATED', '']) {
      test('hasEnded agrees with the server for status "$status"', () {
        final decorated = session(status: status, isActive: true);
        expect(decorated.hasEnded, !decorated.isActive);
      });
    }

    for (final status in const ['ENDED', 'CANCELLED', 'FAILED']) {
      test('hasEnded agrees with the server for status "$status"', () {
        final decorated = session(status: status, isActive: false);
        expect(decorated.hasEnded, !decorated.isActive);
      });
    }

    test('and it agrees when the payload omits isActive entirely', () {
      // Older/lighter payloads fall back to the status rule, so both sides
      // still answer identically.
      for (final status in const ['ACTIVE', 'ENDED', 'CANCELLED', 'FAILED']) {
        final s = session(status: status);
        expect(s.hasEnded, !s.isActive, reason: 'status=$status');
      }
    });
  });

  test('every "is this call over" decision reads the one getter', () {
    // Structural, because the defect class is WHICH QUESTION a call site asks,
    // and no unit test can see a call site revert to spelling it out again.
    // Same technique the repository already uses for ordering invariants (see
    // test/realtime/call_preflight_ordering_test.dart).
    const paths = [
      'lib/features/realtime/presentation/realtime_room_screen.dart',
    ];
    for (final path in paths) {
      final src = File(path).readAsStringSync();
      expect(
        src.contains('state.session?.isActive == false'),
        isFalse,
        reason: '$path should ask hasEnded, so that "terminal" is stated '
            'rather than inferred from "not running"',
      );
    }
  });
}
