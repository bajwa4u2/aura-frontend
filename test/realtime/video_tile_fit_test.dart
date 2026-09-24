import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// EVERY TILE FILLS ITS FRAME — founder-observed, 2026-08-25.
///
/// In a real two-party call: *"in call frame one vertical one landscape"*.
///
/// A phone publishes portrait (9:16); a laptop webcam publishes landscape
/// (16:9). With `Contain`, each stream is letterboxed to its OWN aspect inside
/// a shared tile, so two participants appear as two differently shaped
/// pictures — one tall and pillarboxed, one wide — in a grid that is meant to
/// read as equal seats at the same table.
///
/// `Cover` crops instead of letterboxing, so tiles stay the same shape
/// whatever anyone dialled in from. The Meetings live room, the device check
/// and the PiP already did this; the thread-call room and its participant list
/// were the surfaces still letterboxing.
void main() {
  const surfaces = <String, String>{
    'lib/features/realtime/presentation/realtime_room_screen.dart':
        'the thread-call video grid',
    'lib/features/realtime/presentation/widgets/realtime_participant_list.dart':
        'the participant list thumbnails',
    // The meeting stage is NOT listed here: it legitimately contains the
    // shared screen. Its contract is asserted whole by
    // 'the stage contains ONLY the presentation' below — one Contain, and it
    // belongs to the presentation, while every participant tile Covers.
    'lib/features/realtime/presentation/widgets/floating_call_widget.dart':
        'the picture-in-picture',
    // The preflight self-view was here. The sheet it lived on was deleted
    // (founder ruling, 2026-09-05 — tapping Call places the call), so there is
    // no surface left to letterbox. Removed rather than pointed at a file that
    // does not exist, which would fail for a reason that says nothing about
    // video fit.
  };

  group('no call surface letterboxes a participant', () {
    for (final entry in surfaces.entries) {
      test('${entry.value} uses Cover', () {
        final src = File(entry.key).readAsStringSync();
        expect(
          src,
          isNot(contains('RTCVideoViewObjectFitContain')),
          reason: '${entry.value} letterboxes again, so a portrait phone and a '
              'landscape webcam render as two differently shaped pictures',
        );
        expect(
          src,
          contains('RTCVideoViewObjectFitCover'),
          reason: '${entry.value} no longer states a fit at all',
        );
      });
    }
  });

  test('the whole client agrees — Contain appears on no call surface', () {
    // A single holdout reintroduces the mismatch, because the defect is a
    // DISAGREEMENT between tiles rather than a property of any one of them.
    final offenders = <String>[];
    for (final dir in [
      Directory('lib/features/realtime'),
      Directory('lib/features/meetings'),
      Directory('lib/core/media'),
    ]) {
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.readAsStringSync().contains('RTCVideoViewObjectFitContain')) {
          offenders.add(f.path);
        }
      }
    }
    // ONE CARVE-OUT, NAMED AND REASONED (2026-09-24 founder authority).
    //
    // The meeting stage contains the SHARED SCREEN, and only that: "Do not
    // crop documents, application interfaces or shared screen edges." A
    // document that loses its margin has lost the thing it was shared for.
    // Participants on that same surface still Cover — the group above asserts
    // it file by file, and `participantTilesAlwaysCover` states the contract.
    //
    // The carve-out is a path, not a blanket: any OTHER file reintroducing
    // Contain still fails, which is the point of the sweep.
    offenders.removeWhere((p) => p.endsWith('meeting_stage.dart'));

    expect(offenders, isEmpty,
        reason: 'these surfaces still letterbox participants: $offenders');
  });

  test('the stage contains ONLY the presentation', () {
    // The carve-out above would hide a participant tile quietly reverting to
    // Contain, so the stage is checked from the inside: every Contain in it
    // belongs to the shared surface.
    final src =
        File('lib/features/meetings/presentation/meeting_stage.dart')
            .readAsStringSync();
    final containCount =
        'RTCVideoViewObjectFitContain'.allMatches(src).length;
    expect(containCount, 1,
        reason: 'exactly one Contain — the presentation — is expected, '
            'found $containCount');

    // And it is the presentation's, not a tile's: the only Contain sits in
    // the composition that paints `presentation`.
    final i = src.indexOf('RTCVideoViewObjectFitContain');
    final window = src.substring((i - 400).clamp(0, src.length), i);
    expect(window, contains('presentation'),
        reason: 'a participant tile letterboxes again');

    // And the people on that same surface still fill their seats.
    expect(src, contains('RTCVideoViewObjectFitCover'),
        reason: 'the stage no longer states a fit for participants');
  });
}
