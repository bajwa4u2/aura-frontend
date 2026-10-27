import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/institutions/domain/explore_feed_item.dart';

// The public feed now carries announcements and articles (2026-10-27); the
// Explore parser must skip kinds it does not draw, never misread them as a
// person's post.
void main() {
  test('a person post and an untyped row still parse as person posts', () {
    expect(ExploreFeedItem.fromJson({'id': 'p1', 'text': 'hi', 'kind': 'POST'}), isA<ExploreUserPost>());
    expect(ExploreFeedItem.fromJson({'id': 'p2', 'text': 'hi'}), isA<ExploreUserPost>());
  });

  test('announcements and articles are skipped, not drawn as person posts', () {
    expect(ExploreFeedItem.fromJson({'id': 'a1', 'kind': 'ANNOUNCEMENT'}), isNull);
    expect(ExploreFeedItem.fromJson({'id': 'r1', 'kind': 'ARTICLE'}), isNull);
  });
}
