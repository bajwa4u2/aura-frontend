import 'package:aura/features/composition/domain/composition_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Built from a real production response (8 Oct 2026). The panel read a flat
/// top-level `findings` list and so never showed a finding.
void main() {
  final live = <String, dynamic>{
    'ok': true,
    'data': {
      'sessionId': 'sess_1',
      'intensity': 'FULL',
      'findings': {
        'integrity': [
          {
            'id': 'f1',
            'chapter': 'INTEGRITY',
            'state': 'ATTENTION',
            'message': 'This reads as a factual claim.',
            'suggestion': 'Add support or a little context.',
          },
        ],
        'language': [
          {
            'id': 'f2',
            'chapter': 'LANGUAGE',
            'state': 'ATTENTION',
            'message': 'A refined wording pass is available.',
            'action': {'type': 'RESTRUCTURE_BLOCK', 'preview': 'Our office is closed on Monday.'},
          },
        ],
        'media': [
          {'id': 'f3', 'chapter': 'MEDIA', 'state': 'OK', 'message': 'No media attached.'},
        ],
      },
    },
  };

  test('reads the enveloped, chapter-grouped findings', () {
    final r = CompositionReviewResult.fromJson(live);
    expect(r.sessionId, 'sess_1');
    expect(r.suggestions.map((s) => s.id), ['f1', 'f2'], reason: 'OK items are not suggestions');
  });

  test('only a finding with an action can be applied, with its preview', () {
    final r = CompositionReviewResult.fromJson(live);
    final advice = r.suggestions.firstWhere((s) => s.id == 'f1');
    final rewrite = r.suggestions.firstWhere((s) => s.id == 'f2');
    expect(advice.canApply, isFalse);
    expect(advice.message, 'This reads as a factual claim. Add support or a little context.');
    expect(rewrite.canApply, isTrue);
    expect(rewrite.replacement, 'Our office is closed on Monday.');
  });

  test('still reads the older flat shape', () {
    final r = CompositionReviewResult.fromJson({
      'sessionId': 's',
      'findings': [
        {'id': 'a', 'message': 'm', 'replacement': 'r', 'canApply': true},
      ],
    });
    expect(r.suggestions.single.replacement, 'r');
  });
}
