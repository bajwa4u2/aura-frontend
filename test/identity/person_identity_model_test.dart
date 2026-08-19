// F053 / F116 — THE CLIENT'S CANONICAL PERSON IDENTITY.
//
// The consumer audit measured 103 surfaces reading person fields off untyped
// maps and then named the cause: "the client has no single canonical identity
// model the way the backend now has PERSON_IDENTITY_SELECT." Every one of
// those sites is a symptom of that absence, which is why PB-05 forbids closing
// F116 by fixing one consumer.
//
// The reader is deliberately TOLERANT. F057 is why: the call room read
// `me['id']` while Conversation read `me['user']['id']`, so when /auth/me
// nested the person the realtime surface silently resolved an EMPTY id — host
// detection said "not host" and the participant lookup matched nobody. That
// was two hand-written readers of one payload disagreeing. One shared reader
// cannot disagree with itself.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/identity/person_identity_model.dart';

void main() {
  group('F057 — the nesting that cost us an identity', () {
    test('resolves a person at the TOP level', () {
      final p = AuraPersonIdentity.fromJson({
        'id': 'u1',
        'displayName': 'Ada Lovelace',
        'handle': 'ada',
        'avatarUrl': 'https://cdn.test/a.png',
      });
      expect(p.userId, 'u1');
      expect(p.displayName, 'Ada Lovelace');
      expect(p.handle, 'ada');
      expect(p.avatarUrl, 'https://cdn.test/a.png');
    });

    test('resolves the SAME person nested under `user` — the F057 payload', () {
      final p = AuraPersonIdentity.fromJson({
        'user': {'id': 'u1', 'displayName': 'Ada Lovelace', 'handle': 'ada'},
      });
      expect(p.userId, 'u1', reason: 'This is the id that resolved EMPTY.');
      expect(p.displayName, 'Ada Lovelace');
    });

    test('resolves through every envelope Aura actually uses', () {
      for (final key in const [
        'user',
        'author',
        'sender',
        'senderUser',
        'actor',
        'member',
        'participant',
        'counterpart',
        'profile',
      ]) {
        final p = AuraPersonIdentity.fromJson({
          key: {'id': 'u1', 'handle': 'ada'},
        });
        expect(p.userId, 'u1', reason: key);
        expect(p.handle, 'ada', reason: key);
      }
    });

    test('a person named DIRECTLY wins over a nested envelope', () {
      // Otherwise a message's own `user` key could shadow the author the
      // caller actually passed in.
      final p = AuraPersonIdentity.fromJson({
        'displayName': 'Direct Person',
        'handle': 'direct',
        'user': {'displayName': 'Nested Person', 'handle': 'nested'},
      });
      expect(p.displayName, 'Direct Person');
    });

    test('accepts the field aliases the API actually emits', () {
      expect(AuraPersonIdentity.fromJson({'name': 'Ada'}).displayName, 'Ada');
      expect(
          AuraPersonIdentity.fromJson({'fullName': 'Ada'}).displayName, 'Ada');
      expect(AuraPersonIdentity.fromJson({'username': 'ada'}).handle, 'ada');
      expect(
          AuraPersonIdentity.fromJson({'handle': 'ada', 'photoUrl': 'x'})
              .avatarUrl,
          'x');
      expect(AuraPersonIdentity.fromJson({'userId': 'u9'}).userId, 'u9');
    });

    test('an id-only payload is still a person — anonymous, but resolvable',
        () {
      final p = AuraPersonIdentity.fromJson({'id': 'u1'});
      expect(p.userId, 'u1');
      expect(p.isNotEmpty, isTrue);
    });
  });

  group('F054 — a surface must not invent a name for someone', () {
    test('the fallback order is name, then handle, then a neutral word', () {
      expect(
        AuraPersonIdentity.fromJson({'displayName': 'Ada', 'handle': 'ada'})
            .label,
        'Ada',
      );
      expect(AuraPersonIdentity.fromJson({'handle': 'ada'}).label, '@ada');
      expect(AuraPersonIdentity.fromJson({'id': 'u1'}).label, 'Someone');
    });

    test('it is NEVER "Participant" or "User"', () {
      // F054's defect was a surface labelling someone it had failed to
      // resolve. A shared fallback is the only way that stops being
      // re-decided per screen.
      final label = AuraPersonIdentity.fromJson({'id': 'u1'}).label;
      expect(label, isNot('Participant'));
      expect(label, isNot('User'));
    });

    test('prose names a person WITHOUT the @ — a sentence is not a mention', () {
      // "amjad sent you a message" reads correctly; "@amjad sent you a
      // message" does not. Same fallback ORDER, different decoration.
      final p = AuraPersonIdentity.fromJson({'handle': 'amjad'});
      expect(p.proseName, 'amjad');
      expect(p.label, '@amjad');
      expect(AuraPersonIdentity.fromJson({'displayName': 'Ada'}).proseName,
          'Ada');
      expect(AuraPersonIdentity.unknown.proseName, 'Someone');
    });

    test('whitespace-only fields do not count as a name', () {
      expect(
        AuraPersonIdentity.fromJson({'displayName': '   ', 'handle': 'ada'})
            .label,
        '@ada',
      );
    });
  });

  group('the reader refuses to guess', () {
    test('a payload with a face but NO identity is not a person', () {
      // Rendering an avatar for someone the payload never identified is a
      // face with nobody behind it.
      expect(AuraPersonIdentity.fromJson({'avatarUrl': 'https://cdn/x.png'}),
          AuraPersonIdentity.unknown);
    });

    test('null, a non-map, and an empty map all resolve to unknown', () {
      for (final input in [null, 'string', 42, <String, dynamic>{}]) {
        expect(AuraPersonIdentity.fromJson(input), AuraPersonIdentity.unknown,
            reason: '$input');
      }
    });

    test('unknown is empty, and says so rather than throwing', () {
      expect(AuraPersonIdentity.unknown.isEmpty, isTrue);
      expect(AuraPersonIdentity.unknown.label, 'Someone');
      expect(AuraPersonIdentity.unknown.profileRoute, isNull);
    });

    test('a person with no handle has no profile route to offer', () {
      // A route that cannot resolve is worse than no affordance at all.
      expect(AuraPersonIdentity.fromJson({'displayName': 'Ada'}).profileRoute,
          isNull);
      expect(AuraPersonIdentity.fromJson({'handle': 'ada'}).profileRoute,
          '/u/ada');
    });
  });

  group('the shape matches the backend projection', () {
    test('it carries exactly what PERSON_IDENTITY_SELECT projects', () {
      // A client shape that disagrees with the projection would simply be the
      // 104th private person model.
      final p = AuraPersonIdentity.fromJson({
        'id': 'u1',
        'handle': 'ada',
        'displayName': 'Ada',
        'avatarUrl': 'https://cdn.test/a.png',
        'accountStatus': 'ACTIVE',
      });
      expect(p.userId, 'u1');
      expect(p.handle, 'ada');
      expect(p.displayName, 'Ada');
      expect(p.avatarUrl, 'https://cdn.test/a.png');
      expect(p.accountStatus, 'ACTIVE');
    });

    test('lifecycle is carried so a deleted author renders truthfully', () {
      final p = AuraPersonIdentity.fromJson({
        'id': 'u1',
        'displayName': 'Ada',
        'accountStatus': 'DELETED',
      });
      expect(p.accountStatus, 'DELETED');
      expect(p.label, 'Ada',
          reason: 'Identity resolves even when the account no longer acts.');
    });

    test('two readings of the same payload are equal', () {
      const payload = {'id': 'u1', 'handle': 'ada', 'displayName': 'Ada'};
      expect(AuraPersonIdentity.fromJson(payload),
          AuraPersonIdentity.fromJson(payload));
      expect(AuraPersonIdentity.fromJson(payload).hashCode,
          AuraPersonIdentity.fromJson(payload).hashCode);
    });

    test('the nested and flat forms of one person are the SAME person', () {
      // The property F057 needed and did not have.
      expect(
        AuraPersonIdentity.fromJson(
            {'user': {'id': 'u1', 'handle': 'ada', 'displayName': 'Ada'}}),
        AuraPersonIdentity.fromJson(
            {'id': 'u1', 'handle': 'ada', 'displayName': 'Ada'}),
      );
    });
  });
}
