// F053/F116 — ROUTEDRECORD'S ACTOR DOMAIN, SETTLED BY ITS PRODUCER.
//
// The model read `['handle', 'handleOrSlug']`, and `handleOrSlug` is the
// normalised field a person's handle and an institution's slug share. Holding
// that value, a consumer could not tell which authority owned it.
//
// The producer answers it. `InstitutionEngagementService.toDto` builds the
// author from `row.post.author` — a User relation — selected with
// `PERSON_REFERENCE_SELECT`, and emits `{ id, handle, displayName, avatarUrl }`.
// No institution branch exists on this contract and `handleOrSlug` is never
// emitted. The union was not lossy and not deliberate: it did not exist. The
// repair is to stop reading a field the server never sends, not to add an
// actorType to discriminate a union of one.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/identity/person_identity_model.dart';
import 'package:aura/features/institutions/engagement/engagement_models.dart';

Map<String, dynamic> record(Map<String, dynamic> author) => {
      'id': 'rec-1',
      'institutionId': 'inst-1',
      'status': 'PENDING',
      'post': {'id': 'post-1', 'author': author},
    };

void main() {
  group('RoutedRecord — the author is a PERSON, and says so', () {
    test('the real producer shape resolves canonically', () {
      // Exactly what PERSON_REFERENCE_SELECT emits.
      final r = RoutedRecord.fromJson(record(const {
        'id': 'u-1',
        'handle': 'imran',
        'displayName': 'Imran Qadir',
        'avatarUrl': 'https://cdn.example/i.png',
      }));

      expect(r.author.userId, 'u-1');
      expect(r.authorName, 'Imran Qadir');
      expect(r.authorHandle, 'imran');
      expect(r.author.avatarUrl, 'https://cdn.example/i.png');
    });

    test('the author is typed as a person — no consumer has to guess which '
        'identity authority owns the value', () {
      final r = RoutedRecord.fromJson(record(const {'id': 'u-2', 'handle': 'sara'}));

      // The domain is carried by the TYPE, not inferred from string shape,
      // route prefix, avatar presence or UI context.
      expect(r.author, isA<AuraPersonIdentity>());
      expect(r.author.profileRoute, '/u/sara');
    });

    test('a handle-only author is named by the canonical order', () {
      final r = RoutedRecord.fromJson(record(const {'id': 'u-3', 'handle': 'nadia'}));
      expect(r.authorName, '@nadia');
    });

    test('an unnamed author is omitted, never invented', () {
      // Both engagement screens hide the byline when this is empty. Answering
      // with the shared neutral word would print 'Someone' under a post.
      final r = RoutedRecord.fromJson(record(const {'id': 'u-4'}));
      expect(r.authorName, isNull);
      expect(r.authorName, isNot('Someone'));
      expect(r.authorHandle, isNull);
    });

    test('a record with no author at all is safe', () {
      final r = RoutedRecord.fromJson(const {
        'id': 'rec-2',
        'institutionId': 'inst-1',
        'status': 'PENDING',
        'post': {'id': 'post-2'},
      });

      expect(r.author, AuraPersonIdentity.unknown);
      expect(r.authorName, isNull);
    });

    test('the record keeps its own engagement state beside the person', () {
      final r = RoutedRecord.fromJson({
        ...record(const {'id': 'u-5', 'displayName': 'Layla'}),
        'participationMode': 'OPEN',
      });

      expect(r.id, 'rec-1');
      expect(r.institutionId, 'inst-1');
      expect(r.status, RoutedRecordStatus.pending);
      expect(r.participationMode, 'OPEN');
      expect(r.authorName, 'Layla');
    });
  });
}
