import 'package:aura/core/tagging/tag_entities.dart';
import 'package:aura/features/public/widgets/mention_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A picked mention renders the same everywhere: a post, a reply, a thread
/// header and a message draw the recorded tag as "@<name>", accent, w800,
/// tappable, and a click target with a pointer on desktop and the web
/// (21 Oct 2026: a picked "@bajwawrites" otherwise drew as plain text).
void main() {
  const ref = TagReference(
    kind: TagKind.member,
    canonicalId: 'user-b',
    display: 'M S Bajwa',
    insertText: '@bajwawrites',
    sourceText: '@bajwawrites',
    startOffset: 7,
    endOffset: 19,
    identity: TagIdentity(
      id: 'user-b',
      type: 'member',
      displayLabel: 'M S Bajwa',
      handleOrSlug: 'bajwawrites',
      route: '/u/bajwawrites',
    ),
  );

  testWidgets('a recorded mention draws as the name, styled, tappable, clickable',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ResolvedTagText(
          'Thanks @bajwawrites for this',
          tagReferences: [ref],
        ),
      ),
    ));

    TextSpan? hit;
    void visit(InlineSpan s) {
      if (s is TextSpan) {
        if (s.text == '@M S Bajwa') hit = s;
        for (final c in s.children ?? const <InlineSpan>[]) {
          visit(c);
        }
      }
    }

    for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
      visit(w.text);
    }
    expect(hit, isNotNull);
    expect(hit!.style?.fontWeight, FontWeight.w800);
    expect(hit!.recognizer, isNotNull);
    expect(hit!.mouseCursor, SystemMouseCursors.click);
  });

  test('ranges come from the record, falling back to the text', () {
    final ranges = resolvedTagRanges('Thanks @bajwawrites for this', [ref]);
    expect(ranges.single.start, 7);
    expect(ranges.single.end, 19);
    final moved = resolvedTagRanges('Hi @bajwawrites', [ref]);
    expect(moved.single.start, 3);
  });
}
