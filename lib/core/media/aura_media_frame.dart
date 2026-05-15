import 'package:flutter/material.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_surface.dart';
import 'aura_attachment_image.dart';
import 'aura_resolvable_attachment_image.dart';

/// Canonical Aura media frame.
///
/// Single rendering primitive for every photo/graphic shown in
/// content surfaces — feed cards, post detail, institution post
/// detail, announcement detail, announcement cards. Designed to
/// replace the three pre-existing renderers (`CanonicalMediaThumb`,
/// `_MediaThumb` in `unified_feed_card.dart`, and
/// `PostCardSingleMediaCard` in `post_card_parts.dart`), each of which
/// had a different crop/clip/aspect policy that produced the global
/// rendering drift documented in the May 2026 media pass.
///
/// Contract
/// --------
///   * **Never overflows the parent.** ClipRRect with [AuraRadius.md]
///     (or a caller override) is always applied. A `maxWidth`
///     constraint is always applied for [AuraMediaFrameMode.feed] and
///     [AuraMediaFrameMode.detail] (defaults derived from MediaQuery).
///   * **Predictable aspect.** If the caller passes intrinsic
///     dimensions and they sit inside a landscape-tolerance window
///     (0.85 ≤ aspect ≤ 1.91), the frame uses the intrinsic aspect
///     with `BoxFit.cover` so landscape photos look "photographic".
///     Otherwise — tall portrait, square, oversize, or unknown — the
///     frame uses a fixed bounded aspect with `BoxFit.contain` and a
///     subtle backdrop, so text-heavy generated graphics stay
///     readable instead of getting their headlines chopped off.
///   * **Visibility-aware.** When the caller indicates the media is
///     non-public (`isPublic == false`), the frame routes through
///     [AuraResolvableAttachmentImage] which fetches a signed URL via
///     `MediaUrlResolver`. Public media uses the supplied URL
///     directly via [AuraAttachmentImage].
///
/// Modes
/// -----
///   * [AuraMediaFrameMode.feed] — in-feed cards. Bounded width and
///     height; default aspect for unknown/portrait content is 16:9
///     with contain so the card rhythm stays stable.
///   * [AuraMediaFrameMode.detail] — single-item detail screens. More
///     generous width (1080 desktop / parent on mobile) and taller
///     height ceiling; aspect favors the image's intrinsic ratio with
///     contain so vertical posters render at full readable size.
///   * [AuraMediaFrameMode.thumbnail] — small fixed thumbnail (72×72
///     by default), cover, for compact lists.
enum AuraMediaFrameMode { feed, detail, thumbnail }

class AuraMediaFrame extends StatelessWidget {
  const AuraMediaFrame({
    super.key,
    this.url,
    this.attachmentId,
    this.mediaId,
    this.isPublic = true,
    this.intrinsicWidth,
    this.intrinsicHeight,
    this.mode = AuraMediaFrameMode.feed,
    this.alignment = AlignmentDirectional.centerStart,
    this.borderRadius,
    this.semanticLabel,
    this.maxWidthOverride,
    this.maxHeightOverride,
    this.aspectOverride,
    this.errorWidget,
    this.placeholder,
    this.onTap,
    this.foreground,
  });

  /// Permanent public URL. Required when [isPublic] is true. Ignored
  /// when [isPublic] is false (in which case [mediaId] drives the
  /// signed-URL resolution).
  final String? url;

  /// Cache key for the underlying CachedNetworkImage. Use the
  /// canonical Media id when known so a server-side replacement
  /// invalidates cleanly.
  final String? attachmentId;

  /// Server-issued Media id. Required when [isPublic] is false so the
  /// resolver can request a signed URL.
  final String? mediaId;

  /// Whether the media is publicly accessible. Default true.
  /// MEMBER_ONLY / INTERNAL / PRIVATE attachments must pass false so
  /// the frame routes via [AuraResolvableAttachmentImage].
  final bool isPublic;

  final int? intrinsicWidth;
  final int? intrinsicHeight;

  final AuraMediaFrameMode mode;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  final double? maxWidthOverride;
  final double? maxHeightOverride;

  /// Force a specific aspect ratio. When non-null this disables the
  /// intrinsic-aspect heuristic and the contain/cover decision; the
  /// frame uses the override aspect and `BoxFit.cover`. Use sparingly
  /// — the default heuristic is usually right.
  final double? aspectOverride;

  final WidgetBuilder? errorWidget;
  final WidgetBuilder? placeholder;
  final VoidCallback? onTap;

  /// Optional overlay rendered on top of the media (e.g. a video play
  /// glyph). Sized to the frame's content rect; clipped by the same
  /// ClipRRect.
  final Widget? foreground;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewportWidth = media.size.width;
    final isMobile = viewportWidth < 600;

    // ── Resolve frame bounds ────────────────────────────────────────
    final double maxWidth = _resolveMaxWidth(viewportWidth);
    final double maxHeight = _resolveMaxHeight(media.size.height);

    // ── Resolve aspect + fit ────────────────────────────────────────
    final _AspectDecision decision = _decideAspect(isMobile: isMobile);
    final BoxFit fit = decision.fit;
    final double aspect = decision.aspect;
    final bool useBackdrop = decision.useBackdrop;

    // ── Build the inner image widget ────────────────────────────────
    Widget image;
    final trimmedUrl = (url ?? '').trim();
    if (isPublic) {
      if (trimmedUrl.isEmpty) {
        image = _buildError(context);
      } else {
        image = AuraAttachmentImage(
          url: trimmedUrl,
          attachmentId: (attachmentId ?? mediaId)?.trim().isNotEmpty == true
              ? (attachmentId ?? mediaId)
              : null,
          fit: fit,
          // Pinch the alignment in BoxFit.cover so text-heavy content
          // anchored at the top (most quote graphics) keeps its
          // headline visible when slight cropping does occur.
          alignment: fit == BoxFit.cover
              ? Alignment.topCenter
              : Alignment.center,
          semanticLabel: semanticLabel,
          placeholder: placeholder,
          errorWidget: errorWidget ?? (_) => _buildError(context),
        );
      }
    } else {
      final id = (mediaId ?? '').trim();
      if (id.isEmpty) {
        image = _buildError(context);
      } else {
        image = AuraResolvableAttachmentImage(
          mediaId: id,
          fit: fit,
          alignment: fit == BoxFit.cover ? Alignment.topCenter : Alignment.center,
          semanticLabel: semanticLabel,
          placeholder: placeholder,
          errorWidget: errorWidget ?? (_) => _buildError(context),
        );
      }
    }

    // ── Compose into the aspect-bounded, clipped frame ──────────────
    final radius = borderRadius ?? BorderRadius.circular(AuraRadius.md);

    Widget framed = AspectRatio(
      aspectRatio: aspect,
      child: Container(
        color: useBackdrop ? AuraSurface.subtle : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: image),
            if (foreground != null) Positioned.fill(child: foreground!),
          ],
        ),
      ),
    );

    framed = ClipRRect(borderRadius: radius, child: framed);

    if (onTap != null) {
      framed = InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: framed,
      );
    }

    // ── Apply width + height bounds and start-align ─────────────────
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: framed,
      ),
    );
  }

  // ── Internals ────────────────────────────────────────────────────

  double _resolveMaxWidth(double viewportWidth) {
    if (maxWidthOverride != null) return maxWidthOverride!;
    switch (mode) {
      case AuraMediaFrameMode.feed:
        // Cap on desktop so wide cards don't render giant images, but
        // let mobile fill its parent.
        if (viewportWidth < 600) return double.infinity;
        return 720;
      case AuraMediaFrameMode.detail:
        if (viewportWidth < 600) return double.infinity;
        return 1080;
      case AuraMediaFrameMode.thumbnail:
        return 72;
    }
  }

  double _resolveMaxHeight(double viewportHeight) {
    if (maxHeightOverride != null) return maxHeightOverride!;
    switch (mode) {
      case AuraMediaFrameMode.feed:
        // Bounded so feed rhythm stays stable; tall posters letterbox
        // inside this ceiling rather than pushing the whole card.
        if (viewportHeight >= 900) return 520;
        if (viewportHeight >= 700) return 460;
        return 380;
      case AuraMediaFrameMode.detail:
        // 80% of viewport so even on a portrait phone the media never
        // pushes the action bar off-screen.
        return viewportHeight * 0.80;
      case AuraMediaFrameMode.thumbnail:
        return 72;
    }
  }

  _AspectDecision _decideAspect({required bool isMobile}) {
    // Caller override wins, used by detail viewers/avatars that want
    // a strict aspect.
    if (aspectOverride != null && aspectOverride! > 0) {
      return _AspectDecision(
        aspect: aspectOverride!,
        fit: BoxFit.cover,
        useBackdrop: false,
      );
    }

    final iw = intrinsicWidth ?? 0;
    final ih = intrinsicHeight ?? 0;
    final hasIntrinsic = iw > 0 && ih > 0;

    // Thumbnail mode is always 1:1 cover — fixed square thumbnails.
    if (mode == AuraMediaFrameMode.thumbnail) {
      return const _AspectDecision(
        aspect: 1.0,
        fit: BoxFit.cover,
        useBackdrop: false,
      );
    }

    if (!hasIntrinsic) {
      // Unknown intrinsic dimensions — safe default is contain inside
      // 16:9 with the subtle backdrop, so text-heavy generated graphics
      // never get accidentally cropped. Detail mode uses a slightly
      // taller default (3:2) since users expect more vertical room on
      // a dedicated detail surface.
      if (mode == AuraMediaFrameMode.detail) {
        return const _AspectDecision(
          aspect: 3 / 2,
          fit: BoxFit.contain,
          useBackdrop: true,
        );
      }
      return const _AspectDecision(
        aspect: 16 / 9,
        fit: BoxFit.contain,
        useBackdrop: true,
      );
    }

    final intrinsicAspect = iw / ih;
    // Landscape tolerance window: roughly 4:3 (1.33) up to 16:9 (1.78)
    // plus a little headroom on each side. Inside this window the
    // image is "photographic" and BoxFit.cover gives the right feel
    // even if the frame's aspect is slightly different.
    const landscapeMin = 0.85;
    const landscapeMax = 1.91;

    if (intrinsicAspect >= landscapeMin && intrinsicAspect <= landscapeMax) {
      // Discourse media must preserve informational integrity. When the
      // rendered aspect EXACTLY matches the source's intrinsic aspect,
      // `cover` and `contain` produce identical pixels — pick `cover` so
      // photographic content fills the card without subtle borders. The
      // capping path below (where intrinsic exceeds the mode's max
      // ratio) deliberately falls through to `contain` so the
      // information at the cropped edges is never lost.
      final lowerBound = mode == AuraMediaFrameMode.feed ? 0.85 : 0.6;
      final upperBound = mode == AuraMediaFrameMode.feed ? 1.91 : 2.4;
      final wouldClamp =
          intrinsicAspect < lowerBound || intrinsicAspect > upperBound;
      final cappedAspect = intrinsicAspect.clamp(lowerBound, upperBound);
      return _AspectDecision(
        aspect: cappedAspect,
        fit: wouldClamp ? BoxFit.contain : BoxFit.cover,
        useBackdrop: wouldClamp,
      );
    }

    // Outside the landscape window: portrait, very tall, or square.
    // Contain inside a bounded aspect with subtle backdrop. The
    // aspect is the FRAME aspect (not intrinsic) — letterboxing the
    // portrait inside the frame keeps card rhythm stable AND
    // preserves the entire text-heavy graphic.
    if (mode == AuraMediaFrameMode.detail) {
      // For detail, use a portrait-leaning aspect when the source is
      // portrait so we don't show big empty side bars.
      final frameAspect = intrinsicAspect < 1 ? (4 / 5) : (3 / 2);
      return _AspectDecision(
        aspect: frameAspect,
        fit: BoxFit.contain,
        useBackdrop: true,
      );
    }
    return _AspectDecision(
      aspect: isMobile ? (4 / 5) : (16 / 9),
      fit: BoxFit.contain,
      useBackdrop: true,
    );
  }

  Widget _buildError(BuildContext context) {
    if (errorWidget != null) return errorWidget!(context);
    return Container(
      color: AuraSurface.subtle,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        size: 28,
        color: AuraSurface.faint,
      ),
    );
  }
}

class _AspectDecision {
  const _AspectDecision({
    required this.aspect,
    required this.fit,
    required this.useBackdrop,
  });

  final double aspect;
  final BoxFit fit;
  final bool useBackdrop;
}
