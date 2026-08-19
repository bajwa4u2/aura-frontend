// F116 — THE FINAL TWO FEED ACTORS, DISPOSITIONED.
//
// The founder brief asks a question rather than ordering a migration: are
// these two models a genuine PERSON | INSTITUTION actor union, or a person
// model with institution aliases mixed in? The answer is different for each,
// and it was taken from the backend that produces them, not from the field
// names.
//
//   FeedSignalActor  — TRUE UNION. `feed-signal.service.ts` builds it through
//                      two separate builders, `userActor` (person name/handle/
//                      avatar) and `institutionActor` (institution name/slug/
//                      logo), tagged `type: 'USER' | 'INSTITUTION'`. The union
//                      stays. What ends is the shared bag of normalized
//                      strings that let any caller read institution identity
//                      through a person-shaped accessor.
//
//   FeedReplyAuthor  — NOT a union. `feed-reply.service.ts` builds EVERY reply
//                      author through one builder, `userAuthor`, and routes it
//                      to `/u/:handle`. An institution never authors a reply;
//                      affiliation is expressed through `context`. The union
//                      aliases this model used to accept were a private person
//                      interpretation dressed as tolerance.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/identity/person_identity_model.dart';
import 'package:aura/features/feed/domain/feed_item.dart';

void main() {
  group('FeedSignalActor — a true PERSON | INSTITUTION union', () {
    test('a person actor is delegated to the canonical person authority', () {
      final actor = FeedSignalActor.fromJson(const {
        'id': 'u-1',
        'type': 'USER',
        'displayName': 'Yara Nasser',
        'handle': 'yara',
        'avatarUrl': 'https://cdn.example/y.png',
      })!;

      expect(actor.isInstitution, isFalse);
      expect(actor.person, isNotNull);
      expect(actor.person!.userId, 'u-1');
      expect(actor.label, 'Yara Nasser');
      expect(actor.handle, 'yara');
      expect(actor.avatarUrl, 'https://cdn.example/y.png');
    });

    test('an institution actor keeps institution identity in its own terms — '
        'and holds NO person', () {
      final actor = FeedSignalActor.fromJson(const {
        'id': 'i-1',
        'type': 'INSTITUTION',
        'displayName': 'Aura Clinic',
        'handle': 'aura-clinic',
        'avatarUrl': 'https://cdn.example/logo.png',
      })!;

      expect(actor.isInstitution, isTrue);
      // The whole point of the split: an institution's slug can no longer be
      // read out of a person-shaped accessor, because there is no person.
      expect(actor.person, isNull);
      expect(actor.institutionSlug, 'aura-clinic');
      expect(actor.label, 'Aura Clinic');
      expect(actor.avatarUrl, 'https://cdn.example/logo.png');
    });

    test('each side falls back in ITS OWN domain, not the other one', () {
      final person = FeedSignalActor.fromJson(const {
        'id': 'u-2',
        'type': 'USER',
        'handle': 'omar',
      })!;
      // The canonical person order — the same one every other surface uses.
      expect(person.label, '@omar');

      final institution = FeedSignalActor.fromJson(const {
        'id': 'i-2',
        'type': 'INSTITUTION',
        'handle': 'northgate',
      })!;
      // An institution is addressed by /slug. Two orders because there are two
      // identity domains, not because a surface re-decided one of them.
      expect(institution.label, '/northgate');
    });

    test('an actor with nothing at all is still not named after a person', () {
      final actor = FeedSignalActor.fromJson(const {
        'id': 'i-3',
        'type': 'INSTITUTION',
      })!;
      expect(actor.label, 'Someone');
      expect(actor.person, isNull);
    });

    test('the viewer flag is presentation state, not identity', () {
      final actor = FeedSignalActor.fromJson(const {
        'id': 'u-3',
        'type': 'USER',
        'displayName': 'Sami',
        'isViewer': true,
      })!;
      expect(actor.isViewer, isTrue);
      expect(actor.label, 'Sami');
    });
  });

  group('FeedReplyAuthor — a person model, now saying so', () {
    test('the author is the canonical person, route included', () {
      final author = FeedReplyAuthor.fromJson(const {
        'id': 'u-4',
        'displayName': 'Rana Khalil',
        'handle': 'rana',
        'avatarUrl': 'https://cdn.example/r.png',
      });

      expect(author.person, isNot(AuraPersonIdentity.unknown));
      expect(author.id, 'u-4');
      expect(author.displayName, 'Rana Khalil');
      expect(author.handle, 'rana');
      expect(author.profileRoute, '/u/rana');
    });

    test('an explicit profileRoute from the backend still wins', () {
      final author = FeedReplyAuthor.fromJson(const {
        'id': 'u-5',
        'handle': 'nadir',
        'profileRoute': '/u/nadir?from=feed',
      });
      expect(author.profileRoute, '/u/nadir?from=feed');
    });

    test('an unresolvable author is unknown — never invented', () {
      const author = FeedReplyAuthor();
      expect(author.person, AuraPersonIdentity.unknown);
      expect(author.id, '');
      expect(author.displayName, '');
      expect(author.profileRoute, isNull);
    });

    test('identity context stays context — it is not the author', () {
      final author = FeedReplyAuthor.fromJson(const {
        'id': 'u-6',
        'displayName': 'Tarek',
        'handle': 'tarek',
        'context': {'kind': 'INSTITUTION_MEMBER', 'label': 'Aura Clinic'},
      });

      expect(author.displayName, 'Tarek');
      expect(author.context, isNotNull);
      // The affiliation did NOT become the author.
      expect(author.person.displayName, 'Tarek');
    });
  });
}
