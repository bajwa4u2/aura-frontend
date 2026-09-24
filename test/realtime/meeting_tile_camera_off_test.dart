import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/meetings/presentation/meeting_stage_layout.dart';

/// M-4 — AN AVATAR OVER A LIVE PICTURE.
///
/// Measured on a real meeting, 2026-09-24. The founder's client had her video
/// published, subscribed, bound (`receiving=2 bound=2`), attached to a
/// renderer (`withVideo=1 attachedVideoTracks=1 failures=0`) and was DECODING
/// it — `videoFramesDecoded` 1521 → 1596 → 1671 → 1745, 11.7 MB received, 0%
/// loss — and her tile showed her avatar and the words "Camera off".
///
/// The tile decided video state from the received track's `muted` flag:
///
///     return tracks.first.muted != true;
///
/// On a REMOTE track `muted` means "no data is arriving right now". It starts
/// true on every remote track and clears when media flows; when it does not
/// clear, a live picture is hidden. It is very likely the same fault behind
/// "his video was not reliably visible" the day before — a flag that clears
/// sometimes and not others is the definition of unreliable.
///
/// The rule was not always wrong to distrust the roster: when it was written,
/// a meeting's camera never signalled the session at all (M-1), so `videoOn`
/// was meaningless. M-1 is fixed, so the roster is ground truth again — with
/// arriving data kept as a second opinion so a stale-false roster cannot hide
/// a picture either.
void main() {
  group('what the tile paints', () {
    test('the exact live failure: roster ON, track reports muted', () {
      // Her camera was on and 1,745 frames had decoded. The old rule returned
      // false here, and that is the whole defect.
      expect(
        stageTileShowsPicture(hasVideoTrack: true, trackMuted: true),
        isTrue,
      );
    });

    test('roster ON and data arriving — paint', () {
      expect(stageTileShowsPicture(hasVideoTrack: true, trackMuted: false), isTrue);
    });

    test('no video track at all is the only reason to show camera-off', () {
      expect(stageTileShowsPicture(hasVideoTrack: false, trackMuted: true), isFalse);
      expect(stageTileShowsPicture(hasVideoTrack: false, trackMuted: false), isFalse);
    });

    test('no roster flag can hide a picture that exists', () {
      // M-5: the roster was observed reading OFF for three participants who
      // were all publishing. The stage does not consult it at all.
      expect(stageTileShowsPicture(hasVideoTrack: true), isTrue);
    });

    test('an unattributed renderer still paints what it holds', () {
      expect(stageTileShowsPicture(hasVideoTrack: true, trackMuted: null), isTrue);
    });

    test('muted alone can never veto', () {
      // The single property the old rule got wrong, stated as an invariant:
      // there is no combination in which `muted: true` by itself hides video.
      for (final muted in [true, false, null]) {
        expect(
          stageTileShowsPicture(hasVideoTrack: true, trackMuted: muted),
          isTrue,
          reason: 'muted is a transport signal, not a camera switch',
        );
      }
    });
  });
}
