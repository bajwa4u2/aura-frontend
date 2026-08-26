import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/data/realtime_event_parser.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';

/// ONE CANONICAL PARTICIPANT IDENTITY RENDERS ONCE.
///
/// **Founder-observed live, 2026-08-25:** re-joining a call while already in it
/// produced a THIRD participant — one human rendered twice in a two-person
/// call.
///
/// The single-participant merge already collapsed by identity. The full-roster
/// path did not: it mapped the array straight to a list, so a roster carrying
/// one user more than once — a second transport binding, or a re-join racing
/// the previous teardown — rendered as another person in the room.
///
/// This is not new policy. Aura already asserts it everywhere else:
/// `@@unique([sessionId, userId])` in the database; `PresenceService` keyed by
/// `(sessionId, userId)` with `runtimeDeviceIds` as a Set *inside* that one
/// record; the gateway disconnecting replaced sockets; and mid-call device
/// handoff modelled as a TRANSFER authority rather than a second seat.
void main() {
  RealtimeParticipant p({
    String id = '',
    String userId = '',
    String? runtimeDeviceId,
    String displayName = 'Someone',
    bool audioOn = true,
  }) =>
      RealtimeParticipant(
        id: id,
        userId: userId,
        runtimeDeviceId: runtimeDeviceId,
        role: RealtimeParticipantRole.participant,
        joinState: 'ACTIVE',
        isPresent: true,
        audioOn: audioOn,
        videoOn: true,
        screenOn: false,
        displayName: displayName,
        handle: '',
        avatarUrl: '',
        displayRole: '',
        institutionName: '',
        institutionHandle: '',
        institutionRole: '',
        institutionTitle: '',
        joinedAt: null,
        leftAt: null,
      );

  RealtimeState stateWith(List<RealtimeParticipant> participants) =>
      RealtimeState.initial().copyWith(
        participants: participants,
        joinState: RealtimeJoinState.joined,
      );

  Map<String, dynamic> roster(List<Map<String, dynamic>> people) => {
        'participants': people,
      };

  group('a re-join does not seat a second copy of the same person', () {
    test('the same userId twice renders once', () {
      // THE PRODUCTION CASE: two transport bindings for one human.
      final merged = RealtimeEventParser.mergeSnapshot(
        stateWith(const []),
        roster([
          {'id': 'row-1', 'userId': 'u-bajwa', 'displayName': 'M S Bajwa'},
          {'id': 'row-2', 'userId': 'u-bajwa', 'displayName': 'M S Bajwa'},
          {'id': 'row-3', 'userId': 'u-zakria', 'displayName': 'Muhammad Zakria'},
        ]),
      );

      expect(merged.participants.length, 2,
          reason: 'one human rendered twice — the third-participant defect');
      expect(
        merged.participants.map((x) => x.userId),
        ['u-bajwa', 'u-zakria'],
        reason: 'the seat should keep its original position, not reshuffle',
      );
    });

    test('the newest binding wins, because it carries current media state', () {
      final merged = RealtimeEventParser.mergeSnapshot(
        stateWith(const []),
        roster([
          {'id': 'row-1', 'userId': 'u-bajwa', 'audioOn': true},
          {'id': 'row-2', 'userId': 'u-bajwa', 'audioOn': false},
        ]),
      );
      expect(merged.participants.single.audioOn, isFalse,
          reason: 'a stale binding overwrote the live one');
    });

    test('two different people are never collapsed', () {
      final merged = RealtimeEventParser.mergeSnapshot(
        stateWith(const []),
        roster([
          {'id': 'row-1', 'userId': 'u-a'},
          {'id': 'row-2', 'userId': 'u-b'},
        ]),
      );
      expect(merged.participants.length, 2);
    });
  });

  group('anonymous participants stay distinct', () {
    test('two guests with no userId remain two people', () {
      // A guest has no canonical user identity, and two guests are two humans.
      final merged = RealtimeEventParser.mergeSnapshot(
        stateWith(const []),
        roster([
          {'id': 'row-1', 'displayName': 'Guest one'},
          {'id': 'row-2', 'displayName': 'Guest two'},
        ]),
      );
      expect(merged.participants.length, 2,
          reason: 'distinct guests were merged into one');
    });

    test('the same guest row twice still renders once', () {
      final merged = RealtimeEventParser.mergeSnapshot(
        stateWith(const []),
        roster([
          {'id': 'row-1', 'displayName': 'Guest one'},
          {'id': 'row-1', 'displayName': 'Guest one'},
        ]),
      );
      expect(merged.participants.length, 1);
    });
  });

  group('a nameless event cannot invent a participant', () {
    test('a single-participant event with no identity is ignored', () {
      // `_mergeSingleParticipant` appended anything it could not match, so an
      // event carrying no userId, row id or device seated a participant nobody
      // could name.
      // The parser recognises a participant event by its FIELDS at the top
      // level, so `runtimeDeviceId: ''` reaches the merge with nothing that
      // identifies anyone.
      final before = stateWith([p(id: 'row-1', userId: 'u-a')]);
      final merged = RealtimeEventParser.mergeSnapshot(before, {
        'runtimeDeviceId': '',
        'displayName': 'Someone',
      });
      expect(merged.participants.length, 1,
          reason: 'a ghost participant was seated from an identity-less event');
    });

    test('an identified event still updates its own seat', () {
      final before = stateWith([p(id: 'row-1', userId: 'u-a', audioOn: true)]);
      final merged = RealtimeEventParser.mergeSnapshot(before, {
        'id': 'row-1',
        'userId': 'u-a',
        'audioState': 'MUTED',
      });
      expect(merged.participants.length, 1);
      expect(merged.participants.single.audioOn, isFalse);
    });
  });
}
