import 'package:aura/core/media/aura_media_frame.dart';
import 'package:aura/core/media/trace/media_corner_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// TR SITS ON THE MEDIA'S OWN CORNER (founder, 2026-10-26: "its disconnected
/// from media in feeds it has to be in left bottom corner of media").
///
/// The frame centres a capped picture in a wide slot. A mark stacked on the
/// slot landed in the empty space beside the picture; handed down, the frame
/// places it inside the picture's own box.
void main() {
  testWidgets('in a wide slot, TR is inside the centred picture, bottom-start',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const markKey = Key('tr');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1200,
          child: MediaCornerMark(
            mark: const SizedBox(key: markKey, width: 22, height: 22),
            child: AuraMediaFrame(
              url: 'https://example.invalid/a.png',
              isPublic: true,
              intrinsicWidth: 400,
              intrinsicHeight: 300,
              maxWidthOverride: 400,
              mode: AuraMediaFrameMode.feed,
              errorWidget: (_) => const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final mark = tester.getRect(find.byKey(markKey));
    final picture = tester.getRect(find.byType(ClipRRect).first);

    expect(picture.width, lessThan(1200), reason: 'the picture is capped');
    expect(picture.left, greaterThan(100), reason: 'and centred in the slot');
    expect(mark.left, closeTo(picture.left + MediaCornerMark.inset, 0.5));
    expect(mark.bottom, closeTo(picture.bottom - MediaCornerMark.inset, 0.5));
  });

  testWidgets('the mark is placed once, never again by a nested renderer',
      (tester) async {
    const markKey = Key('tr');
    await tester.pumpWidget(MaterialApp(
      home: MediaCornerMark(
        mark: const SizedBox(key: markKey, width: 22, height: 22),
        child: AuraMediaFrame(
          url: 'https://example.invalid/a.png',
          isPublic: true,
          intrinsicWidth: 400,
          intrinsicHeight: 300,
          foreground: Builder(
            builder: (context) => MediaCornerMark.of(context) == null
                ? const SizedBox()
                : const Text('placed twice'),
          ),
          errorWidget: (_) => const SizedBox(),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byKey(markKey), findsOneWidget);
    expect(find.text('placed twice'), findsNothing);
  });
}
