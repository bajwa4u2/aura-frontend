import 'package:aura/core/media/aura_media_frame.dart';
import 'package:aura/core/media/aura_video_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// FEED MEDIA SITS CENTRED ON DESKTOP (founder, 2026-09-30: "media in every
/// feed on desktop not centered but left align"). A picture capped at 720 px,
/// or a tall video capped in height, is narrower than a desktop card; it used
/// to hug the left edge. A message still keeps media to its bubble's side.
void main() {
  Future<Rect> place(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1000,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [child],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    return tester.getRect(find.byType(AspectRatio).first);
  }

  testWidgets('a tall video capped in height is centred', (tester) async {
    final r = await place(
      tester,
      const AuraVideoSurface(
        url: 'https://example.test/v.mp4',
        intrinsicWidth: 1080,
        intrinsicHeight: 1920,
        maxHeight: 400,
        canDecode: false,
      ),
    );
    expect(r.width, lessThan(1000));
    expect(r.center.dx, closeTo(500, 1));
  });

  testWidgets('in a message, the same video keeps to the start', (tester) async {
    final r = await place(
      tester,
      const AuraVideoSurface(
        url: 'https://example.test/v.mp4',
        intrinsicWidth: 1080,
        intrinsicHeight: 1920,
        maxHeight: 400,
        canDecode: false,
        alignment: AlignmentDirectional.centerStart,
      ),
    );
    expect(r.left, closeTo(0, 1));
  });

  testWidgets('a feed picture narrower than the card is centred', (tester) async {
    final r = await place(
      tester,
      const AuraMediaFrame(
        url: 'https://example.test/p.jpg',
        intrinsicWidth: 1080,
        intrinsicHeight: 1920,
      ),
    );
    expect(r.width, lessThan(1000));
    expect(r.center.dx, closeTo(500, 1));
  });
}
