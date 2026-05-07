import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/domain/feed_item.dart';
import '../../institutions/ui/institution_ds.dart';
import '../data/public_spaces_registry.dart';
import '../data/public_spaces_repository.dart';
import '../domain/space.dart';
import '../widgets/discourse_card.dart';
import '../widgets/follow_button.dart';

/// Space detail screen at `/spaces/:slug`.
///
/// Public-UX Phase 2: real space content. Today, since no backend
/// `/spaces/:id/feed` endpoint exists, the discourse stream is derived
/// client-side by tag-filtering the global public feed
/// (`globalPublicFeedProvider`). When a backend per-space feed lands,
/// only the data source changes — the layout and components stay.
///
/// What's real:
///   * Stable URL (`/spaces/civic`).
///   * Stable identity (slug + name + description from the registry).
///   * Discourse stream tagged to this space (frontend-filtered today).
///   * Composer that prefills the space tag so the next post will
///     appear inside this space without backend changes.
///   * Participants summary derived from the filtered feed (distinct
///     authors).
class SpaceDetailScreen extends ConsumerWidget {
  const SpaceDetailScreen({super.key, required this.slug});

  final String slug;

  void _openCompose(BuildContext context, PubSpace space) {
    // Public-UX Phase 4 — pass the space anchoring through query
    // params. The composer reads them, displays the "Posting in
    // [Name]" chip, and sends `publicSpaceId` on the draft so the
    // post lands inside the space without hashtag mentions.
    final qp = <String, String>{
      'publicSpaceId': space.id,
      'publicSpaceSlug': space.slug,
      'publicSpaceName': space.name,
    };
    final qs = qp.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    context.push('/compose?$qs');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 3 — primary source is the backend feed; the local registry
    // is only consulted as a fallback for the *header* (so signed-out
    // viewers without a network call still see space identity).
    final feedAsync = ref.watch(publicSpaceFeedProvider(slug));
    final summaryAsync = ref.watch(publicSpaceSummaryProvider(slug));
    final fallbackSpace = ref.watch(publicSpaceBySlugProvider(slug));

    return feedAsync.when(
      loading: () => AuraScaffold(
        showHeader: false,
        body: InsScreen(
          children: [
            InsModeHeader(
              title: fallbackSpace?.name ?? 'Loading space',
              description: fallbackSpace?.description ?? '',
            ),
            const InsModeHeaderGap(),
            const Center(child: AuraLoadingState(message: 'Loading…')),
          ],
        ),
      ),
      error: (e, _) {
        // 404 / missing migration — render a calm "no posts yet" using
        // the local registry's identity if available. This is the
        // explicit graceful-fallback path: real backend, real space,
        // empty stream until posts exist.
        if (fallbackSpace == null) {
          return AuraScaffold(
            showHeader: false,
            body: InsScreen(
              children: [
                InsModeHeader(
                  title: 'Space not found',
                  description: 'No space matches the slug "$slug".',
                  primaryAction: AuraSecondaryButton(
                    label: 'See all spaces',
                    icon: Icons.grid_view_rounded,
                    onPressed: () => context.go('/spaces'),
                  ),
                ),
                const InsModeHeaderGap(),
                const InsEmptyState(
                  icon: Icons.public_off_outlined,
                  title: 'Space unavailable',
                  description:
                      'It may have been renamed or removed. '
                      'Try the spaces directory.',
                ),
              ],
            ),
          );
        }
        return AuraScaffold(
          showHeader: false,
          body: InsScreen(
            children: [
              InsModeHeader(
                title: fallbackSpace.name,
                description: fallbackSpace.description,
                primaryAction: AuraPrimaryButton(
                  label: 'Post in space',
                  icon: Icons.edit_rounded,
                  onPressed: () => _openCompose(context, fallbackSpace),
                ),
              ),
              const InsModeHeaderGap(),
              _ComposeHintBand(
                space: fallbackSpace,
                onTap: () => _openCompose(context, fallbackSpace),
              ),
              const SizedBox(height: AuraSpace.s14),
              const InsEmptyState(
                icon: Icons.forum_outlined,
                title: 'No posts in this space yet',
                description:
                    'Use the action above to start the first discussion.',
              ),
            ],
          ),
        );
      },
      data: (page) {
        final space = page.space;
        return AuraScaffold(
          showHeader: false,
          body: InsScreen(
            children: [
              // ── Mode header ────────────────────────────────────
              // Public-UX Phase 6.1 — primary action is the Post CTA;
              // secondary action below it is the Follow toggle so the
              // header stays clean. We render the follow button as a
              // separate row immediately under the header instead of
              // overloading the mode-header trailing slot.
              InsModeHeader(
                title: space.name,
                description: space.description,
                primaryAction: AuraPrimaryButton(
                  label: 'Post in space',
                  icon: Icons.edit_rounded,
                  onPressed: () => _openCompose(context, space),
                ),
              ),
              const SizedBox(height: AuraSpace.s10),
              Align(
                alignment: Alignment.centerLeft,
                child: FollowButton.space(spaceSlug: space.slug),
              ),
              const InsModeHeaderGap(),

              // ── Identity panel — real counts from /summary ──────
              _SpaceIdentityPanel(slug: space.slug, summary: summaryAsync),
              const SizedBox(height: AuraSpace.s14),

              // ── Compose hint ────────────────────────────────────
              _ComposeHintBand(
                space: space,
                onTap: () => _openCompose(context, space),
              ),
              const SizedBox(height: AuraSpace.s14),

              // ── Discourse stream ────────────────────────────────
              if (page.items.isEmpty)
                const InsEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No posts in this space yet',
                  description:
                      'Use the action above to start the first discussion.',
                )
              else
                _SpaceStreamTabs(
                  space: space,
                  items: page.items,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Identity panel shown beneath the space mode header — backend-truth
/// counts of active discussions, participants, and institutions
/// involved. While the summary is loading or unavailable, render
/// nothing rather than fake numbers.
class _SpaceIdentityPanel extends StatelessWidget {
  const _SpaceIdentityPanel({required this.slug, required this.summary});

  final String slug;
  final AsyncValue<PublicSpaceSummary> summary;

  @override
  Widget build(BuildContext context) {
    return summary.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if (s.activeDiscussionCount == 0 &&
            s.participantCount == 0 &&
            s.institutionCount == 0) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: AuraSpace.s10,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.lg),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Wrap(
            spacing: AuraSpace.s14,
            runSpacing: AuraSpace.s8,
            children: [
              _CountChip(
                icon: Icons.forum_outlined,
                label: s.activeDiscussionCount == 1
                    ? '1 active discussion'
                    : '${s.activeDiscussionCount} active discussions',
              ),
              _CountChip(
                icon: Icons.people_outline_rounded,
                label: s.participantCount == 1
                    ? '1 participant'
                    : '${s.participantCount} participants',
              ),
              _CountChip(
                icon: Icons.apartment_rounded,
                label: s.institutionCount == 1
                    ? '1 institution involved'
                    : '${s.institutionCount} institutions involved',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AuraSurface.muted),
        const SizedBox(width: 5),
        Text(
          label,
          style: AuraText.small.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ComposeHintBand extends StatelessWidget {
  const _ComposeHintBand({required this.space, required this.onTap});

  final PubSpace space;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s14,
            vertical: AuraSpace.s12,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.lg),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  space.icon,
                  size: 16,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start a statement in ${space.name}',
                      style: AuraText.body.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your post will be anchored to this space — no hashtag needed.',
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.faint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AuraSurface.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Public-UX Phase 4 — three-tab discourse stream for space detail:
///   * **All** — every post in the space (backend order).
///   * **Top** — sorted by reply count desc (client-side reorder, no
///     extra fetch).
///   * **Outcomes** — only threads where institutions have responded
///     and the activity hint suggests the discussion is concluded.
///     Today this is heuristic (institution involved + recent reply
///     true). Once the reply preview surfaces accountabilityTag, this
///     filter will tighten to "has at least one RESOLVED reply".
class _SpaceStreamTabs extends StatefulWidget {
  const _SpaceStreamTabs({required this.space, required this.items});

  final dynamic space; // PubSpace; loose to avoid extra import
  final List items;

  @override
  State<_SpaceStreamTabs> createState() => _SpaceStreamTabsState();
}

enum _StreamTab { all, top, outcomes }

class _SpaceStreamTabsState extends State<_SpaceStreamTabs> {
  _StreamTab _tab = _StreamTab.all;

  @override
  Widget build(BuildContext context) {
    final list = _filtered();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AuraSpace.s8,
          children: [
            _TabChip(
              label: 'All',
              selected: _tab == _StreamTab.all,
              onTap: () => setState(() => _tab = _StreamTab.all),
            ),
            _TabChip(
              label: 'Top',
              selected: _tab == _StreamTab.top,
              onTap: () => setState(() => _tab = _StreamTab.top),
            ),
            _TabChip(
              label: 'Outcomes',
              selected: _tab == _StreamTab.outcomes,
              onTap: () => setState(() => _tab = _StreamTab.outcomes),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s14),
        if (list.isEmpty)
          const InsEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Nothing here yet',
            description:
                'Try a different tab — or be the first to post in this space.',
          )
        else
          for (var i = 0; i < list.length; i++) ...[
            DiscourseCard(
              item: list[i],
              spaceName: (widget.space as dynamic).name as String,
              spaceRoute:
                  '/spaces/${(widget.space as dynamic).slug as String}',
            ),
            if (i < list.length - 1) const SizedBox(height: AuraSpace.s10),
          ],
      ],
    );
  }

  List _filtered() {
    final raw = widget.items;
    switch (_tab) {
      case _StreamTab.all:
        return raw;
      case _StreamTab.top:
        // Sort by reply count desc; preserve backend order for ties.
        final indexed = <MapEntry<int, dynamic>>[];
        for (var i = 0; i < raw.length; i++) {
          indexed.add(MapEntry(i, raw[i]));
        }
        indexed.sort((a, b) {
          final ar = (a.value as dynamic).interaction.canViewReplyCount
              ? (a.value as dynamic).interaction.replyCount as int
              : 0;
          final br = (b.value as dynamic).interaction.canViewReplyCount
              ? (b.value as dynamic).interaction.replyCount as int
              : 0;
          if (ar != br) return br.compareTo(ar);
          return a.key.compareTo(b.key);
        });
        return indexed.map((e) => e.value).toList(growable: false);
      case _StreamTab.outcomes:
        // Heuristic: an "outcome" thread is one where institutions
        // have responded AND the activity hint suggests it's settled
        // (has replies, not actively churning). When the backend
        // surfaces the RESOLVED tag on reply previews, tighten this.
        return raw.where((item) {
          final preview = (item as dynamic).replyPreview;
          if (preview == null) return false;
          final hasInstitutional = (preview.items as List).any((r) =>
              (r as dynamic).author?.context?.type ==
              FeedIdentityContextType.officialInstitution);
          final replyCount =
              (item as dynamic).interaction.canViewReplyCount
                  ? (item as dynamic).interaction.replyCount as int
                  : 0;
          return hasInstitutional && replyCount >= 2;
        }).toList(growable: false);
    }
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.accentSoft : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected
                ? AuraSurface.accent.withValues(alpha: 0.4)
                : AuraSurface.divider,
          ),
        ),
        child: Text(
          label,
          style: AuraText.small.copyWith(
            color: selected ? AuraSurface.accentText : AuraSurface.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
