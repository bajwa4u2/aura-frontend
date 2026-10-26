import 'package:aura/core/media/trace/aura_trace.dart';
import 'package:aura/features/feed/domain/post.dart';
import 'package:flutter_test/flutter_test.dart';

/// A post's own page reads a typed Post. Its media dropped `trace`, so TR
/// showed on a post in the feed and vanished when the post was opened
/// (2026-10-26).
void main() {
  test('typed post media keeps the Trace the server sent', () {
    final item = PostMediaItem.fromJson({
      'id': 'm1',
      'type': 'IMAGE',
      'url': 'https://api.auraplatform.org/v1/media/m1/raw',
      'trace': {
        'available': true,
        'headline': 'Created with AI',
        'source': 'OpenAI',
        'evidence': const [],
        'history': const [],
        'uncertainty': const [],
      },
    });
    final trace = AuraTrace.fromJson(item.toJson()['trace']);
    expect(trace.isNotEmpty, isTrue);
    expect(trace.headline, 'Created with AI');
  });

  test('media without a Trace stays without one', () {
    final item = PostMediaItem.fromJson({'id': 'm2', 'type': 'IMAGE'});
    expect(item.toJson().containsKey('trace'), isFalse);
    expect(AuraTrace.fromJson(item.toJson()['trace']).isEmpty, isTrue);
  });
}
