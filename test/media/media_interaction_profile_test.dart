// PLATFORM INTERACTION CONTRACT — the layer that did not exist.
//
// `aura_media_viewer.dart` contained ZERO references to `defaultTargetPlatform`,
// `kIsWeb` or `Platform.is`. Its only branch was image-versus-video, so a
// desktop pointer-and-keyboard model — a zoom percentage, a −/+/fit/100%
// cluster and two permanent source actions — shipped byte-identically to
// Android and iOS.
//
// These tests hold the rules apart from the widgets, so a platform's behaviour
// can be asserted without that platform being present.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/immersive_presenter.dart';
import 'package:aura/core/media/media_interaction_profile.dart';

MediaInteractionProfile forPlatform(
  TargetPlatform p, {
  bool isWeb = false,
  bool canDecodeVideo = true,
}) =>
    MediaInteractionProfile.resolve(
      canDecodeVideo: canDecodeVideo,
      platform: p,
      isWeb: isWeb,
    );

ImmersiveCapabilities capsFor(
  MediaInteractionProfile profile, {
  required bool isVideo,
}) =>
    ImmersivePresenterRegistry.capabilitiesFor(
      ImmersiveRequest(
        isVideo: isVideo,
        mimeType: null,
        profile: profile,
        mediaId: 'm1',
        isPublic: true,
        originalUrl: 'https://example/x',
      ),
    );

void main() {
  group('ANDROID_IMAGE_INTERACTION / IOS_IMAGE_INTERACTION', () {
    for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('${p.name}: pinch, double-tap and pan — never a button cluster', () {
        final profile = forPlatform(p);
        expect(profile.pointer, PointerModel.touch);
        expect(profile.pinchZoom, isTrue);
        expect(profile.doubleTapZoom, isTrue);
        // The founder's `38%` and the −/+ pair. A phone user manipulates the
        // image physically rather than managing a zoom level.
        expect(profile.zoomButtons, isFalse);
        expect(profile.zoomReadout, isFalse);
      });

      test('${p.name}: immersive, minimal chrome, no redundant fullscreen', () {
        final profile = forPlatform(p);
        expect(profile.edgeToEdge, isTrue);
        // The immersive viewer already IS fullscreen; a button would promise a
        // state the user is in.
        expect(profile.explicitFullscreen, isFalse);
        expect(profile.persistentSourceActions, isFalse);
      });
    }

    test('GESTURE_CONFLICT_HANDLED — dismissal yields to a zoomed image', () {
      final profile = forPlatform(TargetPlatform.android);
      expect(profile.swipeToDismiss, isTrue);
      expect(profile.dismissGestureAvailable(isZoomed: false), isTrue);
      // A zoomed image owns vertical drag for panning. Taking that away to
      // close the viewer is the single most common way this is got wrong.
      expect(profile.dismissGestureAvailable(isZoomed: true), isFalse);
    });
  });

  group('WEB_IMAGE_INTERACTION / WINDOWS_IMAGE_INTERACTION', () {
    test('desktop keeps the pointer idiom: buttons, readout, keyboard', () {
      for (final p in [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]) {
        final profile = forPlatform(p);
        expect(profile.pointer, PointerModel.pointer, reason: p.name);
        expect(profile.zoomButtons, isTrue, reason: p.name);
        expect(profile.zoomReadout, isTrue, reason: p.name);
        expect(profile.keyboardShortcuts, isTrue, reason: p.name);
      }
    });

    test('a pointer does not get a drag-to-dismiss gesture', () {
      // It would fight text selection and pointer panning for no gain: Esc, a
      // close button and the backdrop all already exist.
      expect(forPlatform(TargetPlatform.windows).swipeToDismiss, isFalse);
    });

    test('a browser on a phone is a TOUCH client, not a desktop one', () {
      // Deciding on `kIsWeb` alone would hand a phone browser the desktop
      // model — the exact mistake this layer exists to undo.
      final mobileWeb = forPlatform(TargetPlatform.android, isWeb: true);
      expect(mobileWeb.pointer, PointerModel.touch);
      expect(mobileWeb.zoomButtons, isFalse);
    });
  });

  group('OPEN_ORIGINAL prominence follows CAPABILITY, not platform', () {
    test('OPEN_ORIGINAL_SECONDARY_WHEN_PRESENTABLE', () {
      final web = forPlatform(TargetPlatform.macOS, isWeb: true, canDecodeVideo: true);
      final caps = capsFor(web, isVideo: true);
      expect(caps.canPresent, isTrue);
      expect(caps.sourceActionIsPrimary, isFalse);
      expect(web.persistentSourceActions, isFalse);
    });

    test('OPEN_ORIGINAL_PRIMARY_WHEN_UNSUPPORTED — the Windows video case', () {
      // `video_player` resolves no Windows implementation. Here the source
      // action is not clutter; it is the only way to watch the video.
      final windows = forPlatform(TargetPlatform.windows, canDecodeVideo: false);
      final caps = capsFor(windows, isVideo: true);
      expect(caps.canPresent, isFalse);
      expect(caps.playable, isFalse);
      expect(caps.sourceActionIsPrimary, isTrue);
      expect(windows.persistentSourceActions, isTrue);
    });

    test('the SAME action is demoted on a phone and promoted on Windows', () {
      // One capability fact, two correct answers — which is the whole reason
      // this is a resolved profile rather than a hard-coded opinion.
      final phone = forPlatform(TargetPlatform.android, canDecodeVideo: true);
      final windows = forPlatform(TargetPlatform.windows, canDecodeVideo: false);
      expect(capsFor(phone, isVideo: true).sourceActionIsPrimary, isFalse);
      expect(capsFor(windows, isVideo: true).sourceActionIsPrimary, isTrue);
    });

    test('an image is presentable everywhere, so its source action never leads', () {
      for (final p in TargetPlatform.values) {
        final caps = capsFor(forPlatform(p, canDecodeVideo: false), isVideo: false);
        expect(caps.canPresent, isTrue, reason: p.name);
        expect(caps.sourceActionIsPrimary, isFalse, reason: p.name);
      }
    });
  });

  group('IMMERSIVE_PRESENTER_REGISTRY — no closed isVideo switch', () {
    setUp(ImmersivePresenterRegistry.resetForTest);
    tearDown(ImmersivePresenterRegistry.resetForTest);

    test('built-ins resolve image and video', () {
      final profile = forPlatform(TargetPlatform.android);
      expect(capsFor(profile, isVideo: false).zoomable, isTrue);
      expect(capsFor(profile, isVideo: true).playable, isTrue);
    });

    test('a registered presenter overrides a built-in without deleting it', () {
      ImmersivePresenterRegistry.register(_NeverPresents());
      final profile = forPlatform(TargetPlatform.android);
      // The application presenter wins...
      expect(capsFor(profile, isVideo: false).canPresent, isFalse);
      ImmersivePresenterRegistry.resetForTest();
      // ...and the built-in is still there afterwards.
      expect(capsFor(profile, isVideo: false).canPresent, isTrue);
    });

    test('video is not zoomable — pinching a playing video is not a gesture', () {
      expect(capsFor(forPlatform(TargetPlatform.iOS), isVideo: true).zoomable, isFalse);
    });

    test('a presentable video declares a real transport, not just play', () {
      final caps = capsFor(forPlatform(TargetPlatform.android), isVideo: true);
      // Play/pause and restart were the entire control set before this.
      expect(caps.scrubbable, isTrue);
      expect(caps.hasAudio, isTrue);
    });
  });
}

/// An application presenter that handles everything and can present nothing —
/// the shape a future PDF or 3D presenter would take before it gains a surface.
class _NeverPresents extends ImmersivePresenter {
  @override
  bool handles(ImmersiveRequest request) => true;

  @override
  ImmersiveCapabilities capabilitiesFor(ImmersiveRequest request) =>
      const ImmersiveCapabilities(canPresent: false);
}
