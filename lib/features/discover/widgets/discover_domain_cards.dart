import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/aura_attachment_image.dart';
import '../../../core/interactions/follow_invalidation.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../conversation/presentation/conversation_identity.dart';
import '../../public/data/thread_space_follow_repository.dart';
import '../data/discover_repository.dart';

/// FOUR DOMAINS THAT MEAN DIFFERENT THINGS, PRESENTED DIFFERENTLY.
///
/// Founder ruling: do not force all four into one card template for
/// implementation symmetry. Shared primitives are good; identical product
/// treatment is not required.
///
/// So these share Aura's type scale, surfaces, spacing, trust marks and
/// temporal authority — and diverge in composition, because a Space is a place
/// you enter, an institution is a presence you trust, and an article is
/// something you read.
///
/// Every card offers the natural next action for its object, and only where
/// the viewer is authorised to take it. None of them invents a control.

/// The Space icon vocabulary, resolved from the governed `iconKey` the backend
/// stores. Unknown keys fall back to a neutral mark rather than an error glyph
/// — a new Space added server-side should look plain, never broken.
IconData spaceIcon(String iconKey) {
  switch (iconKey) {
    case 'account_balance_outlined':
      return Icons.account_balance_outlined;
    case 'eco_outlined':
      return Icons.eco_outlined;
    case 'memory_rounded':
      return Icons.memory_rounded;
    case 'school_outlined':
      return Icons.school_outlined;
    case 'local_hospital_outlined':
      return Icons.local_hospital_outlined;
    case 'place_outlined':
      return Icons.place_outlined;
    case 'trending_up_rounded':
      return Icons.trending_up_rounded;
    case 'science_outlined':
      return Icons.science_outlined;
    case 'palette_outlined':
      return Icons.palette_outlined;
    case 'gavel_rounded':
      return Icons.gavel_rounded;
    default:
      return Icons.forum_outlined;
  }
}

/// SPACES — participation contexts.
///
/// Wide and enterable, carrying live participation rather than a description
/// alone: a Space with people in it should look different from an empty one,
/// because it is. Counts are derived and zero is shown as absence rather than
/// as "0 participants", which reads like a defect.
class SpaceEnvironmentTile extends ConsumerStatefulWidget {
  const SpaceEnvironmentTile({super.key, required this.space});

  final DiscoveredSpace space;

  @override
  ConsumerState<SpaceEnvironmentTile> createState() =>
      _SpaceEnvironmentTileState();
}

class _SpaceEnvironmentTileState extends ConsumerState<SpaceEnvironmentTile> {
  bool? _following;
  bool _busy = false;

  Future<void> _toggleFollow() async {
    if (_busy) return;
    final next = !(_following ?? widget.space.viewerFollows);
    setState(() => _busy = true);
    try {
      final repo = ref.read(threadSpaceFollowRepositoryProvider);
      final ok = next
          ? await repo.followSpace(widget.space.slug)
          : await repo.unfollowSpace(widget.space.slug);
      if (!mounted) return;
      // The server's answer, not the optimistic guess.
      setState(() => _following = ok ? next : !next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That did not go through — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.space;
    final following = _following ?? s.viewerFollows;

    return InkWell(
      onTap: () => context.push(NavigationAuthority.spaceRoute(s.slug)),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.s16),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AuraSurface.accentSoft,
                    borderRadius: BorderRadius.circular(AuraRadius.r12),
                  ),
                  child: Icon(spaceIcon(s.iconKey),
                      size: 22, color: AuraSurface.accentText),
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.headline
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                AuraSecondaryButton(
                  label: _busy
                      ? '…'
                      : following
                          ? 'Following'
                          : 'Follow',
                  onPressed: _busy ? null : _toggleFollow,
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s10),
            Text(
              s.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AuraText.small
                  .copyWith(color: AuraSurface.muted, height: 1.4),
            ),
            if (s.hasActivity) ...[
              const SizedBox(height: AuraSpace.s12),
              Wrap(
                spacing: AuraSpace.s12,
                runSpacing: AuraSpace.s6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Stat(
                    icon: Icons.forum_outlined,
                    label: s.postCount == 1
                        ? '1 discussion'
                        : '${s.postCount} discussions',
                  ),
                  if (s.participantCount > 0)
                    _Stat(
                      icon: Icons.people_outline_rounded,
                      label: s.participantCount == 1
                          ? '1 participant'
                          : '${s.participantCount} participants',
                    ),
                  if (s.lastActivityAt != null)
                    _Stat(
                      icon: Icons.schedule_rounded,
                      label: AuraTemporal.humanize(
                        ProductTime(s.lastActivityAt!, TimeEvent.occurred),
                        style: TemporalStyle.compact,
                      ),
                    ),
                ],
              ),
            ],
            if (s.reason != null) ...[
              const SizedBox(height: AuraSpace.s8),
              _ReasonLine(s.reason!),
            ],
          ],
        ),
      ),
    );
  }
}

/// INSTITUTIONS — presences.
///
/// Calm and provenance-rich: identity, the verified mark where it is real,
/// where they operate, and how many people stand behind them. Deliberately
/// restrained density — institutional classification must not become Aura's
/// acquisition premise, so this reads as a presence rather than a directory
/// row.
class InstitutionPresenceCard extends ConsumerStatefulWidget {
  const InstitutionPresenceCard({super.key, required this.institution});

  final DiscoveredInstitution institution;

  @override
  ConsumerState<InstitutionPresenceCard> createState() =>
      _InstitutionPresenceCardState();
}

class _InstitutionPresenceCardState
    extends ConsumerState<InstitutionPresenceCard> {
  bool? _following;
  bool _busy = false;

  Future<void> _toggleFollow() async {
    if (_busy) return;
    final i = widget.institution;
    final next = !(_following ?? i.viewerFollows);
    setState(() => _busy = true);
    try {
      final viewerId = ref.read(myUserIdProvider);
      if (viewerId.isEmpty) return;
      // C1 — acting context is per-act. Following an institution from
      // Discover is a PERSONAL act: the viewer follows as themselves, never
      // on behalf of an institution they happen to speak for.
      final repo = ref.read(followsRepositoryProvider);
      final actor = ActorRef.user(viewerId);
      final target = ActorRef.institution(i.id);
      if (next) {
        await repo.follow(actor: actor, target: target);
      } else {
        await repo.unfollow(actor: actor, target: target);
      }
      if (!mounted) return;
      setState(() => _following = next);

      // Every surface that reads the follow graph re-reads: the pair cache and
      // the feeds whose composition changed the moment this edge existed.
      invalidateFollowSurfaces(
        ref,
        key: FollowStateKey(actor: actor, target: target),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That did not go through — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.institution;
    final following = _following ?? i.viewerFollows;
    final place = i.place;

    return InkWell(
      onTap: () => context.push(NavigationAuthority.institutionRoute(i.slug)),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AuraSpace.s16),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuraAvatar(name: i.name, imageUrl: i.logoUrl, size: 48),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              i.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AuraText.headline
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (i.verified) ...[
                            const SizedBox(width: AuraSpace.s4),
                            const Icon(Icons.verified_rounded,
                                size: 15, color: AuraSurface.accentText),
                          ],
                        ],
                      ),
                      if (i.tagline != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          i.tagline!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.small
                              .copyWith(color: AuraSurface.muted, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AuraSpace.s12,
                    runSpacing: AuraSpace.s6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (place != null)
                        _Stat(icon: Icons.place_outlined, label: place),
                      if (i.memberCount > 0)
                        _Stat(
                          icon: Icons.people_outline_rounded,
                          label: i.memberCount == 1
                              ? '1 member'
                              : '${i.memberCount} members',
                        ),
                    ],
                  ),
                ),
                AuraSecondaryButton(
                  label: _busy
                      ? '…'
                      : following
                          ? 'Following'
                          : 'Follow',
                  onPressed: _busy ? null : _toggleFollow,
                ),
              ],
            ),
            if (i.reason != null) ...[
              const SizedBox(height: AuraSpace.s8),
              _ReasonLine(i.reason!),
            ],
          ],
        ),
      ),
    );
  }
}

/// ARTICLES — knowledge.
///
/// Editorial: the cover leads where there is one, the title carries reading
/// weight, and the byline and reading time sit quietly under it. No
/// engagement chrome — an article is something to read, and a row of counters
/// would make this a feed card.
class ArticleEditorialCard extends StatelessWidget {
  const ArticleEditorialCard({super.key, required this.article});

  final DiscoveredArticle article;

  /// A FIXED EDITORIAL ROW HEIGHT, for two reasons. `stretch` needs a bounded
  /// height and this card renders inside unbounded-height columns, so without
  /// it the layout asserts. It also gives the Articles domain a consistent
  /// rhythm — a run of covers at one height reads as a reading list rather
  /// than as ragged cards.
  static const double _rowHeight = 104;

  @override
  Widget build(BuildContext context) {
    final a = article;
    final byline = <String>[
      if (a.authorName != null) a.authorName!,
      if (a.readingMinutes > 0) '${a.readingMinutes} min read',
    ].join('  ·  ');

    return InkWell(
      onTap: () =>
          context.push(NavigationAuthority.articleRoute(a.slug ?? a.id)),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        margin: const EdgeInsets.only(bottom: AuraSpace.s10),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: _rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (a.coverUrl != null)
                // THE GOVERNED IMAGE, AND A SLOT THAT COLLAPSES.
                //
                // This was a raw `Image.network` on the delivery URL, and it
                // could not fetch Aura media at all: media is RESTRICTED by
                // default and needs a freshly signed URL, so every cover
                // failed to `errorBuilder` and every card carried a blank
                // 108px panel down its left edge — the bar the founder saw in
                // Discover on 2026-09-04. Reserving width for a picture that
                // cannot load is worse than having no picture.
                //
                // `AuraAttachmentImage` is the canonical reader: it takes the
                // server's delivery URL and the media identity, and re-resolves
                // a signed URL when the address has expired. Sizing the IMAGE
                // rather than a wrapping box is what lets the failure case
                // shrink to nothing and give the width back to the words.
                AuraAttachmentImage(
                  url: a.coverUrl!,
                  attachmentId: a.coverMediaId,
                  width: 108,
                  fit: BoxFit.cover,
                  errorWidget: (_) => const SizedBox.shrink(),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AuraSpace.s14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.headline.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (byline.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s6),
                        Text(
                          byline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AuraText.micro.copyWith(color: AuraSurface.muted),
                        ),
                      ],
                      if (a.reason != null) ...[
                        const SizedBox(height: AuraSpace.s6),
                        _ReasonLine(a.reason!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AuraSurface.faint),
        const SizedBox(width: 4),
        Text(label, style: AuraText.micro.copyWith(color: AuraSurface.muted)),
      ],
    );
  }
}

/// Why this was surfaced, shown only when a signal had something worth saying.
/// The relevance authority returns no reason far more often than it returns
/// one, and a label mechanically attached to every object is noise.
class _ReasonLine extends StatelessWidget {
  const _ReasonLine(this.reason);
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome_outlined,
            size: 12, color: AuraSurface.faint),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuraText.micro.copyWith(color: AuraSurface.faint),
          ),
        ),
      ],
    );
  }
}
