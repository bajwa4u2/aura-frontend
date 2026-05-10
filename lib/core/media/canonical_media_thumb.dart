import 'package:flutter/material.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_surface.dart';
import '../../features/feed/domain/feed_media.dart';
import 'aura_attachment_image.dart';
import 'aura_resolvable_attachment_image.dart';

/// Renders a single canonical [FeedMedia] entry honoring its visibility:
///
///   * `PUBLIC`     → [AuraAttachmentImage] using the permanent URL.
///   * non-PUBLIC   → [AuraResolvableAttachmentImage], which calls
///                    `GET /v1/media/:id/url` for a fresh signed URL.
///
/// This widget is the single rendering decision point for canonical Media
/// across feed cards, post detail, institution post detail, announcement
/// list cards, and announcement detail. Adding a new surface should reuse
/// this rather than re-deriving the public/restricted branch.
///
/// Sizing contract: the thumb fills the available width up to [maxWidth]
/// and applies [aspectRatio] to derive height. On narrow viewports
/// (mobile, ~360–600px) it fills the parent. On wide viewports
/// (tablet/desktop) it caps at [maxWidth] so a 1920×1080 PNG doesn't
/// blow a card to viewport-width. Use [maxWidth] = `double.infinity`
/// to opt out of the cap when a surface deliberately wants the full
/// available width (rare).
class CanonicalMediaThumb extends StatelessWidget {
  const CanonicalMediaThumb({
    super.key,
    required this.media,
    this.aspectRatio = 16 / 9,
    this.fit = BoxFit.cover,
    this.maxWidth = 720,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final FeedMedia media;
  final double aspectRatio;
  final BoxFit fit;

  /// Hard cap on the thumb's width. Used so wide viewports don't
  /// stretch a single image to fill the page.
  final double maxWidth;

  /// Where to anchor the thumb when [maxWidth] caps it below the
  /// available width. Defaults to start so cards keep their reading
  /// rhythm; pass `Alignment.center` for hero strips.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (media.isPublic) {
      final url = (media.url ?? '').trim();
      if (url.isEmpty) {
        child = const BrokenMediaTile();
      } else {
        child = AuraAttachmentImage(
          url: url,
          attachmentId: media.mediaId.isNotEmpty ? media.mediaId : null,
          fit: fit,
          errorWidget: (_) => const BrokenMediaTile(),
        );
      }
    } else {
      child = AuraResolvableAttachmentImage(
        mediaId: media.mediaId,
        fit: fit,
        errorWidget: (_) => const BrokenMediaTile(),
      );
    }

    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: AspectRatio(aspectRatio: aspectRatio, child: child),
    );

    if (!maxWidth.isFinite) return framed;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: framed,
      ),
    );
  }
}

/// Fallback tile shown when canonical media is missing, deleted, or
/// access is denied. Matched aesthetically to the legacy `_MediaThumb`
/// fallback so PUBLIC and non-PUBLIC rows look identical when
/// unavailable.
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
