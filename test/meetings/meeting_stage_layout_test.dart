import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/meetings/presentation/meeting_stage_layout.dart';

/// M-6 — THE INTERFACE WAS EATING THE MEETING.
///
/// Founder screenshot, 2026-09-24, three participants on a 1920-wide window:
/// a 2x2 grid with a DEAD QUADRANT taking a quarter of the stage, the bottom
/// row CLIPPED by the window, and each person shown as a narrow band of
/// picture inside a large black rectangle. The old rule was
/// `if (count <= 4) return 2;` columns, and the cell aspect was computed
/// against a height the grid did not actually have.
///
/// These hold the composition: never reserve a cell for somebody who is not
/// there, and never plan more rows than the stage can show.
void main() {
  group('rows are filled, never padded', () {
    test('every plan sums to the number of people', () {
      for (final aspect in [0.6, 1.0, 1.4, 1.78, 2.4, 3.2]) {
        for (var n = 1; n <= 5; n++) {
          final rows = stageRows(count: n, stageAspect: aspect);
          expect(rows.fold<int>(0, (a, b) => a + b), n,
              reason: 'aspect $aspect, $n people: $rows');
          expect(rows.any((r) => r <= 0), isFalse,
              reason: 'an empty row is a dead band');
        }
      }
    });

    test('three people never produce a 2x2 with a hole', () {
      for (final aspect in [0.6, 1.0, 1.4, 1.78, 2.4, 3.2]) {
        final rows = stageRows(count: 3, stageAspect: aspect);
        expect(rows, isNot([2, 2]));
        expect(rows.fold<int>(0, (a, b) => a + b), 3);
        // The measured failure: a plan whose capacity exceeds the people.
        final capacity = rows.fold<int>(0, (a, b) => a + b);
        expect(capacity, 3, reason: 'capacity must equal attendance');
      }
    });

    test('a very wide stage puts three across; a squarer one stacks 2 over 1', () {
      expect(stageRows(count: 3, stageAspect: 2.6), [3]);
      expect(stageRows(count: 3, stageAspect: 1.4), [2, 1]);
      expect(stageRows(count: 3, stageAspect: 0.7), [1, 1, 1]);
    });

    test('two people share the long edge', () {
      expect(stageRows(count: 2, stageAspect: 1.78), [2]);
      expect(stageRows(count: 2, stageAspect: 0.6), [1, 1]);
    });

    test('five people never leave a row of slivers on a narrow stage', () {
      expect(stageRows(count: 5, stageAspect: 1.78), [3, 2]);
      expect(stageRows(count: 5, stageAspect: 0.7), [2, 2, 1]);
    });
  });

  group('a tile keeps a usable shape', () {
    test('no plan produces a tile thinner than a letterbox slit', () {
      const stage = Size(1600, 780); // a real desktop meeting area
      for (var n = 1; n <= 5; n++) {
        final rows = stageRows(count: n, stageAspect: stage.width / stage.height);
        for (var r = 0; r < rows.length; r++) {
          final a = tileAspect(stage: stage, rows: rows, rowIndex: r, gap: 6);
          expect(a, greaterThan(0.5), reason: '$n people, row $r: $a');
          expect(a, lessThan(4.0), reason: '$n people, row $r: $a');
        }
      }
    });
  });

  group('cover or contain', () {
    test('a face fills its seat — participant tiles always cover', () {
      // 2026-08-25, founder, on a real call: "in call frame one vertical one
      // landscape". Contain letterboxes a 9:16 phone and a 16:9 webcam to
      // different shapes and the grid stops reading as equal seats.
      expect(participantTilesAlwaysCover, isTrue);
    });

    test('shared material is never cropped', () {
      expect(sharedSurfaceAlwaysContains, isTrue);
    });
  });

  group('the presentation dominates', () {
    test('the filmstrip takes the long edge and a minority of the stage', () {
      const wide = Size(1600, 780);
      expect(filmstripPlacement(wide), FilmstripPlacement.right);
      final e = filmstripExtent(wide, FilmstripPlacement.right, 3);
      expect(e, lessThan(wide.width * 0.25),
          reason: 'the shared material must stay primary');
      expect(e, greaterThan(wide.width * 0.11),
          reason: 'a face still has to be recognisable');

      const tall = Size(800, 1200);
      expect(filmstripPlacement(tall), FilmstripPlacement.bottom);
      final e2 = filmstripExtent(tall, FilmstripPlacement.bottom, 3);
      expect(e2, lessThan(tall.height * 0.25));
    });
  });
}
