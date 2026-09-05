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
    'lib/features/meetings/presentation/meeting_live_room_screen.dart':
        'the meeting live room',
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
    expect(offenders, isEmpty,
        reason: 'these surfaces still letterbox participants: $offenders');
  });
}
