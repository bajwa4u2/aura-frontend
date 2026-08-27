/// THE IMMERSIVE PRESENTER REGISTRY.
///
/// The inline layer has always resolved presentation through an open registry.
/// The immersive viewer did not: it ended in
///
///     if (item.isVideo) { …video… } else { …image… }
///
/// which is exactly the permanently-closed central switch the extensibility
/// ruling forbids. A future presenter — a PDF, an audio waveform, a 3D asset —
/// could not participate in the fullscreen experience without editing that
/// file, so the registry stopped at the boundary where the media actually gets
/// its full attention.
///
/// This closes that gap with the SAME shape the inline layer already uses:
/// most-recently-registered first, built-ins last, so an application presenter
/// can override a default without deleting it.
///
/// ## WHAT A PRESENTER DECLARES
///
/// A presenter does not merely render. It declares what it CAN do, and the
/// viewer's chrome is assembled from that declaration crossed with the
/// platform's [MediaInteractionProfile]. That is what makes
/// `Open original` contextual rather than permanent: an action becomes primary
/// when the presenter reports it cannot present the media, and secondary when
/// it can — from one capability fact instead of two hard-coded opinions.
library;

import 'package:flutter/widgets.dart';

import 'media_interaction_profile.dart';

/// What a presenter can offer for a given item on a given platform.
@immutable
class ImmersiveCapabilities {
  const ImmersiveCapabilities({
    required this.canPresent,
    this.zoomable = false,
    this.playable = false,
    this.scrubbable = false,
    this.hasAudio = false,
  });

  /// Whether this presenter can actually show the media here.
  ///
  /// FALSE is not a failure — it is an honest capability report, and it is
  /// what promotes source access from an overflow item to the primary action.
  /// Windows video is the case that proves it: `video_player` resolves no
  /// Windows implementation, so opening externally is the only way to watch,
  /// and the chrome should say so instead of offering a play button that
  /// cannot work.
  final bool canPresent;

  final bool zoomable;
  final bool playable;
  final bool scrubbable;
  final bool hasAudio;

  /// Where the source action belongs, given what this presenter can do.
  ///
  /// The rule, stated once: PRIMARY exactly when Aura cannot present the
  /// media; SECONDARY whenever it can.
  bool get sourceActionIsPrimary => !canPresent;
}

/// Everything a presenter is given.
@immutable
class ImmersiveRequest {
  const ImmersiveRequest({
    required this.isVideo,
    required this.mimeType,
    required this.profile,
    required this.mediaId,
    required this.isPublic,
    required this.originalUrl,
  });

  final bool isVideo;
  final String? mimeType;
  final MediaInteractionProfile profile;
  final String? mediaId;
  final bool isPublic;
  final String originalUrl;
}

/// Declares capability and builds the surface.
abstract class ImmersivePresenter {
  const ImmersivePresenter();

  /// Whether this presenter handles the request at all.
  bool handles(ImmersiveRequest request);

  /// What it can offer. Only called when [handles] is true.
  ImmersiveCapabilities capabilitiesFor(ImmersiveRequest request);
}

/// The registry.
class ImmersivePresenterRegistry {
  ImmersivePresenterRegistry._();

  static final List<ImmersivePresenter> _registered = <ImmersivePresenter>[];

  /// Register an application presenter. Consulted before the built-ins.
  static void register(ImmersivePresenter presenter) =>
      _registered.insert(0, presenter);

  /// Test seam — drops application presenters, keeps built-ins.
  static void resetForTest() => _registered.clear();

  static final List<ImmersivePresenter> _builtIns = <ImmersivePresenter>[
    const _VideoImmersivePresenter(),
    const _ImageImmersivePresenter(),
  ];

  /// The presenter for this request, or null when nothing handles it.
  static ImmersivePresenter? presenterFor(ImmersiveRequest request) {
    for (final p in _registered) {
      if (p.handles(request)) return p;
    }
    for (final p in _builtIns) {
      if (p.handles(request)) return p;
    }
    return null;
  }

  /// Capabilities for this request.
  ///
  /// An unhandled kind reports `canPresent: false` rather than throwing, so an
  /// unknown media type degrades into "Aura cannot show this, here is the
  /// source" — which is the honest answer and already a designed state.
  static ImmersiveCapabilities capabilitiesFor(ImmersiveRequest request) {
    final presenter = presenterFor(request);
    if (presenter == null) return const ImmersiveCapabilities(canPresent: false);
    return presenter.capabilitiesFor(request);
  }
}

class _VideoImmersivePresenter extends ImmersivePresenter {
  const _VideoImmersivePresenter();

  @override
  bool handles(ImmersiveRequest request) => request.isVideo;

  @override
  ImmersiveCapabilities capabilitiesFor(ImmersiveRequest request) {
    // Capability comes from the platform profile, not from a guess. This is
    // the whole Windows story in one expression.
    final can = request.profile.canDecodeVideo;
    return ImmersiveCapabilities(
      canPresent: can,
      playable: can,
      scrubbable: can,
      hasAudio: can,
      // A video is not zoomed. Pinching a playing video is not a gesture
      // anyone expects, and offering it would fight the playback controls.
      zoomable: false,
    );
  }
}

class _ImageImmersivePresenter extends ImmersivePresenter {
  const _ImageImmersivePresenter();

  @override
  bool handles(ImmersiveRequest request) => !request.isVideo;

  @override
  ImmersiveCapabilities capabilitiesFor(ImmersiveRequest request) =>
      const ImmersiveCapabilities(canPresent: true, zoomable: true);
}
