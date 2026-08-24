import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FOLLOW MUST GO THROUGH THE FOLLOWS AUTHORITY.
///
/// Founder live finding, 2026-08-24: "follow people i meant, spaces and
/// institution works".
///
/// The person card hand-rolled `POST /follows` with `{targetType,
/// targetUserId}` and no actor. `actorType` is REQUIRED by FollowPairDto, so
/// every tap was a 400 and the button silently did nothing. Spaces and
/// Institutions worked because they went through their authorities — Spaces
/// via `/follows/space/:slug`, Institutions via the follows repository with an
/// explicit actor.
///
/// This was inherited: the card was extracted from the People screen, so
/// Follow had been broken there too, on a surface with tests that all passed.
/// Hand-rolling the request is the defect, so that is what is asserted
/// against.
void main() {
  String codeOnly(String src) => src
      .split(String.fromCharCode(10))
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('///') && !t.startsWith('*');
      })
      .join(String.fromCharCode(10));

  final cards = <String, String>{
    'person': 'lib/features/discover/widgets/person_suggestion_card.dart',
    'space+institution': 'lib/features/discover/widgets/discover_domain_cards.dart',
  };

  group('no discovery surface hand-rolls a follow', () {
    for (final entry in cards.entries) {
      test('${entry.key} card does not post /follows itself', () {
        final code = codeOnly(File(entry.value).readAsStringSync());
        expect(code.contains("post<dynamic>('/follows'"), isFalse,
            reason: 'the authority owns how a follow is addressed');
        expect(code.contains("'/follows'"), isFalse);
      });
    }

    test('following a PERSON goes through the consent-required request', () {
      // Person-to-person following is request-then-accept by frozen product
      // design. POST /follows refuses USER -> USER outright, so a card that
      // called it was wrong twice: wrong shape and wrong authority.
      final code = codeOnly(File(cards['person']!).readAsStringSync());
      expect(code, contains('profileRepositoryProvider'));
      expect(code, contains('.follow(handle)'));
      expect(code.contains('followsRepositoryProvider'), isFalse,
          reason: 'that authority is for institutions; people need consent');
    });

    test('a person with no handle is not offered a control that cannot work',
        () {
      // The request endpoint is addressed by handle. Aura Reviewer — the only
      // suggestion in production — has none, so the button would always fail.
      final code = codeOnly(File(cards['person']!).readAsStringSync());
      expect(code, contains('if (widget.suggestion.handle == null)'));
    });

    test('a sent request reads as REQUESTED, never as FOLLOWING', () {
      // The other person has not accepted. Claiming otherwise describes a
      // relationship that does not exist.
      final code = codeOnly(File(cards['person']!).readAsStringSync());
      expect(code, contains("_localState = 'REQUESTED'"));
    });

    test('the institution card follows as the PERSON, not as an institution',
        () {
      // C1 — acting context is per-act. Discovering an institution and
      // following it is a personal act; following as an institution the viewer
      // happens to speak for would be a different statement entirely.
      final code = codeOnly(File(cards['space+institution']!).readAsStringSync());
      expect(code, contains('ActorRef.user('));
      expect(code, contains('ActorRef.institution('));
      expect(code, contains('actor: actor'));
    });

    test('institution follow state comes from the server, never assumed', () {
      final code = codeOnly(File(cards['space+institution']!).readAsStringSync());
      // The Space card takes the server's boolean rather than its own guess.
      expect(code, contains('ok ? next : !next'));
    });
  });

  group('the endpoint contract the client must satisfy', () {
    test('POST /follows refuses person-to-person, and says where to go', () {
      // Read from the backend so this fails if the product rule changes,
      // rather than encoding a copy that drifts.
      final svc = File('../aura-backend/src/follows/follows.service.ts');
      if (!svc.existsSync()) return; // backend not checked out beside this repo
      final src = svc.readAsStringSync();
      expect(src, contains('Aura follow requires a request'));
      expect(src, contains('/users/:handle/follow/request'));
    });

    test('actorType is required by FollowPairDto', () {
      // Read from the backend so this test fails if the contract changes,
      // rather than encoding a copy of it that can drift.
      final dto = File(
        '../aura-backend/src/follows/dto/follow-pair.dto.ts',
      );
      if (!dto.existsSync()) return; // backend not checked out beside this repo
      final src = dto.readAsStringSync();
      final actorType = src.indexOf('actorType!');
      expect(actorType, greaterThan(0));
      // The decorators immediately above it must not include @IsOptional.
      final preceding = src.substring(0, actorType);
      final lastOptional = preceding.lastIndexOf('@IsOptional');
      final lastIsIn = preceding.lastIndexOf('@IsIn');
      expect(lastIsIn, greaterThan(lastOptional),
          reason: 'actorType is mandatory — a follow without an actor is a 400');
    });
  });
}
