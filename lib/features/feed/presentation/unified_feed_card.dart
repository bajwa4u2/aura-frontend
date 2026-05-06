import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../shared/identity/aura_identity_badge.dart';
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
    this.showReplyPreview = true,
  });

  final FeedItem item;

  /// Whether to render the visibility chip (PUBLIC / MEMBER_ONLY / INTERNAL).
  /// Off on surfaces where everything is the same visibility (e.g. profile).
  final bool showVisibilityBadge;

  /// When false, hides the like/reply/repost row. Useful for compact preview
  /// surfaces (search, activity).
  final bool showInteractionBar;

  /// Phase 5.1 — when false, the inline reply-preview block doesn't render.
  /// Detail screens turn this off because they already render the full
  /// reply list below the parent card; rendering both would duplicate the
  /// first 1–2 replies.
  final bool showReplyPreview;

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
            if (item.signal != null) ...[
              _SignalLabel(signal: item.signal!),
              const SizedBox(height: AuraSpace.s8),
            ],
            _AuthorRow(
              author: item.author,
              publishedAt: item.publishedAt ?? item.createdAt,
              profileRoute: adaptedProfile,
            ),
            if (_shouldRenderSecondary(item)) ...[
              const SizedBox(height: AuraSpace.s6),
              _SecondaryAttributionLine(
                attribution: item.secondaryAttribution!,
                currentPath: currentPath,
              ),
            ],
            if (item.voice != null && item.voice!.type.rendersLabel) ...[
              const SizedBox(height: 2),
              _VoiceLabelLine(voice: item.voice!),
            ],
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
            if (showReplyPreview &&
                item.replyPreview != null &&
                item.replyPreview!.items.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s10),
              if (item.activity?.recentReply == true) ...[
                const _ActivityHintLine(label: 'New reply'),
                const SizedBox(height: 6),
              ],
              _ReplyPreviewBlock(
                preview: item.replyPreview!,
                openTarget: adaptedTarget,
              ),
            ],
            if (showInteractionBar) ...[
              const SizedBox(height: AuraSpace.s12),
              if (_reactionTargetFor(item) case final reactionTarget?)
                FeedInteractionBar(
                  target: reactionTarget,
                  visibility: item.interaction,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Phase 6.4 — voice clarity line. Subordinate to both the primary author
/// and the secondary attribution; renders as a single uppercase micro-line
/// in the lightest UI color so it informs without competing.
class _VoiceLabelLine extends StatelessWidget {
  const _VoiceLabelLine({required this.voice});

  final FeedVoice voice;

  @override
  Widget build(BuildContext context) {
    final label = voice.label.trim();
    if (label.isEmpty) return const SizedBox.shrink();
    return Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        fontSize: 10,
      ),
    );
  }
}

/// Phase 6.3 — secondary attribution gating.
///
/// Only renders when the backend supplied real data AND the actor is
/// distinct from the primary author (defensive: an institution post whose
/// human author somehow shares an id with the institution should not show
/// "Posted by itself").
bool _shouldRenderSecondary(FeedItem item) {
  final attr = item.secondaryAttribution;
  if (attr == null) return false;
  if (attr.type == FeedSecondaryAttributionType.unknown) return false;
  final actor = attr.actor;
  if (actor.id.isEmpty) return false;
  if (actor.displayName.trim().isEmpty &&
      (actor.handle ?? '').trim().isEmpty) {
    return false;
  }
  // Skip when the secondary actor would duplicate the visible primary
  // identity. With current data this only happens in odd/legacy rows; the
  // safe default is to suppress.
  if (actor.id == item.author.id) return false;
  return true;
}

/// Phase 6.3 — small, muted, accountable line that sits below the author
/// row when an institution voice has a real human behind it.
///
/// Style rules: subordinate to the primary author row (smaller text,
/// muted color), tappable to the actor's profile, never rendered as a
/// metric. The optional context badge from Phase 6.1.1 is reused in
/// `replyPreview` mode so the line stays compact.
class _SecondaryAttributionLine extends StatelessWidget {
  const _SecondaryAttributionLine({
    required this.attribution,
    required this.currentPath,
  });

  final FeedSecondaryAttribution attribution;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final actor = attribution.actor;
    final adaptedProfile = FeedRouting.adaptProfileRoute(
      actor.profileRoute,
      currentPath: currentPath,
    );
    final tap = (adaptedProfile == null || adaptedProfile.isEmpty)
        ? null
        : () => context.push(adaptedProfile);
    final ctxLabel = actor.context?.label;
    final hasMeaningfulCtx =
        actor.context != null && actor.context!.isMeaningful;

    final nameText = actor.displayName.isNotEmpty
        ? actor.displayName
        : ((actor.handle ?? '').isNotEmpty
            ? '@${actor.handle}'
            : 'A member');

    // Compose: "Posted by Founder · M S Bajwa"
    //   * verb              — neutral "Posted by"
    //   * role + dot        — when role context is meaningful (e.g. "Founder · ")
    //   * accountable name  — bolder than verb but still muted
    final composed = StringBuffer(attribution.type.verb)
      ..write(' ');
    if (hasMeaningfulCtx && ctxLabel != null && ctxLabel.contains(' · ')) {
      // ctxLabel like "Founder · Aura Platform" — take the role half only.
      composed.write(ctxLabel.split(' · ').first);
      composed.write(' · ');
    } else if (hasMeaningfulCtx && ctxLabel != null && ctxLabel.isNotEmpty) {
      composed.write(ctxLabel);
      composed.write(' · ');
    }

    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(AuraRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              height: 1.4,
            ),
            children: [
              TextSpan(text: composed.toString()),
              TextSpan(
                text: nameText,
                style: AuraText.micro.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
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
///
/// Returns `null` when the item is missing the data needed to build a
/// stable target — defensive against any backend regression that fails to
/// populate `author.id` on an institution post. With `null`, the card hides
/// the interaction bar instead of rendering a button that would hit
/// `/v1/institutions//posts/.../reactions/state` and 404.
ReactionTarget? _reactionTargetFor(FeedItem item) {
  if (item.type == FeedItemType.institutionPost) {
    final instId = item.author.id.trim();
    if (instId.isEmpty) return null;
    return InstitutionPostReactionTarget(
      institutionId: instId,
      postId: item.id,
    );
  }
  if (item.id.trim().isEmpty) return null;
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
          child: _AvatarWithPresence(
            avatar: _Avatar(
              imageUrl: author.avatarOrLogoUrl,
              fallback: initial,
              isInstitution: author.isInstitution,
            ),
            presence: author.presence,
            avatarSize: 36,
          ),
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: InkWell(
            onTap: tap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        author.name.isNotEmpty
                            ? author.name
                            : (author.handleOrSlug.isNotEmpty
                                ? '@${author.handleOrSlug}'
                                : 'Unknown'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.small
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (author.context != null &&
                        author.context!.isMeaningful) ...[
                      const SizedBox(width: AuraSpace.s6),
                      Flexible(
                        child: AuraIdentityBadge(context: author.context!),
                      ),
                    ],
                  ],
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

/// Phase 6.2 — wraps any avatar with a small presence dot in the bottom-right
/// corner. No animation, no pulse, no tooltip. Rendered only for the three
/// "active" presence states; IDLE / unknown / null = no dot.
class _AvatarWithPresence extends StatelessWidget {
  const _AvatarWithPresence({
    required this.avatar,
    required this.avatarSize,
    this.presence,
  });

  final Widget avatar;
  final double avatarSize;
  final FeedPresence? presence;

  @override
  Widget build(BuildContext context) {
    final showDot = presence != null && presence!.state.hasDot;
    if (!showDot) return avatar;
    final dotSize = avatarSize <= 24 ? 6.0 : 8.0;
    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatar),
          Positioned(
            right: -1,
            bottom: -1,
            child: _PresenceDot(state: presence!.state, size: dotSize),
          ),
        ],
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.state, required this.size});

  final FeedPresenceState state;
  final double size;

  Color get _color {
    switch (state) {
      case FeedPresenceState.activeNow:
        return const Color(0xFF22C55E); // soft green
      case FeedPresenceState.recentlyActive:
        return const Color(0xFF60A5FA); // muted blue
      case FeedPresenceState.activeToday:
        return const Color(0xFF94A3B8); // gray
      case FeedPresenceState.idle:
      case FeedPresenceState.unknown:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color,
        // Hairline ring so the dot reads against any avatar background.
        border: Border.all(color: AuraSurface.card, width: 1.5),
      ),
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

/// Phase 6.2 — calm activity hint line above the reply-preview block.
/// "New reply" / "Recently replied" — single subtle line, no animation, no
/// counts, no color emphasis beyond the soft accent. Never reorders the
/// feed; just communicates that the conversation is fresh.
class _ActivityHintLine extends StatelessWidget {
  const _ActivityHintLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF22C55E),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AuraText.micro.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Subordinate preview block sitting between the post body and the
/// interaction bar. Shows up to two reply summaries plus an optional
/// "View discussion" link.
///
/// Phase 5.1 product principle: this is conversation depth, not feed
/// noise. The block is visually quieter than the parent post — same card
/// surface, indented avatars, smaller type, no like counts on individual
/// replies. Tapping any reply or the "View discussion" link opens the
/// post-detail screen via the parent's already-shell-adapted
/// `targetRoute`.
class _ReplyPreviewBlock extends StatelessWidget {
  const _ReplyPreviewBlock({
    required this.preview,
    required this.openTarget,
  });

  final FeedReplyPreview preview;
  final String openTarget;

  @override
  Widget build(BuildContext context) {
    final tap = openTarget.isEmpty
        ? null
        : () => context.push(openTarget);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s10,
        AuraSpace.s10,
        AuraSpace.s10,
        AuraSpace.s8,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < preview.items.length; i++) ...[
            _PreviewLine(item: preview.items[i], onTap: tap),
            if (i < preview.items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(height: 1, color: AuraSurface.divider),
              ),
          ],
          if (preview.hasMore && tap != null) ...[
            const SizedBox(height: AuraSpace.s8),
            InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View discussion',
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.accentText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: AuraSurface.accentText,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.item, required this.onTap});

  final FeedReplyPreviewItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = item.author.displayName.trim().isNotEmpty
        ? item.author.displayName.trim()[0].toUpperCase()
        : ((item.author.handle ?? '').isNotEmpty
            ? item.author.handle![0].toUpperCase()
            : '?');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarWithPresence(
              avatarSize: 22,
              presence: item.author.presence,
              avatar: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AuraSurface.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: (item.author.avatarUrl ?? '').isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.author.avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            initial,
                            style: AuraText.micro.copyWith(
                              color: AuraSurface.accentText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initial,
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.accentText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.ink,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: item.author.displayName.isNotEmpty
                          ? item.author.displayName
                          : ((item.author.handle ?? '').isNotEmpty
                              ? '@${item.author.handle}'
                              : 'Someone'),
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.ink,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    if (item.author.context != null &&
                        item.author.context!.isMeaningful) ...[
                      const WidgetSpan(child: SizedBox(width: 6)),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: AuraIdentityBadge(
                          context: item.author.context!,
                          mode: AuraIdentityBadgeMode.replyPreview,
                        ),
                      ),
                    ],
                    const TextSpan(text: '   '),
                    TextSpan(
                      text: item.body.replaceAll('\n', ' ').trim(),
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Muhammad reposted" / "You reposted" / "2 people you follow reposted".
///
/// Phase 4 product principle: this is a **label**, not a metric. We never
/// render counts or icons that imply popularity. When the signal carries
/// multiple actors, we name the first (most recent) and aggregate the rest
/// as "and N others" if there are more.
class _SignalLabel extends StatelessWidget {
  const _SignalLabel({required this.signal});

  final FeedSignal signal;

  String _label() {
    if (signal.actors.isEmpty) return '';
    final first = signal.actors.first;
    final firstName = first.isViewer
        ? 'You'
        : (first.displayName.trim().isNotEmpty
            ? first.displayName.trim()
            : (first.handle ?? '').trim().isNotEmpty
                ? first.type == FeedAuthorType.institution
                    ? '/${first.handle}'
                    : '@${first.handle}'
                : 'Someone');
    final verb = first.isViewer ? 'reposted' : 'reposted';
    final more = signal.actors.length - 1;
    if (more <= 0) return '$firstName $verb';
    if (more == 1) {
      final second = signal.actors[1];
      final secondName = second.isViewer
          ? 'you'
          : (second.displayName.trim().isNotEmpty
              ? second.displayName.trim()
              : (second.handle ?? '').trim().isNotEmpty
                  ? '@${second.handle}'
                  : 'someone');
      return '$firstName and $secondName $verb';
    }
    return '$firstName and $more others $verb';
  }

  @override
  Widget build(BuildContext context) {
    final text = _label();
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(
          Icons.repeat_rounded,
          size: 13,
          color: AuraSurface.faint,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
