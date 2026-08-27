/// MEDIA INTERACTION PROFILE — layer 4 of the canonical media architecture.
///
///     MEDIA IDENTITY              stored_media.dart
///     RESOLUTION / AUTHORIZATION  media_url_resolver.dart + the media door
///     PRESENTATION                the presenter registries
///  →  PLATFORM INTERACTION        THIS FILE
///     SOURCE / FILE ACTIONS       media_save_service, openMediaExternally
///
/// ## WHY THIS EXISTS
///
/// `AuraMediaViewer` contained ZERO references to `defaultTargetPlatform`,
/// `kIsWeb` or `Platform.is` — a measured count, not an impression. Its only
/// branch was image-versus-video. So a desktop pointer-and-keyboard model —
/// a zoom percentage readout, a −/+/fit/100% button cluster, and two permanent
/// source actions — shipped byte-identically to Android and iOS, where none of
/// it is how a person handles a photograph.
///
/// Central authority was never the problem; centralising the WRONG LAYER was.
/// Identity, authorization and provenance must be identical everywhere. How a
/// person touches the media must not be.
///
///     CENTRAL IDENTITY AND POLICY.  PLATFORM-AWARE INTERACTION.
///
/// ## WHY IT IS DATA, NOT A PILE OF `if (isMobile)`
///
/// A profile is resolved once and passed down. Presenters ask what they may
/// offer; they never ask what device they are on. That is what keeps a new
/// presenter — a PDF, a 3D asset — from having to rediscover the platform
/// rules, and what makes every rule here testable without a device.
library;

import 'package:flutter/foundation.dart';

/// How a person points at things.
enum PointerModel {
  /// Fingers. Direct manipulation; gestures are the primary interface.
  touch,

  /// A mouse or trackpad, with a keyboard alongside.
  pointer,
}

/// Where the media is being interacted with.
enum MediaSurface { inline, immersive }

/// What a presenter is allowed to offer on this platform.
@immutable
class MediaInteractionProfile {
  const MediaInteractionProfile({
    required this.pointer,
    required this.pinchZoom,
    required this.doubleTapZoom,
    required this.zoomButtons,
    required this.zoomReadout,
    required this.keyboardShortcuts,
    required this.swipeToDismiss,
    required this.edgeToEdge,
    required this.explicitFullscreen,
    required this.canDecodeVideo,
    required this.persistentSourceActions,
  });

  final PointerModel pointer;

  /// Pinch-to-zoom is available and is the expected way to zoom.
  final bool pinchZoom;

  /// Double tap / double click toggles between fit and a close-up.
  final bool doubleTapZoom;

  /// Show discrete −/+/fit/100% controls.
  ///
  /// FALSE ON TOUCH, deliberately. A phone user manipulates the image
  /// physically; managing a zoom level through buttons is a desktop concept
  /// that was only ever on phones because nothing branched.
  final bool zoomButtons;

  /// Show a numeric zoom percentage.
  ///
  /// The `38%` the founder observed. It is genuinely useful when zoom is
  /// indirect and stepwise; it is noise when the image is under your thumb.
  final bool zoomReadout;

  /// Esc / arrows / +,−,0 are meaningful here.
  final bool keyboardShortcuts;

  /// A downward swipe dismisses the viewer.
  ///
  /// Gated at fit scale by the caller — see [dismissGestureAvailable]. A
  /// zoomed image owns vertical drag for panning, and taking that away to
  /// close the viewer is the single most common way this gesture is got wrong.
  final bool swipeToDismiss;

  /// Present media near edge-to-edge with minimal persistent chrome.
  final bool edgeToEdge;

  /// The platform has a fullscreen concept distinct from the immersive viewer.
  ///
  /// False on phones because the immersive viewer already IS fullscreen; a
  /// fullscreen button there would promise a state the user is already in.
  final bool explicitFullscreen;

  /// Stored video can be decoded at all.
  ///
  /// False on Windows and Linux: `video_player` resolves only
  /// video_player_android, video_player_avfoundation and video_player_web.
  /// This is a capability fact, and the interaction rules read it rather than
  /// asserting playback that cannot happen.
  final bool canDecodeVideo;

  /// Source actions belong in primary chrome rather than an overflow.
  ///
  /// True only where Aura cannot present the media itself, which is exactly
  /// the Windows video case: there, opening externally is not clutter, it is
  /// the only way to watch the video.
  final bool persistentSourceActions;

  /// Whether a dismiss gesture may fire right now.
  ///
  /// The rule the ruling asks for, in one place: a dismiss gesture is offered
  /// only when it cannot conflict with panning a zoomed image.
  bool dismissGestureAvailable({required bool isZoomed}) =>
      swipeToDismiss && !isZoomed;

  /// Resolve for the current platform.
  ///
  /// [canDecodeVideo] is injected rather than recomputed so this file states
  /// interaction rules and `aura_video_surface.dart` remains the single place
  /// that knows which decoders resolve.
  factory MediaInteractionProfile.resolve({
    required bool canDecodeVideo,
    TargetPlatform? platform,
    bool? isWeb,
  }) {
    final web = isWeb ?? kIsWeb;
    final p = platform ?? defaultTargetPlatform;

    // Touch is decided by INPUT MODEL, not by operating system. A browser on a
    // phone is a touch client; asking `kIsWeb` alone would have handed it the
    // desktop model, which is the mistake this whole layer exists to undo.
    final isTouch = p == TargetPlatform.android || p == TargetPlatform.iOS;

    if (isTouch) {
      return MediaInteractionProfile(
        pointer: PointerModel.touch,
        pinchZoom: true,
        doubleTapZoom: true,
        zoomButtons: false,
        zoomReadout: false,
        // Harmless when no keyboard is attached, and correct when one is.
        keyboardShortcuts: false,
        swipeToDismiss: true,
        edgeToEdge: true,
        explicitFullscreen: false,
        canDecodeVideo: canDecodeVideo,
        persistentSourceActions: false,
      );
    }

    return MediaInteractionProfile(
      pointer: PointerModel.pointer,
      // A trackpad pinches, and a touchscreen laptop exists. Allowing it costs
      // nothing and refusing it would be a guess about hardware.
      pinchZoom: true,
      doubleTapZoom: true,
      zoomButtons: true,
      zoomReadout: true,
      keyboardShortcuts: true,
      // A pointer has Esc, a close button and a backdrop. A drag-down gesture
      // would fight text selection and pointer panning for no gain.
      swipeToDismiss: false,
      edgeToEdge: false,
      explicitFullscreen: true,
      canDecodeVideo: canDecodeVideo,
      // THE CASE THAT PROVES THE MODEL. Where Aura cannot present the media,
      // the source action stops being clutter and becomes the only route to
      // it. The same action is demoted on a phone and promoted here, from one
      // capability fact rather than two hard-coded opinions.
      persistentSourceActions: web ? false : !canDecodeVideo,
    );
  }
}
