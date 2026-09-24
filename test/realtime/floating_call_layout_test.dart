import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/presentation/widgets/floating_call_layout.dart';

/// A MINIMISED AUDIO CALL AND A MINIMISED VIDEO CALL ARE NOT THE SAME OBJECT.
///
/// Founder, 2026-09-24: *"pip is odd and ugly its same for the audio and
/// video"*.
///
/// The old card had one shape for both: title row, status row, control row, and
/// on video a strip showing the viewer's OWN mirrored camera. An audio call got
/// furniture it had no use for; a video call spent its only picture on the one
/// person who did not need seeing.
///
/// These hold the rules that replaced it. They are cheap, they need no renderer,
/// and they fail loudly if somebody later collapses the two compositions back
/// into one — which is exactly how the fault arrived in the first place.
void main() {
  group('the composition follows the content, not the call type', () {
    test('an audio call is never given a picture area', () {
      expect(
        floatingCallComposition(isVideo: false, hasRemotePicture: false),
        FloatingCallComposition.bar,
      );
    });

    test('an audio call stays a bar even if a renderer somehow exists', () {
      // Defensive: audio calls must not acquire a video well through a stray
      // renderer left behind by an earlier video session.
      expect(
        floatingCallComposition(isVideo: true, hasRemotePicture: false),
        FloatingCallComposition.bar,
      );
      expect(
        floatingCallComposition(isVideo: false, hasRemotePicture: true),
        FloatingCallComposition.bar,
      );
    });

    test('a video call with a decoding picture becomes that picture', () {
      expect(
        floatingCallComposition(isVideo: true, hasRemotePicture: true),
        FloatingCallComposition.picture,
      );
    });

    test('a video call whose cameras are all off does NOT show a black well', () {
      // THE MEASUREMENT THAT MATTERS. A 16:9 area of nothing is worse than no
      // area: it is the "odd and ugly" the founder was looking at.
      final composition = floatingCallComposition(
        isVideo: true,
        hasRemotePicture: false,
      );
      expect(floatingCallShowsPicture(composition), isFalse);
    });
  });

  group('the two are visibly different objects', () {
    final picture = floatingCallSize(FloatingCallComposition.picture);
    final bar = floatingCallSize(FloatingCallComposition.bar);

    test('they share a width, so the card never jumps sideways', () {
      expect(picture.width, bar.width);
      expect(picture.width, kFloatingCallWidth);
    });

    test('the bar is markedly shorter — that IS the difference', () {
      expect(bar.height, lessThan(picture.height * 0.6),
          reason: 'if these are close, the audio PiP is still carrying the '
              'video PiP\'s furniture');
    });

    test('the picture is framed 16:9, like a face on the meetings stage', () {
      expect(picture.width / picture.height,
          closeTo(kFloatingCallPictureAspect, 0.001));
    });

    test('only the bar says the call kind out loud', () {
      // On a picture, the picture says it. The old card said it in both.
      expect(floatingCallNamesItsKind(FloatingCallComposition.bar), isTrue);
      expect(floatingCallNamesItsKind(FloatingCallComposition.picture), isFalse);
    });
  });

  group('C-4 — a control a thumb can find', () {
    test('the tap target meets the platform minimum', () {
      // The Return chip was ~21 logical pixels tall: hit every time by a mouse
      // cursor, missed by a finger. Founder-observed on Android.
      expect(kFloatingControlTapTarget, greaterThanOrEqualTo(48.0));
    });

    test('both compositions are tall enough to hold one', () {
      for (final composition in FloatingCallComposition.values) {
        expect(
          floatingCallSize(composition).height,
          greaterThanOrEqualTo(kFloatingControlTapTarget),
          reason: '$composition cannot fit a reachable control',
        );
      }
    });

    test('the scrim over a picture can hold one', () {
      expect(
        kFloatingCallScrimHeight,
        greaterThanOrEqualTo(kFloatingControlTapTarget),
      );
    });
  });
}
