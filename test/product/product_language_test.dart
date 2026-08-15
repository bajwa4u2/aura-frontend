import 'package:aura/core/product/product_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product Language Authority — canonical nouns', () {
    test('every noun has a distinct key', () {
      final keys = ProductNoun.all.map((n) => n.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('frozen distinctions are not collapsed', () {
      // These pairs are separate product concepts by founder decision (FD-10).
      expect(ProductNoun.thread.key, isNot(ProductNoun.space.key));
      expect(ProductNoun.meeting.key, isNot(ProductNoun.room.key));
      expect(ProductNoun.room.key, isNot(ProductNoun.live.key));
      expect(ProductNoun.member.key, isNot(ProductNoun.participant.key));
      expect(ProductNoun.correspondence.key, isNot(ProductNoun.message.key));
      expect(ProductNoun.person.key, isNot(ProductNoun.institution.key));
    });

    test('correspondence is a mass noun and is not pluralised', () {
      expect(ProductNoun.correspondence.plural, 'Correspondence');
    });
  });

  group('Product Language Authority — actions', () {
    test('every action has exactly one canonical label', () {
      for (final action in ProductAction.values) {
        expect(
          () => ProductLabels.of(action),
          returnsNormally,
          reason: '$action has no canonical label',
        );
        expect(ProductLabels.of(action).trim(), isNotEmpty);
      }
    });

    test('retry is the single word for the failed-operation action', () {
      expect(ProductLabels.of(ProductAction.retry), 'Retry');
      for (final phrase in const ['try again', 'retry operation', 'try once more']) {
        expect(
          ProductLabels.prohibitedActionSynonyms[phrase],
          ProductAction.retry,
          reason: '$phrase must resolve to the canonical retry action',
        );
      }
    });

    test('the four stop intents produce four distinct labels', () {
      // FD-10 correction: Cancel / Dismiss / Close / Discard are NOT synonyms.
      final labels =
          StopIntent.values.map(ProductLabels.forStop).toList();
      expect(labels.toSet().length, StopIntent.values.length);
      expect(ProductLabels.forStop(StopIntent.cancel), 'Cancel');
      expect(ProductLabels.forStop(StopIntent.dismiss), 'Dismiss');
      expect(ProductLabels.forStop(StopIntent.close), 'Close');
      expect(ProductLabels.forStop(StopIntent.discard), 'Discard');
    });

    test('attribution switching resolves to one semantic action', () {
      // Approved C0 extension, 2026-08-15 (discovered through C1).
      expect(ProductLabels.of(ProductAction.switchIdentity), 'Switch identity');
      for (final phrase in const [
        'change publisher',
        'change sender',
        'change speaker',
        'change institution',
        'change identity',
      ]) {
        expect(ProductLabels.prohibitedActionSynonyms[phrase],
            ProductAction.switchIdentity);
      }
    });

    test('every prohibited synonym maps to a real canonical action', () {
      for (final e in ProductLabels.prohibitedActionSynonyms.entries) {
        expect(() => ProductLabels.of(e.value), returnsNormally,
            reason: '${e.key} maps to an action with no label');
      }
    });

    test('no canonical label is itself a prohibited synonym', () {
      final prohibited = ProductLabels.prohibitedActionSynonyms.keys.toSet();
      for (final action in ProductAction.values) {
        expect(prohibited.contains(ProductLabels.of(action).toLowerCase()),
            isFalse);
      }
    });
  });
}
