import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../posts/data/reactions_repository.dart';
import '../domain/feed_item.dart';
import 'feed_interaction_bar.dart';

/// Single render path for every feed surface.
///
/// Phase 1 scope: tap-to-navigate to the target route, author tap to profile,
/// shell-aware route adaptation, visibility badges. Like/reply/repost
/// affordances are shown but route to the existing detail screen for now;
/// Phase 3 will wire reactions and reply actions in-line.
class UnifiedFeedCard extends ConsumerWidget {
  const UnifiedFeedCard({
    super.key,
    required this.item,
    this.showVisibilityBadge = true,
    this.showInteractionBar = true,
  });

  final FeedItem item;

  /// Whether to render the visibility chip (PUBLIC / MEMBER_ONLY / INTERNAL).
  /// Off on surfaces where everything is the same visibility (e.g. profile).
  final bool showVisibilityBadge;

  /// When false, hides the like/reply/repost row. Useful for compact preview
  /// surfaces (search, activity).
  final bool showInteractionBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;
    final adaptedTarget = FeedRouting.adaptTargetRoute(
      item.targetRoute,
      currentPath: currentPath,
    );
    final adaptedProfile = FeedRouting.adaptProfileRoute(
      item.author.profileRoute,
      currentPath: currentPath,
    );

    return InkWell(
      onTap: adaptedTarget.isEmpty ? null : () => context.push(adaptedTarget),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.s14),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AuthorRow(
              author: item.author,
              publishedAt: item.publishedAt ?? item.createdAt,
              profileRoute: adaptedProfile,
            ),
            if (item.title != null && item.title!.trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s10),
              Text(
                item.title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AuraText.body.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ],
            if (item.body.trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s8),
              Text(
                item.body,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: AuraText.body
                    .copyWith(color: AuraSurface.ink, height: 1.5),
              ),
            ],
            if (item.mediaUrl != null && item.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s10),
              _MediaThumb(url: item.mediaUrl!),
            ],
            if (showVisibilityBadge) ...[
              const SizedBox(height: AuraSpace.s10),
              _MetaRow(
                visibility: item.visibility,
                distribution: item.distribution,
              ),
            ],
            if (showInteractionBar) ...[
              const SizedBox(height: AuraSpace.s12),
              FeedInteractionBar(target: _reactionTargetFor(item)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Maps a FeedItem to the right ReactionTarget polymorph.
///
/// User posts → `PostReactionTarget(item.id)`.
/// Institution posts → `InstitutionPostReactionTarget` keyed by the
/// institution that owns the post (which is `author.id` for institution-
/// authored items, since the projection uses the institution as the author).
ReactionTarget _reactionTargetFor(FeedItem item) {
  if (item.type == FeedItemType.institutionPost) {
    return InstitutionPostReactionTarget(
      institutionId: item.author.id,
      postId: item.id,
    );
  }
  return PostReactionTarget(item.id);
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.author,
    required this.publishedAt,
    required this.profileRoute,
  });

  final FeedAuthor author;
  final DateTime? publishedAt;
  final String? profileRoute;

  @override
  Widget build(BuildContext context) {
    final initial = author.name.trim().isNotEmpty
        ? author.name.trim()[0].toUpperCase()
        : (author.handleOrSlug.isNotEmpty
            ? author.handleOrSlug[0].toUpperCase()
            : '?');
    final tap = profileRoute == null || profileRoute!.isEmpty
        ? null
        : () => context.push(profileRoute!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(20),
          child: _Avatar(
            imageUrl: author.avatarOrLogoUrl,
            fallback: initial,
            isInstitution: author.isInstitution,
          ),
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: InkWell(
            onTap: tap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author.name.isNotEmpty
                      ? author.name
                      : (author.handleOrSlug.isNotEmpty
                          ? '@${author.handleOrSlug}'
                          : 'Unknown'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
                ),
                if (author.handleOrSlug.isNotEmpty &&
                    author.name.isNotEmpty)
                  Text(
                    author.isInstitution
                        ? '/${author.handleOrSlug}'
                        : '@${author.handleOrSlug}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
              ],
            ),
          ),
        ),
        if (publishedAt != null)
          Text(
            _formatRelative(publishedAt!),
            style: AuraText.micro.copyWith(color: AuraSurface.faint),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageUrl,
    required this.fallback,
    required this.isInstitution,
  });

  final String? imageUrl;
  final String fallback;
  final bool isInstitution;

  @override
  Widget build(BuildContext context) {
    final shape = isInstitution ? BoxShape.rectangle : BoxShape.circle;
    final radius = isInstitution
        ? BorderRadius.circular(AuraRadius.sm)
        : null;
    final url = imageUrl?.trim() ?? '';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: radius,
        color: AuraSurface.subtle,
        border: Border.all(color: AuraSurface.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Center(
              child: Text(
                fallback,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  fallback,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            color: AuraSurface.subtle,
            child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: AuraSurface.faint),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.visibility, required this.distribution});

  final FeedVisibility visibility;
  final FeedDistribution distribution;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s6,
      runSpacing: AuraSpace.s6,
      children: [
        _Badge(
          icon: _visibilityIcon(visibility),
          label: _visibilityLabel(visibility),
        ),
        if (distribution == FeedDistribution.globalEligible)
          const _Badge(
            icon: Icons.public,
            label: 'Global',
            tone: _BadgeTone.accent,
          ),
      ],
    );
  }

  IconData _visibilityIcon(FeedVisibility v) {
    switch (v) {
      case FeedVisibility.public:
        return Icons.public_rounded;
      case FeedVisibility.memberOnly:
        return Icons.group_rounded;
      case FeedVisibility.internal:
        return Icons.lock_outline_rounded;
      case FeedVisibility.unknown:
        return Icons.help_outline_rounded;
    }
  }

  String _visibilityLabel(FeedVisibility v) {
    switch (v) {
      case FeedVisibility.public:
        return 'Public';
      case FeedVisibility.memberOnly:
        return 'Members';
      case FeedVisibility.internal:
        return 'Internal';
      case FeedVisibility.unknown:
        return '';
    }
  }
}

enum _BadgeTone { neutral, accent }

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    this.tone = _BadgeTone.neutral,
  });

  final IconData icon;
  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final isAccent = tone == _BadgeTone.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAccent
            ? const Color(0x1E0D9488)
            : AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color:
              isAccent ? const Color(0xFF0D9488) : AuraSurface.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isAccent ? const Color(0xFF5EEAD4) : AuraSurface.muted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AuraText.micro.copyWith(
              color: isAccent ? const Color(0xFF5EEAD4) : AuraSurface.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRelative(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final yyyy = when.year.toString().padLeft(4, '0');
  final mm = when.month.toString().padLeft(2, '0');
  final dd = when.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}
