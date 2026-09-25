import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AN AUDIO-ONLY PARTICIPANT STILL NEEDS A SINK.
///
/// Founder-observed on a live web call, 2026-09-24: an AUDIO-ONLY call with no
/// voice on either side — while the server recorded **~250 KB of inbound audio
/// per participant at about 30 kbps**. Real speech, arriving, decoded, and
/// played nowhere.
///
/// The renderer reconciliation opened with `if (video == null) continue;`, so
/// a participant publishing audio and no video was skipped entirely: no stream
/// composed, no renderer built, and therefore the `renderer.muted = false`
/// immediately below — which exists for precisely this audio problem — never
/// ran.
///
/// On web the renderer IS the sink: it holds the media element for the stream.
/// Without one the track is decoded into nothing. Native routes remote audio
/// through the device and needs no element, which is why this only ever bit
/// the browser — the same asymmetry the `muted = false` note already
/// describes.
///
/// A VIDEO call on the same build has sound only incidentally: it builds a
/// renderer for the picture, and the audio rides the same element. So the
/// feature appeared to work everywhere it was looked at.
///
/// The diagnostic said it plainly the whole time, and nobody had read it:
///
///     render participants=1 withVideo=0 created=0 attachedVideoTracks=0
///     kinds=audio=339848b video=ABSENT
void main() {
  final src = File(
    'lib/features/realtime/data/realtime_media_service.dart',
  ).readAsStringSync();

  final loop = (() {
    final start = src.indexOf('AN AUDIO-ONLY PARTICIPANT STILL NEEDS A SINK');
    if (start < 0) throw StateError('the audio-only repair is gone');
    final end = src.indexOf("unawaited(_stage?.report(", start);
    if (end < 0) throw StateError('could not bound the reconciliation');
    return src.substring(start, end);
  })();

  group('who gets a renderer', () {
    test('THE DEFECT: no-video no longer means no sink', () {
      expect(src, isNot(contains('      if (video == null) continue;')),
          reason: 'this single line is the whole fault');
    });

    test('only a participant with NEITHER track is skipped', () {
      expect(loop, contains('if (video == null && audioTrack == null) continue;'));
    });

    test('the stream carries whichever tracks exist', () {
      expect(loop, contains('if (video != null) await stream.addTrack(video);'));
      expect(loop, contains('if (audio != null) await stream.addTrack(audio);'));
    });

    test('the web unmute is now reachable for an audio-only participant', () {
      // It sits after the renderer is built, and the renderer was what the
      // early `continue` skipped.
      expect(loop, contains('renderer.srcObject = stream;'));
      expect(src, contains('renderer.muted = false;'));
    });
  });

  group('what must NOT happen to an audio-only participant', () {
    test('no picture watchers are armed for a participant with no picture', () {
      // Arming these would report a frozen video that does not exist, and the
      // per-kind stall detector would then act on it.
      expect(loop, contains('if (video != null) {\n          _watchRemoteVideoLiveness(video);'));
    });

    test('a held renderer is compared correctly when there is no video', () {
      // The old comparison dereferenced `video.id` unconditionally. With no
      // video the right question is whether the held stream ALSO has none.
      expect(loop, contains('final sameVideo = video == null\n            ? heldVideo.isEmpty'));
    });
  });

  group('the diagnostic must not call the repair a failure', () {
    test('an audio-only renderer is not reported as an empty stream', () {
      // `attached` counts VIDEO tracks. Comparing it to `created` would mark
      // every successful audio-only attach as `render_empty_stream` — the
      // instrument reporting a fault precisely when it worked.
      expect(src, contains('attached < withVideo'));
      expect(src, isNot(contains('attached < created')));
    });
  });
}
