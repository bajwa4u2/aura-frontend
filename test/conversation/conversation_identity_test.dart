import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/conversation/data/conversations_repository.dart';
import 'package:aura/features/conversation/presentation/conversation_identity.dart';

/// WHOSE CORRESPONDENCE IS THIS?
///
/// A different question from "who is still taking part", and the two had one
/// implementation. Observed on a physical Pixel, 2026-08-24: the reviewer left
/// a direct conversation and the other person's inbox row and header both
/// collapsed to the word "Conversation" over a letter tile. Every message was
/// still there. There was simply no longer any indication of whose they were.
void main() {
  Conversation conv(List<Map<String, dynamic>> parties, {String? name}) {
    return Conversation.fromJson({
      'id': 'c1',
      'name': name,
      'isDirect': parties.length <= 2,
      'parties': parties,
    });
  }

  Map<String, dynamic> person(
    String id,
    String display, {
    String? leftAt,
    String? firstJoinedAt,
  }) =>
      {
        'kind': 'PERSON',
        'userId': id,
        'displayName': display,
        'leftAt': leftAt,
        'firstJoinedAt': firstJoinedAt ?? '2026-01-01T00:00:00.000Z',
        'joinedAt': firstJoinedAt ?? '2026-01-01T00:00:00.000Z',
      };

  const me = 'me';

  group('a correspondence keeps its identity when the other person leaves', () {
    test('a direct conversation is still named after them', () {
      final c = conv([
        person(me, 'Me'),
        person('them', 'Aura Reviewer', leftAt: '2026-08-24T16:38:00.000Z'),
      ]);
      expect(conversationDisplayName(c, me), 'Aura Reviewer');
    });

    test('their face does not become a letter tile', () {
      final c = Conversation.fromJson({
        'id': 'c1',
        'isDirect': true,
        'parties': [
          person(me, 'Me'),
          {
            ...person('them', 'Aura Reviewer',
                leftAt: '2026-08-24T16:38:00.000Z'),
            'avatarUrl': 'https://example.invalid/a.png',
          },
        ],
      });
      expect(conversationDisplayAvatarUrl(c, me),
          'https://example.invalid/a.png');
    });

    test('a group that has emptied out is still named after its people', () {
      final c = conv([
        person(me, 'Me'),
        person('a', 'Amina', leftAt: '2026-08-01T00:00:00.000Z'),
        person('b', 'Tariq', leftAt: '2026-08-02T00:00:00.000Z'),
      ]);
      expect(conversationDisplayName(c, me), contains('Amina'));
      expect(conversationDisplayName(c, me), contains('Tariq'));
    });
  });

  group('participation and naming stay separate questions', () {
    test('while anyone is still active, only the active are named', () {
      // Naming must NOT quietly start listing people who left while the
      // conversation is still live — that would misreport who can read it.
      final c = conv([
        person(me, 'Me'),
        person('a', 'Amina'),
        person('b', 'Tariq', leftAt: '2026-08-02T00:00:00.000Z'),
      ]);
      expect(conversationDisplayName(c, me), 'Amina');
      expect(orderedOtherParties(c, me).length, 1);
    });

    test('the participation set itself is unchanged by naming', () {
      final c = conv([
        person(me, 'Me'),
        person('them', 'Aura Reviewer', leftAt: '2026-08-24T16:38:00.000Z'),
      ]);
      // Nobody is active — that is the truthful answer, and it is what any
      // caller asking "who can see what is said next" must still receive.
      expect(orderedOtherParties(c, me), isEmpty);
      expect(namingParties(c, me).length, 1);
    });

    test('a custom name still wins over both', () {
      final c = conv([
        person(me, 'Me'),
        person('them', 'Aura Reviewer', leftAt: '2026-08-24T16:38:00.000Z'),
      ], name: 'Budget thread');
      expect(conversationDisplayName(c, me), 'Budget thread');
    });
  });

  test('a conversation with genuinely nobody else still says something', () {
    final c = conv([person(me, 'Me')]);
    expect(conversationDisplayName(c, me), isNotEmpty);
  });
}
