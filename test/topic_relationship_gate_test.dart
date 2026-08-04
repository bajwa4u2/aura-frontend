import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/topics/topic.dart';
import 'package:aura/features/topics/topic_repository.dart';

void main() {
  group('parseApprovedSecondaries — GET /topics/:primary/secondaries', () {
    test('parses topic + strength pairs from a well-formed response', () {
      final result = parseApprovedSecondaries({
        'primary': 'EDUCATION',
        'approved': [
          {'topic': 'EMPLOYMENT', 'strength': 'STRONG'},
          {'topic': 'RESEARCH', 'strength': 'STRONG'},
          {'topic': 'COMMUNITY', 'strength': 'MODERATE'},
        ],
      });

      expect(result.length, 3);
      expect(result[0].topic, AuraTopic.employment);
      expect(result[0].strength, 'STRONG');
      expect(result[2].topic, AuraTopic.community);
      expect(result[2].strength, 'MODERATE');
    });

    test('skips entries with an unrecognized topic token', () {
      final result = parseApprovedSecondaries({
        'approved': [
          {'topic': 'EMPLOYMENT', 'strength': 'STRONG'},
          {'topic': 'NOT_A_REAL_TOPIC', 'strength': 'STRONG'},
        ],
      });
      expect(result.length, 1);
      expect(result.first.topic, AuraTopic.employment);
    });

    test('malformed or missing "approved" yields an empty list, not an error', () {
      expect(parseApprovedSecondaries(null), isEmpty);
      expect(parseApprovedSecondaries(<String, dynamic>{}), isEmpty);
      expect(parseApprovedSecondaries({'approved': 'not a list'}), isEmpty);
      expect(parseApprovedSecondaries('not even a map'), isEmpty);
    });
  });

  group('parseSuggestionResult — POST /topics/suggest-secondary', () {
    test('parses ranked suggestions and the mode flag', () {
      final result = parseSuggestionResult({
        'suggestions': [
          {'topic': 'EMPLOYMENT', 'strength': 'STRONG', 'score': 3.0},
          {'topic': 'RESEARCH', 'strength': 'STRONG', 'score': 1.2},
        ],
        'mode': 'ai',
      });

      expect(result.mode, 'ai');
      expect(result.suggestions, [AuraTopic.employment, AuraTopic.research]);
    });

    test('defaults mode to keyword and suggestions to empty on malformed data', () {
      final result = parseSuggestionResult(<String, dynamic>{});
      expect(result.mode, 'keyword');
      expect(result.suggestions, isEmpty);

      final result2 = parseSuggestionResult(null);
      expect(result2.mode, 'keyword');
      expect(result2.suggestions, isEmpty);
    });
  });
}
