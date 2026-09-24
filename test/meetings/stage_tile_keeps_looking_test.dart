import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A TILE HAS TO KEEP LOOKING — and a reconstruction dropped it.
///
/// A renderer is handed its video track by the media service on its own
/// schedule, which is normally AFTER the tile that will paint it was built. A
/// tile that asks "is there a picture?" once and never again answers "no" for
/// the rest of the meeting.
///
/// The tile this replaced was stateful and had two ways of noticing: the
/// renderer's `onFirstFrameRendered` callback and a 500 ms re-check. The stage
/// reconstruction (2026-09-24) replaced it with a stateless tile and silently
/// removed both.
///
/// Measured within the hour, on the live meeting, and it is the sharpest kind
/// of evidence there is — the same build, the same session, the same second:
///
///   * my client, which happened to rebuild when a third person joined,
///     rendered BOTH peers;
///   * the founder's client, whose tiles were built before the tracks
///     attached, showed "Camera off" for BOTH of them — while the server
///     recorded `CLIENT_RENDER_ATTACHED created=1 attachedVideoTracks=1` for
///     the very renderer it was refusing to paint.
///
/// This holds the mechanism, because it is invisible to every layout test and
/// to any single-client check: everything looks right on whichever client
/// happened to rebuild last.
void main() {
  final src = File(
    'lib/features/meetings/presentation/meeting_stage.dart',
  ).readAsStringSync();

  test('the tile is stateful — a stateless one cannot keep looking', () {
    expect(src, contains('class _Tile extends StatefulWidget'),
        reason: 'a stateless tile answers "no picture" once, forever');
  });

  test('it listens for the first frame', () {
    expect(src, contains('onFirstFrameRendered'));
  });

  test('it re-checks, for the platforms where that callback never comes', () {
    expect(src, contains('Timer.periodic'));
    expect(src, contains('hasPicture != _hadPicture'),
        reason: 'the re-check must compare the ANSWER, not just fire');
  });

  test('it re-hooks when the renderer is replaced', () {
    expect(src, contains('didUpdateWidget'));
    expect(src, contains('oldWidget.tile.renderer != widget.tile.renderer'),
        reason: 'a republished peer gets a new renderer, and the old hook '
            'points at the one that went away');
  });

  test('it stops looking when it leaves', () {
    expect(src, contains('_recheck?.cancel()'),
        reason: 'a timer per tile, never cancelled, outlives the meeting');
  });
}
