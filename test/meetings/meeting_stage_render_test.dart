import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/presentation/meeting_stage.dart';
import 'package:aura/features/meetings/presentation/meeting_stage_layout.dart';

/// THE STAGE, AS IT ACTUALLY LAYS OUT.
///
/// The rules have their own test; this pumps the real widget at real viewport
/// sizes and measures the rectangles Flutter produced. It exists because the
/// defect it replaces was invisible to every rule: the old grid's arithmetic
/// was fine in isolation and still put a row off the bottom of the window.
///
/// Tiles carry no renderer here, so every one lands on the camera-off
/// treatment. That is deliberate — geometry is what is being measured, and a
/// tile's rectangle does not depend on whether a picture is in it.
void main() {
  /// Gives the stage exactly the surface under test and measures what came
  /// back. The stage's OWN rect is the reference, never an assumed origin —
  /// the first version of this harness assumed the viewport and quietly
  /// measured a default 800x600 surface instead.
  late Rect stageRect;

  Future<List<Rect>> layout(
    WidgetTester tester, {
    required int people,
    required Size viewport,
  }) async {
    tester.view.physicalSize = const Size(2600, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tiles = [
      for (var i = 0; i < people; i++)
        StageTile(key: 'p$i', label: 'Person $i', isLocal: i == 0),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: viewport.width,
              height: viewport.height,
              child: MeetingStage(tiles: tiles),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    stageRect = tester.getRect(find.byType(MeetingStage));
    expect(stageRect.size.width, closeTo(viewport.width, 0.5));
    expect(stageRect.size.height, closeTo(viewport.height, 0.5));

    final found = find.byWidgetPredicate(
      (w) => w is Container && w.clipBehavior == Clip.antiAlias,
    );
    return found
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
  }

  const viewports = <String, Size>{
    'desktop 1600x780': Size(1600, 780),
    'laptop 1280x640': Size(1280, 640),
    'narrow desktop 1000x900': Size(1000, 900),
    'tablet portrait 820x1180': Size(820, 1180),
    'phone portrait 390x740': Size(390, 740),
  };

  group('every tile is inside the stage', () {
    for (final entry in viewports.entries) {
      for (var n = 1; n <= 5; n++) {
        testWidgets('${entry.key}, $n participants', (tester) async {
          final rects = await layout(tester, people: n, viewport: entry.value);
          expect(rects.length, n, reason: 'a participant lost their tile');

          final stage = stageRect;
          for (final r in rects) {
            // THE CLIPPED ROW. The founder's screenshot had the bottom tile
            // cut off by the window; nothing may extend past the stage.
            expect(r.bottom, lessThanOrEqualTo(stage.bottom + 0.5),
                reason: 'tile runs past the bottom: $r in $stage');
            expect(r.right, lessThanOrEqualTo(stage.right + 0.5),
                reason: 'tile runs past the right: $r in $stage');
            expect(r.top, greaterThanOrEqualTo(-0.5));
            expect(r.left, greaterThanOrEqualTo(-0.5));
            expect(r.width, greaterThan(40));
            expect(r.height, greaterThan(40));
          }
        });
      }
    }
  });

  group('the stage is used, not reserved', () {
    testWidgets('three participants leave no dead quadrant', (tester) async {
      final rects = await layout(tester, people: 3, viewport: const Size(1600, 780));
      expect(rects.length, 3);

      // The old 2x2 put its emptiness in ONE CORNER — a quarter of the stage,
      // clearly broken. The 2-over-1 puts the same arithmetic leftover into
      // two symmetric margins beside a centred tile, which is composition.
      // What is asserted here is the difference: no gap the size of a tile.
      final covered = rects.fold<double>(0, (a, r) => a + r.width * r.height);
      final stageArea = stageRect.width * stageRect.height;
      expect(covered / stageArea, greaterThan(0.70),
          reason: 'the stage is mostly empty: ${covered / stageArea}');

      final tileArea = rects.first.width * rects.first.height;
      // A dead quadrant would be an empty rectangle as big as a tile sitting
      // in a corner. Every corner of the stage must be inside some tile's row.
      final bottomRow = rects.where((r) => r.top > stageRect.center.dy).toList();
      expect(bottomRow.length, 1, reason: 'expected one tile on the lower row');
      expect(bottomRow.single.center.dx, closeTo(stageRect.center.dx, 1.5),
          reason: 'the lone tile must be centred, not parked in a corner');
      expect(tileArea, greaterThan(stageArea * 0.2),
          reason: 'tiles are too small to be faces');
    });

    testWidgets('the chosen plan shows MORE picture than the alternative',
        (tester) async {
      // Why 2-over-1 rather than 3-across on a wide desktop stage: three
      // across makes each tile 0.68 aspect, so a 16:9 camera letterboxes and
      // most of the tile is bars. Measured on 1600x780 — 72% of the stage
      // carries picture under 2-over-1 against 37% under 3-across.
      const stage = Size(1600, 780);
      const gap = 6.0;

      double pictureFraction(List<int> rows) {
        var total = 0.0;
        final columns = stageColumns(rows);
        final h = (stage.height - gap * (rows.length + 1)) / rows.length;
        final w = (stage.width - gap * (columns + 1)) / columns;
        for (var r = 0; r < rows.length; r++) {
          final a = tileAspect(stage: stage, rows: rows, rowIndex: r, gap: gap);
          for (var i = 0; i < rows[r]; i++) {
            // Participant tiles always cover, so a tile close to the camera's
            // own shape wastes nothing and a tile far from it throws most of
            // the frame away. Picture kept = the tile, minus what cover crops.
            final va = 16 / 9;
            final keep = a > va ? va / a : a / va;
            total += w * h * keep;
          }
        }
        return total / (stage.width * stage.height);
      }

      final chosen = stageRows(count: 3, stageAspect: stage.width / stage.height);
      expect(chosen, [2, 1]);
      expect(pictureFraction(chosen), greaterThan(pictureFraction([3])),
          reason: 'the plan must maximise picture, not tile rectangles');
    });

    testWidgets('two participants split the stage evenly', (tester) async {
      final rects = await layout(tester, people: 2, viewport: const Size(1600, 780));
      expect(rects.length, 2);
      expect((rects[0].width - rects[1].width).abs(), lessThan(1.5));
      expect((rects[0].height - rects[1].height).abs(), lessThan(1.5));
    });

    testWidgets('one participant gets the whole stage', (tester) async {
      final rects = await layout(tester, people: 1, viewport: const Size(1280, 640));
      expect(rects.length, 1);
      expect(rects.single.width, greaterThan(stageRect.width * 0.95));
      expect(rects.single.height, greaterThan(stageRect.height * 0.95));
    });

    testWidgets('a phone in portrait stacks rather than slivers', (tester) async {
      final rects = await layout(tester, people: 3, viewport: const Size(390, 740));
      expect(rects.length, 3);
      for (final r in rects) {
        // Nothing thinner than a usable band.
        expect(r.height, greaterThan(100));
      }
    });
  });
}
