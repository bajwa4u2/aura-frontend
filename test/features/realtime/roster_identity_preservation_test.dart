import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/data/realtime_event_parser.dart';
import 'package:aura/features/realtime/domain/realtime_state.dart';

/// A PRESENCE EVENT MUST NOT ERASE CANONICAL IDENTITY.
///
/// Measured in production 2026-08-28, two seconds apart on the same client:
///
///     09:50:35.792  roster ids=[none, cmtcj956]
///     09:50:37.886  roster ids=[none, none]      dev=YyI9Ua-6
///
/// A `session:participant.joined` payload carries userId, socketId and the
/// media flags it exists to announce — and no `RealtimeSessionParticipant.id`.
/// The merge replaced the whole entry, so the id vanished.
///
/// Everything downstream keys on that id: the SFU had bound both remote
/// tracks, the renderer was created, held and decoding, and the call stage
/// looked up `renderersByParticipant[p.id]` with an empty string and drew one
/// tile. The other device kept its copy of the id and drew two — the same
/// build, opposite outcomes.
void main() {
  RealtimeState stateWith(List<Map<String, dynamic>> participants) =>
      RealtimeEventParser.mergeSnapshot(
        RealtimeState.initial(),
        <String, dynamic>{'participants': participants},
      );

  group('a roster update preserves what it does not carry', () {
    test('a presence event without an id keeps the id already held', () {
      final hydrated = stateWith([
        {
          'id': 'part_zakria',
          'userId': 'user_zakria',
          'audioState': 'OFF',
          'videoState': 'OFF',
        },
      ]);
      expect(hydrated.participants.single.id, 'part_zakria');

      // The live event: userId + socket + media flags, no row id.
      final after = RealtimeEventParser.mergeSnapshot(hydrated, {
        'userId': 'user_zakria',
        'socketId': 'YyI9Ua-6xyz',
        'audioState': 'ON',
        'videoState': 'ON',
      });

      final p = after.participants.single;
      expect(p.id, 'part_zakria',
          reason: 'the tile lookup keys on this and nothing else replaces it');
      expect(p.runtimeDeviceId, 'YyI9Ua-6xyz');
      // The event IS authoritative about what it came to say.
      expect(p.audioOn, isTrue);
      expect(p.videoOn, isTrue);
    });

    test('an event that does carry an id still wins', () {
      final hydrated = stateWith([
        {'id': 'old', 'userId': 'user_zakria'},
      ]);
      final after = RealtimeEventParser.mergeSnapshot(hydrated, {
        'id': 'new',
        'userId': 'user_zakria',
      });
      expect(after.participants.single.id, 'new');
    });

    test('a whole-roster payload without ids does not erase them either', () {
      final hydrated = stateWith([
        {'id': 'part_a', 'userId': 'user_a'},
        {'id': 'part_b', 'userId': 'user_b'},
      ]);
      final after = RealtimeEventParser.mergeSnapshot(hydrated, {
        'participants': [
          {'userId': 'user_a', 'videoState': 'ON'},
          {'userId': 'user_b', 'videoState': 'ON'},
        ],
      });
      expect(after.participants.map((p) => p.id), ['part_a', 'part_b']);
      expect(after.participants.every((p) => p.videoOn), isTrue);
    });

    test('a roster list still decides WHO is present', () {
      // Carrying identity forward must not resurrect somebody who left.
      final hydrated = stateWith([
        {'id': 'part_a', 'userId': 'user_a'},
        {'id': 'part_b', 'userId': 'user_b'},
      ]);
      final after = RealtimeEventParser.mergeSnapshot(hydrated, {
        'participants': [
          {'id': 'part_a', 'userId': 'user_a'},
        ],
      });
      expect(after.participants.map((p) => p.userId), ['user_a']);
    });

    test('profile fields survive a bare presence event', () {
      final hydrated = stateWith([
        {
          'id': 'part_a',
          'userId': 'user_a',
          'displayName': 'Muhammad Zakria',
          'handle': 'zakria',
        },
      ]);
      final after = RealtimeEventParser.mergeSnapshot(hydrated, {
        'userId': 'user_a',
        'audioState': 'ON',
      });
      final p = after.participants.single;
      expect(p.displayName, 'Muhammad Zakria');
      expect(p.handle, 'zakria');
    });
  });
}
