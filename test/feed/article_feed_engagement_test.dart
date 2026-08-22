import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ARTICLES ENGAGE THROUGH THE PUBLICATION AUTHORITY, NOT THE POST ENDPOINT.
//
// Before this, an ARTICLE feed item fell through `_reactionTargetFor` to
// `PostReactionTarget(item.id)` — an Article id addressed to the Post reaction
// endpoint. That is worse than a missing control: it is a reaction aimed at the
// wrong object.
//
// The rule is that the card consumes the SAME canonical engagement authority
// the article reader consumes, so counts and actor state are one truth. There
// is deliberately no feed-private article engagement.
void main() {
  final card = File(
    'lib/features/feed/presentation/unified_feed_card.dart',
  ).readAsStringSync();

  test('an article card renders the canonical publication engagement bar', () {
    expect(card, contains('AuraEngagementBar('));
    expect(card, contains('PublicationTarget.article'));
  });

  test('an article never resolves to a Post reaction target', () {
    final marker = card.indexOf('if (item.type == FeedItemType.article) return null;');
    final fallback = card.indexOf('return PostReactionTarget(item.id);');

    expect(marker, greaterThan(-1),
        reason: 'articles must be excluded before the post fallback');
    expect(fallback, greaterThan(-1));
    expect(marker, lessThan(fallback),
        reason: 'the exclusion has to come BEFORE the fallback, or an Article '
            'id is posted to the Post reaction endpoint');
  });
}
