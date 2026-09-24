/// HOW A MEETING USES ITS STAGE.
///
/// Pure rules, separated from the widgets, because composition is exactly the
/// kind of thing that is argued about with screenshots and then regresses
/// silently. Everything here can be asserted without a renderer.
///
/// The doctrine these encode: CONTENT FIRST, INTERFACE SECOND. The people in
/// the meeting own the surface; nothing reserves space for someone who is not
/// there, and nothing is drawn on top of a face.
library;

import 'package:flutter/widgets.dart';

/// How the tiles are distributed across rows, top to bottom.
///
/// `[3]` is three across in one row. `[2, 1]` is two above one. The list never
/// contains a zero and always sums to the participant count, which is the
/// whole point: A ROW IS NEVER PADDED WITH AN EMPTY CELL.
///
/// Measured failure this replaces (2026-09-24, founder screenshot): three
/// participants produced a 2x2 grid — a dead quadrant occupying a quarter of
/// the stage, with the bottom row clipped by the viewport because the grid
/// computed a cell aspect against a height it did not have.
List<int> stageRows({required int count, required double stageAspect}) {
  if (count <= 1) return [if (count == 1) 1];
  // Portrait-ish stage: prefer stacking, since a wide row of short tiles wastes
  // more than a tall column of wide ones.
  final wide = stageAspect >= 1.2;
  final veryWide = stageAspect >= 2.2;

  switch (count) {
    case 2:
      return wide ? [2] : [1, 1];
    case 3:
      // Three across only when each tile still has room to be a face rather
      // than a letterbox slit. Otherwise two and one — which fills the stage
      // completely, unlike a 2x2 with a hole in it.
      return veryWide ? [3] : (wide ? [2, 1] : [1, 1, 1]);
    case 4:
      return wide ? [2, 2] : [2, 2];
    case 5:
      // Never [3,2] on a narrow stage: the row of three collapses to slivers.
      return wide ? [3, 2] : [2, 2, 1];
    default:
      // Beyond five the meeting is not a conversation any more; keep it simple
      // and square-ish rather than inventing a policy for a case the product
      // does not support (max 5 today).
      final columns = (count / 2).ceil().clamp(2, 4);
      final rows = <int>[];
      var left = count;
      while (left > 0) {
        final take = left >= columns ? columns : left;
        rows.add(take);
        left -= take;
      }
      return rows;
  }
}

/// A SHORT ROW DOES NOT STRETCH.
///
/// Every tile on the stage is the same width, whatever row it is in, and a row
/// with fewer tiles is CENTRED rather than spread. Without this, a `[2, 1]`
/// plan hands the lone bottom tile the entire width: on a 1600x780 stage that
/// is a 4.17:1 slit, which is the same disease as the 2x2 hole wearing
/// different clothes. Caught by this file's own test before it ever shipped.
int stageColumns(List<int> rows) =>
    rows.isEmpty ? 1 : rows.reduce((a, b) => a > b ? a : b);

/// The aspect ratio a tile will actually get, given the stage and the plan.
///
/// Used to decide whether a tile can afford to crop: the row's share of the
/// stage height, and one column's share of its width.
double tileAspect({
  required Size stage,
  required List<int> rows,
  required int rowIndex,
  required double gap,
}) {
  if (rows.isEmpty) return 16 / 9;
  final rowCount = rows.length;
  final columns = stageColumns(rows);
  final h = (stage.height - gap * (rowCount + 1)) / rowCount;
  final w = (stage.width - gap * (columns + 1)) / columns;
  if (h <= 0 || w <= 0) return 16 / 9;
  return w / h;
}

/// A FACE FILLS ITS SEAT. A DOCUMENT DOES NOT GET CROPPED.
///
/// Two founder observations govern this, and they point opposite ways for
/// opposite content:
///
///   * 2026-08-25, a real two-party call: *"in call frame one vertical one
///     landscape"*. A phone publishes 9:16 and a laptop 16:9; CONTAIN
///     letterboxes each to its own shape, so the grid stops reading as equal
///     seats at one table. Participant tiles therefore always COVER — the
///     composition above keeps tile aspects near the camera's, so the crop is
///     small by construction rather than by luck.
///   * 2026-09-24: shared material must never lose its edges. A document that
///     loses its margin, or an application whose toolbar is the point, has
///     lost the thing it was shared for. The presentation always CONTAINS.
///
/// Stated as constants because both are contracts other tests assert against,
/// not preferences a future refactor may quietly reverse.
const bool participantTilesAlwaysCover = true;

/// SHARED MATERIAL IS NEVER CROPPED.
///
/// A face survives losing its edges; a document does not, and neither does an
/// application interface whose toolbar is the point. The presentation is
/// always contained.
const bool sharedSurfaceAlwaysContains = true;

/// Where the participant filmstrip sits while somebody is presenting.
///
/// The strip goes along the stage's LONG edge so the presentation keeps the
/// largest possible rectangle: beside it on a wide screen, beneath it on a
/// tall one.
enum FilmstripPlacement { bottom, right }

FilmstripPlacement filmstripPlacement(Size stage) =>
    stage.width >= stage.height * 1.15
        ? FilmstripPlacement.right
        : FilmstripPlacement.bottom;

/// How much of the stage the filmstrip may take.
///
/// Bounded at both ends: enough that a face is recognisable, never so much
/// that the presentation stops dominating. The doctrine is explicit that
/// shared material becomes primary.
double filmstripExtent(Size stage, FilmstripPlacement placement, int people) {
  final along = placement == FilmstripPlacement.right ? stage.width : stage.height;
  final ideal = placement == FilmstripPlacement.right ? 232.0 : 168.0;
  final maxShare = along * 0.24;
  final minShare = along * 0.12;
  if (people <= 0) return 0;
  return ideal.clamp(minShare, maxShare);
}

/// IS THERE A PICTURE TO PAINT?
///
/// The answer is the media plane's, and nobody else's. Two flags have been
/// trusted for this and both lied inside two days:
///
///   * the roster's `videoOn` — meaningless until a meeting's camera actually
///     signalled the session (M-1), and observed reading OFF for three people
///     who were all publishing;
///   * the received track's `muted` — the browser saying "no packets this
///     instant". It starts true on every remote track. Trusting it put an
///     avatar and the words "Camera off" over a picture the receiver was
///     decoding at 1,745 frames and climbing (founder screenshot,
///     2026-09-24), and it is the likeliest reading of "his video was not
///     reliably visible" in the Richard meeting the day before.
///
/// So: a video track that exists is a picture. `trackMuted` is accepted only
/// to make it explicit, in code and in tests, that it CANNOT veto.
bool stageTileShowsPicture({
  required bool hasVideoTrack,
  bool? trackMuted,
}) =>
    hasVideoTrack;

/// THE SHAPE OF A SEAT.
///
/// Filling every last pixel is not the same as looking composed. A stage of
/// 1960x1010 with two-over-one hands each tile a 1.96:1 rectangle — a wide,
/// flat slab that also crops the top of somebody's head, because a 16:9
/// camera covering a 2:1 tile loses its top and bottom. Founder, on the live
/// meeting, 2026-09-24: *"i do not like tiles they are like laid"*.
///
/// So a tile takes the largest 16:9 frame that fits its cell, and the grid is
/// centred in what is left. Symmetric margins read as composition; a stretched
/// slab reads as a stretched slab.
const double stageTileTargetAspect = 16 / 9;

/// The tile size for a plan, honouring the frame shape.
Size stageTileSize({
  required Size stage,
  required List<int> rows,
  required double gap,
}) {
  if (rows.isEmpty) return Size.zero;
  final columns = stageColumns(rows);
  final cellW = (stage.width - gap * (columns + 1)) / columns;
  final cellH = (stage.height - gap * (rows.length + 1)) / rows.length;
  if (cellW <= 0 || cellH <= 0) return Size.zero;
  final w = cellW < cellH * stageTileTargetAspect
      ? cellW
      : cellH * stageTileTargetAspect;
  return Size(w, w / stageTileTargetAspect);
}
