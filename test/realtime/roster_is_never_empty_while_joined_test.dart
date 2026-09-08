import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/realtime/data/realtime_event_parser.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';

/// A JOINED CLIENT IS ALWAYS IN ITS OWN ROSTER.
///
/// `mergeSnapshot` replaces `participants` wholesale whenever the payload
/// carries the key, and it did not distinguish "the key was absent" from "the
/// key said nobody is here". So any broadcast arriving with an empty array
/// emptied the roster of a client that was sitting in the call.
///
/// Observed in production 2026-09-08: the founder's client joined a call with
/// `participants=2` and eighteen seconds later reported
/// `roster=0 ids=[] byPart=0 legacy=0 tiles=1` while still joined — no
/// join-state change, so nothing had disconnected it.
void main() {
  Map<String, dynamic> participant(String id) => {
        'id': id,
        'userId': 'u-$id',
        'displayName': id,
      };

  RealtimeState joinedWith(List<String> ids) => RealtimeState.initial().copyWith(
        joinState: RealtimeJoinState.joined,
        participants: ids
            .map((id) => RealtimeParticipant.fromJson(participant(id)))
            .toList(),
      );

  test('an empty roster is refused while joined', () {
    final before = joinedWith(['a', 'b']);
    final after = RealtimeEventParser.mergeSnapshot(before, {'participants': []});
    expect(after.participants.map((p) => p.id), ['a', 'b'],
        reason: 'a roster that does not contain the receiver cannot be true');
  });

  test('a real roster change still applies, however large', () {
    final before = joinedWith(['a', 'b', 'c']);
    final after = RealtimeEventParser.mergeSnapshot(before, {
      'participants': [participant('a')],
    });
    expect(after.participants.map((p) => p.id), ['a'],
        reason: 'the guard rejects only the empty case');
  });

  test('an empty roster is honoured when not joined', () {
    // Leaving a call legitimately empties it, and that path must stay open.
    final before = RealtimeState.initial().copyWith(
      joinState: RealtimeJoinState.idle,
      participants: [RealtimeParticipant.fromJson(participant('a'))],
    );
    final after = RealtimeEventParser.mergeSnapshot(before, {'participants': []});
    expect(after.participants, isEmpty);
  });

  test('an absent key leaves the roster alone', () {
    final before = joinedWith(['a']);
    final after = RealtimeEventParser.mergeSnapshot(before, {'somethingElse': 1});
    expect(after.participants.map((p) => p.id), ['a']);
  });
}
