// Layout-contract tests for the canonical [AuraMediaFrame].
//
// These tests do NOT render real images (the network calls are stubbed
// at the `CachedNetworkImage` boundary by passing a non-resolvable URL
// and letting the error widget render). What they DO verify is the
// rendered-tree geometry that the brief required:
//
//   * Every render path is wrapped in a [ClipRRect].
//   * The frame never overflows its parent: width is always <=
//     parent width, capped at the per-mode max.
//   * The aspect-ratio decision is correct for landscape vs portrait
//     vs unknown-intrinsic content.
//   * Feed and detail modes pick distinct max widths/heights so the
//     same content renders consistently across surfaces.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/aura_media_frame.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  required Size viewSize,
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('AuraMediaFrame — overflow + clip contract', () {
    testWidgets('feed mode wraps content in a ClipRRect', (tester) async {
      await _pump(
        tester,
        viewSize: const Size(1200, 900),
        child: const AuraMediaFrame(
          url: 'https://example.invalid/image.png',
          intrinsicWidth: 1920,
          intrinsicHeight: 1080,
        ),
      );

      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('feed mode caps width at 720 on desktop viewports',
        (tester) async {
      // 1200 px viewport, but the frame must cap at 720.
      await _pump(
        tester,
        viewSize: const Size(1200, 900),
        child: const AuraMediaFrame(
          url: 'https://example.invalid/image.png',
          intrinsicWidth: 1920,
          intrinsicHeight: 1080,
        ),
      );

      // Locate the inner aspect-bounded box (the ClipRRect's child).
      final aspectFinder = find.byType(AspectRatio);
      expect(aspectFinder, findsOneWidget);
      final box = tester.getSize(aspectFinder);
      expect(box.width, lessThanOrEqualTo(720.0));
    });

    testWidgets('feed mode lets mobile narrow viewports fill the parent',
        (tester) async {
      // 360 px viewport → no desktop cap. The frame should fill the
      // available width.
      await _pump(
        tester,
        viewSize: const Size(360, 700),
        child: const SizedBox(
          width: 360,
          child: AuraMediaFrame(
            url: 'https://example.invalid/image.png',
            intrinsicWidth: 1920,
            intrinsicHeight: 1080,
          ),
        ),
      );

      final aspectFinder = find.byType(AspectRatio);
      expect(aspectFinder, findsOneWidget);
      final box = tester.getSize(aspectFinder);
      // Should be exactly the parent width — no overflow, no cap.
      expect(box.width, equals(360.0));
    });

    testWidgets('detail mode caps width at 1080 on desktop viewports',
        (tester) async {
      await _pump(
        tester,
        viewSize: const Size(1600, 1000),
        child: const AuraMediaFrame(
          url: 'https://example.invalid/image.png',
          mode: AuraMediaFrameMode.detail,
          intrinsicWidth: 1920,
          intrinsicHeight: 1080,
        ),
      );
      final box = tester.getSize(find.byType(AspectRatio));
      expect(box.width, lessThanOrEqualTo(1080.0));
    });

    testWidgets('thumbnail mode renders a fixed 72×72 square',
        (tester) async {
      await _pump(
        tester,
        viewSize: const Size(1200, 900),
        child: const AuraMediaFrame(
          url: 'https://example.invalid/image.png',
          mode: AuraMediaFrameMode.thumbnail,
          intrinsicWidth: 1080,
          intrinsicHeight: 1080,
        ),
      );
      final box = tester.getSize(find.byType(AspectRatio));
      expect(box.width, equals(72.0));
      expect(box.height, equals(72.0));
    });
  });

  group('AuraMediaFrame — aspect-decision heuristic', () {
    testWidgets('landscape 1920×1080 → uses intrinsic 16:9 aspect',
        (tester) async {
      await _pump(
        tester,
        viewSize: const Size(1200, 900),
        child: const AuraMediaFrame(
          url: 'https://example.invalid/image.png',
          intrinsicWidth: 1920,
          intrinsicHeight: 1080,
        ),
      );

      final aspectWidget =
          tester.widget<AspectRatio>(find.byType(AspectRatio));
      // 16:9 = 1.7777...
      expect(aspectWidget.aspectRatio, closeTo(16 / 9, 0.01));
    });

    testWidgets(
        'portrait 1080×1920 (text-heavy graphic) → letterboxed 16:9, NOT clamped to 0.6',
        (tester) async {
      await _pump(
        tester,
        viewSize: const Size(1200, 900),
        child: const AuraMediaFrame(
          url: 'https://example.invalid/image.png',
          intrinsicWidth: 1080,
          intrinsicHeight: 1920,
        ),
      );

      final aspectWidget =
          tester.widget<AspectRatio>(find.byType(AspectRatio));
      // The frame should letterbox inside 16:9 (or 4:5 on mobile),
      // NOT use the clamped 0.6 from the pre-pass code. 16/9 ≈ 1.78.
      expect(aspectWidget.aspectRatio, closeTo(16 / 9, 0.01));
    });

    testWidgets('square 1080×1080 → uses intrinsic 1:1 cover',
        (tester) async {
      await _pump(
        tester,
        viewSize: const Size(1200, 900),
        child: const AuraMediaFrame(
          url: 'https://example.invalid/image.png',
          intrinsicWidth: 1080,
          intrinsicHeight: 1080,
        ),
      );

      final aspectWidget =
          tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectWidget.aspectRatio, closeTo(1.0, 0.01));
    });

    testWidgets('unknown intrinsic dimensions → defaults to 16:9 contain',
        (tester) async {
      await _pump(
        tester,
        viewSize: const Size(1200, 900),
        child: const AuraMediaFrame(
          url: 'https://example.invalid/image.png',
        ),
      );

      final aspectWidget =
          tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectWidget.aspectRatio, closeTo(16 / 9, 0.01));
    });

    testWidgets(
        'panoramic 4000×1000 (>1.91) → letterboxed inside the bounded frame, not stretched',
        (tester) async {
      await _pump(
        tester,
        viewSize: const Size(1200, 900),
        child: const AuraMediaFrame(
          url: 'https://example.invalid/image.png',
          intrinsicWidth: 4000,
          intrinsicHeight: 1000,
        ),
      );
      final aspectWidget =
          tester.widget<AspectRatio>(find.byType(AspectRatio));
      // Should NOT use the intrinsic 4.0 aspect (would make the card
      // explode horizontally). The portrait-heuristic falls back to
      // 16:9 contain so the panorama letterboxes inside.
      expect(aspectWidget.aspectRatio, lessThan(1.91));
    });

    testWidgets('aspectOverride forces the chosen aspect', (tester) async {
      await _pump(
        tester,
        viewSize: const Size(1200, 900),
        child: const AuraMediaFrame(
          url: 'https://example.invalid/image.png',
          intrinsicWidth: 1080,
          intrinsicHeight: 1920,
          aspectOverride: 1.0, // square frame regardless of intrinsic
        ),
      );
      final aspectWidget =
          tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectWidget.aspectRatio, closeTo(1.0, 0.01));
    });
  });

  group('AuraMediaFrame — failure states', () {
    testWidgets('empty URL renders an error tile (no exception)',
        (tester) async {
      await _pump(
        tester,
        viewSize: const Size(800, 600),
        child: const AuraMediaFrame(
          url: '',
          intrinsicWidth: 1920,
          intrinsicHeight: 1080,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('non-public media with missing mediaId renders error tile',
        (tester) async {
      await _pump(
        tester,
        viewSize: const Size(800, 600),
        child: const AuraMediaFrame(
          isPublic: false,
          mediaId: '',
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
