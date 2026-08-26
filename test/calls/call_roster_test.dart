import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/calls/call_participant.dart';
import 'package:aura/core/calls/call_roster.dart';
import 'package:aura/core/identity/person_identity_model.dart';

/// THE SHARED ROSTER INVARIANTS.
///
/// Founder ruling, *Call Presentation Authority*. These pin the rules that
/// every call surface must agree on, so that a thread room, a meeting room, an
/// institution room and a future Live surface cannot answer "who is here"
/// differently.
///
/// Each rule below is here because a real surface got it wrong during A/V
/// two-party certification on 2026-08-25.
void main() {
  AuraPersonIdentity person(String name, {String? id, String handle = ''}) =>
      AuraPersonIdentity(
        userId: id ?? '',
        displayName: name,
        handle: handle,
      );

  CallParticipant seat(
    String name, {
    String? userId,
    String? rowId,
    String? transportId,
    bool isSelf = false,
    bool isGuest = false,
    CallMediaState media = const CallMediaState(),
  }) =>
      CallParticipant(
        identity: person(name, id: userId),
        seatId: callSeatId(
          userId: userId,
          participantRowId: rowId,
          transportId: transportId,
        ),
        transportId: transportId,
        isSelf: isSelf,
        isGuest: isGuest,
        media: media,
      );

  group('a seat binds to a human, not to a connection', () {
    test('the canonical user outranks the row and the transport', () {
      expect(
        callSeatId(userId: 'u1', participantRowId: 'r1', transportId: 't1'),
        'user:u1',
      );
    });

    test('a guest falls back to their session seat, not their socket', () {
      // A socket changes on reconnect; the seat must not.
      expect(callSeatId(participantRowId: 'r1', transportId: 't1'), 'seat:r1');
    });

    test('the transport is the last resort, and it is the weak one', () {
      expect(callSeatId(transportId: 't1'), 'transport:t1');
    });

    test('nothing identifying yields nothing, rather than a false match', () {
      expect(callSeatId(), isEmpty);
      expect(callSeatId(userId: '  ', participantRowId: ''), isEmpty);
    });
  });

  group('one canonical identity renders once', () {
    test('a re-join does not seat the same human twice', () {
      // THE PRODUCTION DEFECT: re-joining while already in a call produced a
      // third participant in a two-person call.
      final roster = CallRoster.converge([
        seat('M S Bajwa', userId: 'u1', transportId: 'socket-A'),
        seat('Muhammad Zakria', userId: 'u2', transportId: 'socket-B'),
        seat('M S Bajwa', userId: 'u1', transportId: 'socket-C'),
      ]);

      expect(roster.participants.length, 2);
      expect(roster.participants.map((p) => p.displayName),
          ['M S Bajwa', 'Muhammad Zakria']);
    });

    test('the newest binding wins — it carries the live transport', () {
      final roster = CallRoster.converge([
        seat('A', userId: 'u1', transportId: 'old'),
        seat('A', userId: 'u1', transportId: 'new'),
      ]);
      expect(roster.participants.single.transportId, 'new');
    });

    test('but the seat keeps the position it first appeared in', () {
      // Otherwise a reconnect reshuffles the grid under the people reading it.
      final roster = CallRoster.converge([
        seat('first', userId: 'u1'),
        seat('second', userId: 'u2'),
        seat('first again', userId: 'u1'),
      ]);
      expect(roster.participants.first.displayName, 'first again');
      expect(roster.participants.last.displayName, 'second');
    });
  });

  group('legitimate people are never collapsed', () {
    test('two guests remain two humans', () {
      final roster = CallRoster.converge([
        seat('Guest one', rowId: 'r1', isGuest: true),
        seat('Guest two', rowId: 'r2', isGuest: true),
      ]);
      expect(roster.participants.length, 2);
    });

    test('unidentifiable entries are kept, not merged into each other', () {
      // Merging entries that identify nobody would combine strangers.
      final roster = CallRoster.converge([seat('?'), seat('?')]);
      expect(roster.participants.length, 2);
    });
  });

  group('the roster answers what a room needs to know', () {
    final roster = CallRoster.converge([
      seat('Me', userId: 'u1', isSelf: true),
      seat('Them', userId: 'u2'),
    ]);

    test('it knows which seat is mine', () {
      expect(roster.self?.displayName, 'Me');
      expect(roster.others.map((p) => p.displayName), ['Them']);
    });

    test('it counts humans, never transports', () {
      expect(roster.presentCount, 2);
      expect(roster.isAlone, isFalse);
    });

    test('alone means nobody else is present, not nobody else exists', () {
      final waiting = CallRoster.converge([
        seat('Me', userId: 'u1', isSelf: true),
        CallParticipant(
          identity: person('Invited', id: 'u2'),
          seatId: callSeatId(userId: 'u2'),
          participation: CallParticipation.invited,
        ),
      ]);
      expect(waiting.isAlone, isTrue);
      expect(waiting.participants.length, 2,
          reason: 'an invited person still belongs to the call');
    });
  });

  group('a reconnecting person is still a person', () {
    test('they stay present, so the room keeps saying who they are', () {
      // Blanking somebody because their socket blinked is the failure the
      // Meetings chapter froze a rule against.
      final p = CallParticipant(
        identity: person('Them', id: 'u2'),
        seatId: callSeatId(userId: 'u2'),
        participation: CallParticipation.reconnecting,
      );
      expect(p.isPresent, isTrue);
    });

    test('someone who left is not present', () {
      final p = CallParticipant(
        identity: person('Them', id: 'u2'),
        seatId: callSeatId(userId: 'u2'),
        participation: CallParticipation.left,
      );
      expect(p.isPresent, isFalse);
    });
  });

  group('media state is not identity state', () {
    test('enabled video is not the same as arriving video', () {
      // A tile trusting cameraOn alone renders a black rectangle and calls it
      // video.
      const enabledButSilent =
          CallMediaState(cameraOn: true, hasVideoFrames: false);
      expect(enabledButSilent.cameraOn, isTrue);
      expect(enabledButSilent.hasVideoFrames, isFalse);
    });
  });
}
