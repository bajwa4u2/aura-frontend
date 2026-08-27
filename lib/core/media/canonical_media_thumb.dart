import 'package:flutter/material.dart';

import '../ui/aura_surface.dart';
import '../../features/feed/domain/feed_media.dart';
import 'aura_media_frame.dart';
import 'aura_media_viewer.dart';
import 'aura_stored_media.dart';
import 'stored_media.dart';

/// Renders a single canonical [FeedMedia] entry inside the canonical
/// [AuraMediaFrame].
///
/// Sizing/aspect/clip behavior lives entirely in [AuraMediaFrame]; this
/// widget is a thin adapter that maps the [FeedMedia] payload onto the
/// frame's API:
///
///   * `media.isPublic` → routes to public-URL or signed-URL flow.
///   * `media.width` / `media.height` → drives the intrinsic-aspect
///     decision so landscape photos and portrait/text-heavy graphics
///     render appropriately.
///
/// Tapping the thumb opens the canonical fullscreen [AuraMediaViewer]
/// (zoom / pan / open original / download original) unless the caller
/// supplies an explicit [onTap] override.
///
/// [mode] selects feed vs. detail behavior. Default is
/// [AuraMediaFrameMode.feed]; pass [AuraMediaFrameMode.detail] from
/// detail screens to allow a larger media surface.
class CanonicalMediaThumb extends StatelessWidget {
  const CanonicalMediaThumb({
    super.key,
    required this.media,
    this.mode = AuraMediaFrameMode.feed,
    this.alignment = AlignmentDirectional.centerStart,
    this.onTap,
    this.downloadContext = 'media',
  });

  final FeedMedia media;
  final AuraMediaFrameMode mode;
  final AlignmentGeometry alignment;

  /// Explicit tap override. When null the thumb opens the fullscreen
  /// [AuraMediaViewer] for this media.
  final VoidCallback? onTap;

  /// Filename context token forwarded to the viewer's download action,
  /// e.g. `post-media`, `announcement-media`,
  /// `institution-announcement-media`.
  final String downloadContext;

  @override
  Widget build(BuildContext context) {
    // The inline save affordance is offered only for public image
    // media: its [url] is directly fetchable. Visibility-gated
    // (RESTRICTED/PRIVATE) media needs a freshly signed URL the
    // resolver owns — the viewer resolves it on demand instead.
    final canSave = media.isPublic && media.isImage;
    final saveUrl = canSave ? (media.url ?? '').trim() : '';

    final hasViewable = (media.url ?? '').trim().isNotEmpty ||
        media.mediaId.trim().isNotEmpty;
    final effectiveTap = onTap ??
        (hasViewable ? () => _openViewer(context) : null);

    // VIDEO IS NOT A RASTER URL.
    //
    // This adapter used to have no video branch: it handed `media.url` to the
    // image pipeline whatever the media was. An MP4 given to an image decoder
    // fails, and the frame fell back to `BrokenMediaTile` — the broken-image
    // glyph founder-observed on the feed. Because the feed, announcements and
    // institution announcements all reach media through this one adapter, that
    // single missing branch broke video on all three at once.
    //
    // Stored video is DELEGATED, not handled here. This adapter is a consumer
    // of the stored-media authority, never its owner: a thumbnail is one
    // presentation capability of a stored object, not the domain model for
    // one. Poster resolution, the play affordance, duration, loading and the
    // honest failure states all belong to that layer, which is why fixing this
    // one delegation fixes the feed, announcements and institution
    // announcements together.
    //
    // The card still hands off to the fullscreen viewer on tap: a feed card
    // references media, it is not the media's home.
    if (media.isVideo) {
      return AuraStoredMedia(
        media: _asStoredMedia(media),
        context: mode == AuraMediaFrameMode.detail
            ? StoredMediaContext.detail
            : StoredMediaContext.feed,
        onOpenViewer: effectiveTap,
      );
    }

    return AuraMediaFrame(
      url: media.url,
      attachmentId: media.mediaId.isNotEmpty ? media.mediaId : null,
      mediaId: media.mediaId,
      isPublic: media.isPublic,
      intrinsicWidth: media.width,
      intrinsicHeight: media.height,
      mode: mode,
      alignment: alignment,
      semanticLabel: media.caption,
      onTap: effectiveTap,
      saveUrl: saveUrl.isEmpty ? null : saveUrl,
      saveFilename:
          media.mediaId.isNotEmpty ? 'aura-${media.mediaId}' : null,
      errorWidget: (_) => const BrokenMediaTile(),
    );
  }

  void _openViewer(BuildContext context) {
    showAuraMediaViewer(
      context,
      items: [
        AuraViewerItem(
          originalUrl: (media.url ?? '').trim(),
          mediaId: media.mediaId.trim().isEmpty ? null : media.mediaId.trim(),
          isPublic: media.isPublic,
          isVideo: media.isVideo,
          caption: media.caption,
          intrinsicWidth: media.width,
          intrinsicHeight: media.height,
          downloadContext: downloadContext,
        ),
      ],
    );
  }
}

/// Adapter from the feed's wire model onto the canonical stored-media model.
///
/// Surfaces keep their own payload shapes; the presentation layer sees exactly
/// one. `mediaType` is passed as the declared kind and the mime alongside it,
/// so the canonical mime-first rule decides — this adapter does not.
StoredMedia _asStoredMedia(FeedMedia media) => StoredMedia.fromParts(
      mediaId: media.mediaId,
      mimeType: media.mimeType,
      declaredKind: media.mediaType,
      isPublic: media.isPublic,
      sourceUrl: media.url,
      posterUrl: media.thumbUrl,
      caption: media.caption,
      width: media.width,
      height: media.height,
      durationMs: media.duration,
    );

/// Fallback tile shown when canonical media is missing, deleted, or
/// access is denied. Kept as a public widget so legacy callers that
/// referenced it directly continue to compile.
class BrokenMediaTile extends StatelessWidget {
  const BrokenMediaTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AuraSurface.subtle,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: AuraSurface.faint),
      ),
    );
  }
}
