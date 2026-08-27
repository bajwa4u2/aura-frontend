/// AURA STORED MEDIA — the inline presentation layer of the stored-media
/// authority.
///
/// It answers exactly one question, for every kind of stored object:
///
///     WHAT SHOULD THIS MEDIA LOOK LIKE INLINE?
///
/// and it is the only place in the product allowed to answer it. Surfaces hand
/// over a resolved [StoredMedia] and a context; they do not branch on mime,
/// they do not reason about posters, and they never decide what an MP4 is.
///
/// ## WHY A REGISTRY AND NOT A SWITCH
///
/// A closed switch over today's kinds is how the product got here: each new
/// kind that did not fit became a surface-local special case, and video —
/// which fits no image pipeline — became four different improvisations. The
/// registry lets a new capability (a provider-backed preview, a document
/// thumbnailer, a live-processing state) be added as one presenter without
/// editing every consumer, and without this file becoming the place every
/// future media type is negotiated.
///
/// Presenters are consulted most-recently-registered first, and the built-in
/// set is last, so an application-level presenter can override a default
/// without deleting it.
///
/// ## WHAT THIS LAYER DOES NOT OWN
///
/// It does not own resolution (that is [StoredMedia]) and it does not own
/// fullscreen (that is `AuraMediaViewer`). It routes to the canonical
/// primitives — the video surface, the media frame, the voice player, the
/// attachment card — rather than reimplementing any of them.
library;

import 'package:flutter/material.dart';

import 'aura_attachment_card.dart';
import 'aura_media_frame.dart';
import 'aura_video_surface.dart';
import 'aura_voice_player.dart';
import 'canonical_media_thumb.dart';
import 'stored_media.dart';

/// Where the media is being shown. Presentation differs by context even for
/// the same object: a feed card references media, a message contains it.
enum StoredMediaContext {
  /// Lists and cards. Compact, and a tap hands off to the viewer.
  feed,

  /// Detail screens. Larger surface, still viewer-first.
  detail,

  /// Inside a message or correspondence body. Plays in place.
  message,

  /// Pre-send composition. Plays in place, and must work from local sources.
  compose,
}

/// Everything a presenter is given.
class StoredMediaRequest {
  const StoredMediaRequest({
    required this.media,
    this.context = StoredMediaContext.feed,
    this.maxHeight,
    this.borderRadius,
    this.onOpenViewer,
    this.onOpenFile,
    this.semanticLabel,
  });

  final StoredMedia media;
  final StoredMediaContext context;
  final double? maxHeight;
  final BorderRadius? borderRadius;

  /// Hand-off to the fullscreen viewer, where the surface offers one.
  final VoidCallback? onOpenViewer;

  /// Hand-off for objects opened outside the app (documents and the like).
  final VoidCallback? onOpenFile;

  final String? semanticLabel;

  /// True where the product expects media to play where it sits rather than
  /// pushing a fullscreen surface.
  bool get playsInline =>
      context == StoredMediaContext.message ||
      context == StoredMediaContext.compose;
}

/// A candidate presentation. Returning null means "not mine".
typedef StoredMediaPresenter = Widget? Function(
  BuildContext context,
  StoredMediaRequest request,
);

/// The presenter chain.
class AuraStoredMediaRegistry {
  AuraStoredMediaRegistry._();

  static final List<StoredMediaPresenter> _registered = <StoredMediaPresenter>[];

  /// Add a presenter ahead of the built-ins.
  static void register(StoredMediaPresenter presenter) =>
      _registered.insert(0, presenter);

  /// Test seam — drops application-registered presenters, keeping built-ins.
  @visibleForTesting
  static void resetForTest() => _registered.clear();

  /// Resolve a presentation, falling back to the honest identity card so this
  /// never returns nothing for an object the product does not yet understand.
  static Widget present(BuildContext context, StoredMediaRequest request) {
    for (final presenter in _registered) {
      final widget = presenter(context, request);
      if (widget != null) return widget;
    }
    for (final presenter in _builtIns) {
      final widget = presenter(context, request);
      if (widget != null) return widget;
    }
    return _identityCard(request);
  }

  static final List<StoredMediaPresenter> _builtIns = <StoredMediaPresenter>[
    _unavailablePresenter,
    _videoPresenter,
    _audioPresenter,
    _imagePresenter,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILT-IN PRESENTERS
// ─────────────────────────────────────────────────────────────────────────────

/// Nothing reachable. Said plainly, with the object's identity intact, before
/// any kind-specific presenter can try to render an absence.
Widget? _unavailablePresenter(BuildContext context, StoredMediaRequest r) {
  if (r.media.isReachable) return null;
  if (r.media.isVideo) {
    return AuraVideoUnavailableTile(
      fileName: r.media.fileName,
      borderRadius: r.borderRadius,
    );
  }
  return _identityCard(r);
}

/// Stored video, in every context, through the one canonical surface.
Widget? _videoPresenter(BuildContext context, StoredMediaRequest r) {
  if (!r.media.isVideo) return null;
  final media = r.media;

  final tap = r.playsInline ? AuraVideoTap.inline : AuraVideoTap.viewer;
  final maxHeight = r.maxHeight ??
      switch (r.context) {
        StoredMediaContext.feed => 360.0,
        StoredMediaContext.detail => 520.0,
        StoredMediaContext.message => 320.0,
        StoredMediaContext.compose => 320.0,
      };

  // Before there is a fetchable server URL, the local source is the only
  // truth — and that stays true WHILE the upload is in flight, not just
  // before it starts. Keying this on state alone would blank the preview the
  // moment someone pressed send.
  if (media.hasLocalPath && !media.hasSource) {
    return AuraVideoSurface(
      localPath: media.localPath,
      posterUrl: media.posterUrl,
      intrinsicWidth: media.width,
      intrinsicHeight: media.height,
      durationMs: media.durationMs,
      fileName: media.fileName,
      maxHeight: maxHeight,
      borderRadius: r.borderRadius,
      tap: AuraVideoTap.inline,
    );
  }

  return AuraVideoMedia(
    mediaId: media.mediaId,
    isPublic: media.isPublic,
    publicUrl: media.sourceUrl,
    posterUrl: media.posterUrl,
    intrinsicWidth: media.width,
    intrinsicHeight: media.height,
    durationMs: media.durationMs,
    fileName: media.fileName,
    maxHeight: maxHeight,
    borderRadius: r.borderRadius,
    tap: tap,
    onOpenViewer: r.onOpenViewer,
  );
}

/// Audio through the canonical voice player, which already owns the
/// recording-vs-uploaded distinction.
Widget? _audioPresenter(BuildContext context, StoredMediaRequest r) {
  if (!r.media.isAudio) return null;
  final url = (r.media.sourceUrl ?? '').trim();
  if (url.isEmpty) return null;
  return AuraVoicePlayer(
    url: url,
    fileName: r.media.fileName,
    durationMs: r.media.durationMs,
  );
}

/// Images through the canonical frame, which owns crop/contain and sizing.
Widget? _imagePresenter(BuildContext context, StoredMediaRequest r) {
  if (!r.media.isImage) return null;
  final media = r.media;

  if (media.hasLocalBytes) {
    return ClipRRect(
      borderRadius: r.borderRadius ?? BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: media.aspectRatio ?? 4 / 3,
        child: Image.memory(
          media.localBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }

  final url = (media.posterUrl ?? media.sourceUrl ?? '').trim();
  if (url.isEmpty && media.mediaId.isEmpty) return null;

  return AuraMediaFrame(
    url: url.isEmpty ? null : url,
    attachmentId: media.mediaId.isEmpty ? null : media.mediaId,
    mediaId: media.mediaId,
    isPublic: media.isPublic,
    intrinsicWidth: media.width,
    intrinsicHeight: media.height,
    mode: r.context == StoredMediaContext.detail
        ? AuraMediaFrameMode.detail
        : AuraMediaFrameMode.feed,
    maxHeightOverride: r.maxHeight,
    borderRadius: r.borderRadius,
    semanticLabel: r.semanticLabel ?? media.caption,
    onTap: r.onOpenViewer,
    errorWidget: (_) => const BrokenMediaTile(),
  );
}

/// Documents, archives and anything unrecognised keep their real identity and
/// are offered the action appropriate to their kind.
Widget _identityCard(StoredMediaRequest r) => AuraAttachmentCard(
      kind: r.media.kind,
      fileName: r.media.fileName,
      sizeBytes: r.media.sizeBytes,
      onOpen: r.onOpenFile,
      unavailableReason:
          r.media.isReachable ? null : 'Unavailable',
    );

// ─────────────────────────────────────────────────────────────────────────────
// THE CONSUMER-FACING WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Canonical inline presentation for one stored media object.
///
/// This is what product surfaces use. Posts, conversation, correspondence,
/// institution spaces, announcements and composers all reach media through
/// here, so a video shared into any of them behaves the same way.
class AuraStoredMedia extends StatelessWidget {
  const AuraStoredMedia({
    super.key,
    required this.media,
    this.context = StoredMediaContext.feed,
    this.maxHeight,
    this.borderRadius,
    this.onOpenViewer,
    this.onOpenFile,
    this.semanticLabel,
  });

  final StoredMedia media;
  final StoredMediaContext context;
  final double? maxHeight;
  final BorderRadius? borderRadius;
  final VoidCallback? onOpenViewer;
  final VoidCallback? onOpenFile;
  final String? semanticLabel;

  @override
  Widget build(BuildContext buildContext) {
    return AuraStoredMediaRegistry.present(
      buildContext,
      StoredMediaRequest(
        media: media,
        context: context,
        maxHeight: maxHeight,
        borderRadius: borderRadius,
        onOpenViewer: onOpenViewer,
        onOpenFile: onOpenFile,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
