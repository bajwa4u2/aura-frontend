import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  });

  final PostCardResolvedMediaItem item;
  final double maxHeight;
  final VoidCallback onTap;

  double? _ratio() {
    final w = item.width;
    final h = item.height;
    if (w != null && h != null && w > 0 && h > 0) {
      var ratio = w / h;
      if (ratio < 0.6) ratio = 0.6;
      if (ratio > 1.9) ratio = 1.9;
      return ratio;
    }
    return item.isVideo ? (16 / 9) : null;
  }

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
    final border = Border.all(color: AuraSurface.divider);
    final radius = BorderRadius.circular(16);
    final ratio = _ratio();

    final imageUrl = item.previewUrl;

    Widget mediaWidget;

    if (item.isSvg && imageUrl.isNotEmpty) {
      mediaWidget = SvgPicture.network(
        imageUrl,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => const SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else if (imageUrl.isNotEmpty) {
      mediaWidget = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          constraints: const BoxConstraints(minHeight: 180),
          alignment: Alignment.center,
          child: Text(
            item.isVideo ? 'Video unavailable' : 'Media unavailable',
            style: AuraText.small,
            textAlign: TextAlign.center,
          ),
        ),
        loadingBuilder: (c, child, p) {
          if (p == null) return child;
          return SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                value: (p.expectedTotalBytes != null)
                    ? (p.cumulativeBytesLoaded / (p.expectedTotalBytes ?? 1))
                    : null,
                strokeWidth: 2,
              ),
            ),
          );
        },
      );
    } else {
      mediaWidget = Container(
        constraints: const BoxConstraints(minHeight: 180),
        alignment: Alignment.center,
        child: Text(
          item.isVideo ? 'Video unavailable' : 'Media unavailable',
          style: AuraText.small,
          textAlign: TextAlign.center,
        ),
      );
    }

    Widget content = Stack(
      children: [
        Positioned.fill(child: mediaWidget),
        if (item.isVideo)
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
        if (item.isVideo)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AuraRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam, size: 14, color: Colors.white),
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
    );

    Widget mediaBox = ClipRRect(
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: border,
          color: AuraSurface.elevated,
        ),
        child: ratio == null
            ? ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: content,
              )
            : AspectRatio(aspectRatio: ratio, child: content),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(borderRadius: radius, onTap: onTap, child: mediaBox),
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
        bg = AuraSurface.goodBg;
        fg = AuraSurface.goodInk;
        break;
      case PostCardBadgeTone.warn:
        bg = AuraSurface.warnBg;
        fg = AuraSurface.warnInk;
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
