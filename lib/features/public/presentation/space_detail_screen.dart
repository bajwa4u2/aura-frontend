import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../institutions/ui/institution_ds.dart';
import '../data/public_spaces_registry.dart';
import '../data/public_spaces_repository.dart';
import '../domain/space.dart';
import '../widgets/discourse_card.dart';

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
    // The compose screen does not yet accept a `bodyPrefill` query
    // param. Until it does, we route to the canonical `/compose` route
    // — the visibility selector is restricted to Social/Public per
    // Phase 1, so a "Social — [Space]" framing is the next step.
    context.push('/compose');
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
              InsModeHeader(
                title: space.name,
                description: space.description,
                primaryAction: AuraPrimaryButton(
                  label: 'Post in space',
                  icon: Icons.edit_rounded,
                  onPressed: () => _openCompose(context, space),
                ),
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
              else ...[
                const _SectionEyebrow(label: 'DISCUSSION'),
                const SizedBox(height: AuraSpace.s10),
                for (var i = 0; i < page.items.length; i++) ...[
                  DiscourseCard(
                    item: page.items[i],
                    spaceName: space.name,
                    spaceRoute: '/spaces/${space.slug}',
                  ),
                  if (i < page.items.length - 1)
                    const SizedBox(height: AuraSpace.s10),
                ],
              ],
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
                      'Mention ${space.composeTagPrefix} in your post so it appears here.',
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

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        fontSize: 10,
      ),
    );
  }
}
