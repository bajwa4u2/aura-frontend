import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/topics/topic.dart';
import 'package:aura/features/topics/topic_repository.dart';

void main() {
  group('parseApprovedSecondaries — GET /topics/:primary/secondaries', () {
    test(
      'parses topic + strength pairs from the real API envelope ({ok, data})',
      () {
        // This is the actual production response shape — every backend
        // response is wrapped by ResponseWrapInterceptor ("Aura Contract
        // v1"): { ok: true, data: <payload> }. A prior version of this
        // parser read fields off the top level and silently returned an
        // empty list against this exact shape in production.
        final result = parseApprovedSecondaries({
          'ok': true,
          'data': {
            'primary': 'EDUCATION',
            'approved': [
              {'topic': 'EMPLOYMENT', 'strength': 'STRONG'},
              {'topic': 'RESEARCH', 'strength': 'STRONG'},
              {'topic': 'COMMUNITY', 'strength': 'MODERATE'},
            ],
          },
        });

        expect(result.length, 3);
        expect(result[0].topic, AuraTopic.employment);
        expect(result[0].strength, 'STRONG');
        expect(result[2].topic, AuraTopic.community);
        expect(result[2].strength, 'MODERATE');
      },
    );

    test('skips entries with an unrecognized topic token', () {
      final result = parseApprovedSecondaries({
        'data': {
          'approved': [
            {'topic': 'EMPLOYMENT', 'strength': 'STRONG'},
            {'topic': 'NOT_A_REAL_TOPIC', 'strength': 'STRONG'},
          ],
        },
      });
      expect(result.length, 1);
      expect(result.first.topic, AuraTopic.employment);
    });

    test(
      'also accepts an unwrapped (flat) response, for resilience against non-enveloped endpoints',
      () {
        final result = parseApprovedSecondaries({
          'approved': [
            {'topic': 'EMPLOYMENT', 'strength': 'STRONG'},
          ],
        });
        expect(result.length, 1);
        expect(result.first.topic, AuraTopic.employment);
      },
    );

    test('malformed or missing "approved" yields an empty list, not an error', () {
      expect(parseApprovedSecondaries(null), isEmpty);
      expect(parseApprovedSecondaries(<String, dynamic>{}), isEmpty);
      expect(parseApprovedSecondaries({'data': {}}), isEmpty);
      expect(
        parseApprovedSecondaries({
          'data': {'approved': 'not a list'},
        }),
        isEmpty,
      );
      expect(parseApprovedSecondaries('not even a map'), isEmpty);
    });
  });

  group('parseSuggestionResult — POST /topics/suggest-secondary', () {
    test('parses ranked suggestions and the mode flag from the real API envelope', () {
      final result = parseSuggestionResult({
        'ok': true,
        'data': {
          'suggestions': [
            {'topic': 'EMPLOYMENT', 'strength': 'STRONG', 'score': 3.0},
            {'topic': 'RESEARCH', 'strength': 'STRONG', 'score': 1.2},
          ],
          'mode': 'ai',
        },
      });

      expect(result.mode, 'ai');
      expect(result.suggestions, [AuraTopic.employment, AuraTopic.research]);
    });

    test(
      'also accepts an unwrapped (flat) response, for resilience against non-enveloped endpoints',
      () {
        final result = parseSuggestionResult({
          'suggestions': [
            {'topic': 'EMPLOYMENT'},
          ],
          'mode': 'keyword',
        });
        expect(result.mode, 'keyword');
        expect(result.suggestions, [AuraTopic.employment]);
      },
    );

    test('defaults mode to keyword and suggestions to empty on malformed data', () {
      final result = parseSuggestionResult(<String, dynamic>{});
      expect(result.mode, 'keyword');
      expect(result.suggestions, isEmpty);

      final result2 = parseSuggestionResult(null);
      expect(result2.mode, 'keyword');
      expect(result2.suggestions, isEmpty);

      final result3 = parseSuggestionResult({'data': {}});
      expect(result3.mode, 'keyword');
      expect(result3.suggestions, isEmpty);
    });
  });
}
