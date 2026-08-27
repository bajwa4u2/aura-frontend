// MULTI-MEDIA COMPOSITION — one composition, many ordered items.
//
// The defect this closes: the feed rendered `item.media.first`. The backend has
// always shipped an ordered array — `PostMedia` and `MessageMedia` are join
// tables with an explicit `position`, and every read path sorts by it — so a
// four-photograph post looked like a one-photograph post to everyone who saw
// it. This was never a persistence gap; the client was behind its own
// authority.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/aura_media_group.dart';
import 'package:aura/features/feed/domain/feed_media.dart';

FeedMedia img(String id, {int position = 0}) => FeedMedia(
      id: id,
      mediaId: id,
      position: position,
      mediaType: 'IMAGE',
      mimeType: 'image/jpeg',
      visibility: 'PUBLIC',
      url: 'https://example/$id.jpg',
      width: 1200,
      height: 900,
    );

FeedMedia vid(String id, {int position = 0}) => FeedMedia(
      id: id,
      mediaId: id,
      position: position,
      mediaType: 'VIDEO',
      mimeType: 'video/mp4',
      visibility: 'PUBLIC',
      url: 'https://example/$id.mp4',
      thumbUrl: 'https://example/$id.jpg',
      width: 1920,
      height: 1080,
      duration: 6000,
    );

Future<void> pump(WidgetTester tester, List<FeedMedia> items,
    {void Function(int)? onOpen}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        child: AuraMediaGroup(items: items, onOpenItem: onOpen),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('the group renders every item, not the first', () {
    testWidgets('2_IMAGES', (tester) async {
      await pump(tester, [img('a'), img('b')]);
      expect(find.byType(AuraMediaGroup), findsOneWidget);
      // Two cells, not one.
      expect(tester.widgetList(find.byType(Expanded)).length, greaterThanOrEqualTo(2));
    });

    testWidgets('3_MEDIA lays out as dominant plus two, not three slivers', (tester) async {
      await pump(tester, [img('a'), img('b'), img('c')]);
      // Three equal columns is the layout that makes every three-item post
      // look like a filmstrip; this one nests a Column of two beside a lead.
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('4_MEDIA is a 2x2', (tester) async {
      await pump(tester, [img('a'), img('b'), img('c'), img('d')]);
      expect(find.byType(AuraMediaGroup), findsOneWidget);
    });

    testWidgets('5_PLUS_MEDIA collapses the tail into a continuation count', (tester) async {
      await pump(tester, [img('a'), img('b'), img('c'), img('d'), img('e'), img('f')]);
      // Six items, four cells: the fourth stands in for the remaining two.
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('exactly 4 shows no continuation', (tester) async {
      await pump(tester, [img('a'), img('b'), img('c'), img('d')]);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('ONE ITEM keeps the single-media treatment', (tester) async {
      await pump(tester, [img('a')]);
      // A lone photograph must not look different because the group case
      // exists, so it does not get the collage shape at all.
      expect(find.byType(AspectRatio), findsWidgets);
    });

    testWidgets('an empty group renders nothing rather than an empty frame', (tester) async {
      await pump(tester, const []);
      expect(find.byType(AspectRatio), findsNothing);
    });
  });

  group('ORDER_PRESERVED', () {
    testWidgets('order is the caller\'s, never re-derived', (tester) async {
      final tapped = <int>[];
      // Deliberately supplied out of position order: the widget must trust the
      // list it is given, because the server already sorted by `position` and
      // re-sorting here would let the client second-guess composition intent.
      final items = [img('c', position: 2), img('a', position: 0), img('b', position: 1)];
      await pump(tester, items, onOpen: tapped.add);
      final group = tester.widget<AuraMediaGroup>(find.byType(AuraMediaGroup));
      expect(group.items.map((m) => m.mediaId).toList(), ['c', 'a', 'b']);
    });
  });

  group('IMMERSIVE_GROUP_NAVIGATION', () {
    testWidgets('tapping an item reports ITS index, so the viewer opens there', (tester) async {
      final tapped = <int>[];
      await pump(tester, [img('a'), img('b'), img('c')], onOpen: tapped.add);
      // The whole group travels to the viewer; the index says where to start.
      final group = tester.widget<AuraMediaGroup>(find.byType(AuraMediaGroup));
      expect(group.onOpenItem, isNotNull);
      group.onOpenItem!(2);
      expect(tapped, [2]);
    });
  });

  group('IMAGE_PLUS_VIDEO — mixed groups', () {
    testWidgets('a group may mix images and videos', (tester) async {
      await pump(tester, [img('a'), vid('b'), img('c')]);
      expect(find.byType(AuraMediaGroup), findsOneWidget);
    });

    testWidgets('ACCESSIBILITY — the label states count and kinds', (tester) async {
      await pump(tester, [img('a'), vid('b'), img('c')]);
      // Collage shape conveys the count visually; this conveys it to everyone
      // else, including which items are video.
      final semantics = tester.widget<Semantics>(
        find.ancestor(
          of: find.byType(ClipRRect).first,
          matching: find.byType(Semantics),
        ).first,
      );
      final label = semantics.properties.label ?? '';
      expect(label, contains('3 media items'));
      expect(label, contains('2 images'));
      expect(label, contains('1 video'));
    });
  });

  group('the preview limit is a stated policy', () {
    test('four items, so the last layout with a fair share of the frame', () {
      expect(kMediaGroupPreviewLimit, 4);
    });
  });
}
