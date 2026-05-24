import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/media/aura_media_frame.dart';
import '../../../../../core/ui/aura_platform_components.dart';
import '../../../../../core/ui/aura_radius.dart';
import '../../../../../core/ui/aura_space.dart';
import '../../../../../core/ui/aura_surface.dart';
import '../../../../../core/ui/aura_text.dart';
import 'post_card_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VISIBILITY META
// ─────────────────────────────────────────────────────────────────────────────

class PostCardVisibilityMeta extends StatelessWidget {
  const PostCardVisibilityMeta({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AuraSurface.muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDENTITY HEADER
// ─────────────────────────────────────────────────────────────────────────────

class PostCardIdentityHeader extends StatelessWidget {
  const PostCardIdentityHeader({
    super.key,
    required this.displayName,
    required this.handle,
    required this.contextLine,
    required this.avatarUrl,
    required this.createdLabel,
    required this.visibilityLabel,
    required this.visibilityIcon,
    required this.compact,
    required this.onMenuTap,
    this.onProfileTap,
  });

  final String displayName;
  final String handle;
  final String contextLine;
  final String? avatarUrl;
  final String createdLabel;
  final String visibilityLabel;
  final IconData visibilityIcon;
  final bool compact;
  final VoidCallback? onProfileTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final metaParts = <String>[
      if (handle.trim().isNotEmpty) '@${handle.trim()}',
      if (createdLabel.trim().isNotEmpty) createdLabel.trim(),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onProfileTap,
            child: Padding(
              padding: const EdgeInsets.only(
                right: AuraSpace.s8,
                top: 2,
                bottom: 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuraAvatar(
                    name: displayName,
                    imageUrl: avatarUrl,
                    size: compact ? 36.0 : 40.0,
                  ),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AuraText.body.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (metaParts.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              metaParts.join(' · '),
                              style: AuraText.small.copyWith(
                                color: AuraSurface.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (!compact && contextLine.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              contextLine.trim(),
                              style: AuraText.small.copyWith(
                                color: AuraSurface.muted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (visibilityLabel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: PostCardVisibilityMeta(
                              icon: visibilityIcon,
                              label: visibilityLabel,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: onMenuTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(color: AuraSurface.divider),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.more_horiz,
              size: 18,
              color: AuraSurface.muted,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA BLOCK
// ─────────────────────────────────────────────────────────────────────────────

class PostCardMediaBlock extends StatelessWidget {
  const PostCardMediaBlock({
    super.key,
    required this.items,
    required this.postId,
    required this.maxHeight,
    required this.onOpenMediaAt,
  });

  final List<PostCardResolvedMediaItem> items;
  final String postId;
  final double maxHeight;
  final ValueChanged<int> onOpenMediaAt;

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return PostCardSingleMediaCard(
        item: items.first,
        maxHeight: maxHeight,
        // Single discourse media renders at detail width so it stays
        // compositionally balanced with the post's text column instead
        // of sitting feed-narrow (720px) inside a wider record column.
        mode: AuraMediaFrameMode.detail,
        onTap: () => onOpenMediaAt(0),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AuraSpace.s12;
        final totalWidth = constraints.maxWidth;
        final columns = totalWidth >= 760 ? 2 : 1;
        final cardWidth = columns == 1
            ? totalWidth
            : (totalWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(items.length, (index) {
            final item = items[index];
            return SizedBox(
              width: cardWidth,
              child: PostCardSingleMediaCard(
                item: item,
                maxHeight: columns == 1 ? maxHeight : 260,
                onTap: () => onOpenMediaAt(index),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE MEDIA CARD
// ─────────────────────────────────────────────────────────────────────────────

class PostCardSingleMediaCard extends StatelessWidget {
  const PostCardSingleMediaCard({
    super.key,
    required this.item,
    required this.maxHeight,
    required this.onTap,
    this.mode = AuraMediaFrameMode.feed,
  });

  final PostCardResolvedMediaItem item;
  final double maxHeight;
  final VoidCallback onTap;

  /// Media frame mode. Defaults to [AuraMediaFrameMode.feed] (used by
  /// the multi-image grid tiles); the single-media path passes
  /// [AuraMediaFrameMode.detail] for a column-balanced render.
  final AuraMediaFrameMode mode;

  String _durationLabel() {
    final ms = item.duration;
    if (ms == null || ms <= 0) return '';
    final totalSeconds = (ms / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final imageUrl = item.previewUrl;

    // ── SVG branch keeps its own bounded ClipRRect+AspectRatio since
    //    AuraMediaFrame is built around raster URL pipelines. SVGs are
    //    rare (mostly server-generated infographics); the same crop/
    //    contain reasoning still applies, so prefer contain.
    if (item.isSvg && imageUrl.isNotEmpty) {
      return _buildSvgCard(context, imageUrl, radius);
    }

    // ── Empty/error tile.
    if (imageUrl.isEmpty) {
      return _buildEmptyCard(context, radius);
    }

    // ── Standard image (or video poster). Everything goes through the
    //    canonical [AuraMediaFrame] so crop/contain, max width/height,
    //    and clipping are decided in one place.
    final overlay = item.isVideo
        ? Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam,
                          size: 14, color: Colors.white),
                      if (_durationLabel().isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          _durationLabel(),
                          style: AuraText.small.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          )
        : null;

    final frame = AuraMediaFrame(
      url: imageUrl,
      attachmentId: item.id.isNotEmpty ? item.id : null,
      intrinsicWidth: item.width,
      intrinsicHeight: item.height,
      mode: mode,
      maxHeightOverride: maxHeight,
      borderRadius: radius,
      onTap: onTap,
      foreground: overlay,
      errorWidget: (_) => Container(
        color: AuraSurface.elevated,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AuraSpace.s12),
        child: Text(
          item.isVideo ? 'Video unavailable' : 'Media unavailable',
          style: AuraText.small,
          textAlign: TextAlign.center,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        frame,
        if ((item.caption ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s8),
          Text(
            item.caption!.trim(),
            style: AuraText.small.copyWith(height: 1.35),
          ),
        ],
        if (item.editDisclosure) ...[
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Edited for clarity or privacy',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSvgCard(BuildContext context, String url, BorderRadius radius) {
    // SVGs render via flutter_svg directly. We still apply the canonical
    // ClipRRect + bounded AspectRatio with contain so a poster-style
    // infographic stays readable instead of being aggressively cropped.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ClipRRect(
            borderRadius: radius,
            child: Container(
              color: AuraSurface.subtle,
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: SvgPicture.network(
                  url,
                  fit: BoxFit.contain,
                  placeholderBuilder: (_) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
        if ((item.caption ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s8),
          Text(
            item.caption!.trim(),
            style: AuraText.small.copyWith(height: 1.35),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyCard(BuildContext context, BorderRadius radius) {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        color: AuraSurface.elevated,
        constraints: const BoxConstraints(minHeight: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AuraSpace.s12),
        child: Text(
          item.isVideo ? 'Video unavailable' : 'Media unavailable',
          style: AuraText.small,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MENU ACTION TILE
// ─────────────────────────────────────────────────────────────────────────────

class PostCardMenuActionTile extends StatelessWidget {
  const PostCardMenuActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: AuraText.body),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE
// ─────────────────────────────────────────────────────────────────────────────

enum PostCardBadgeTone { neutral, good, warn }

class PostCardBadge extends StatelessWidget {
  const PostCardBadge({super.key, required this.text, required this.tone});

  final String text;
  final PostCardBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (tone) {
      case PostCardBadgeTone.good:
        bg = AuraSurface.coVerdant.withValues(alpha: 0.16);
        fg = AuraSurface.coVerdant;
        break;
      case PostCardBadgeTone.warn:
        bg = AuraSurface.coSun.withValues(alpha: 0.16);
        fg = AuraSurface.coSun;
        break;
      case PostCardBadgeTone.neutral:
        bg = AuraSurface.elevated;
        fg = AuraSurface.ink;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        text,
        style: AuraText.small.copyWith(color: fg, fontWeight: FontWeight.w800),
      ),
    );
  }
}
