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
class CanonicalMediaThumb extends StatelessWidget {
  const CanonicalMediaThumb({
    super.key,
    required this.media,
    this.aspectRatio = 16 / 9,
    this.fit = BoxFit.cover,
  });

  final FeedMedia media;
  final double aspectRatio;
  final BoxFit fit;

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

    return ClipRRect(
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: AspectRatio(aspectRatio: aspectRatio, child: child),
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
