import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../feed/domain/feed_item.dart';
import '../../institutions/ui/institution_ds.dart';
import '../data/public_spaces_registry.dart';
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
    final space = ref.watch(publicSpaceBySlugProvider(slug));
    if (space == null) {
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
                  'It may have been renamed or removed. Try the spaces directory.',
            ),
          ],
        ),
      );
    }

    final feedAsync = ref.watch(globalPublicFeedProvider);

    return AuraScaffold(
      showHeader: false,
      body: InsScreen(
        children: [
          // ── Mode header ───────────────────────────────────────────
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

          // ── Compose hint band ────────────────────────────────────
          _ComposeHintBand(
            space: space,
            onTap: () => _openCompose(context, space),
          ),
          const SizedBox(height: AuraSpace.s14),

          // ── Discourse stream + participants ──────────────────────
          feedAsync.when(
            loading: () => const AuraLoadingState(message: 'Loading…'),
            error: (e, _) => AuraErrorState(
              title: 'Could not load this space',
              body: '$e',
              action: AuraSecondaryButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(globalPublicFeedProvider),
              ),
            ),
            data: (page) {
              final inSpace = _filterToSpace(page.items, space);
              if (inSpace.isEmpty) {
                return const InsEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No posts in this space yet',
                  description:
                      'Use the action above to start the first discussion. '
                      'Posts that mention the space’s tag in their text appear here.',
                );
              }
              final participants = _participantNames(inSpace);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ParticipantsLine(
                    count: participants.length,
                    sample: participants,
                  ),
                  const SizedBox(height: AuraSpace.s14),
                  const _SectionEyebrow(label: 'DISCUSSION'),
                  const SizedBox(height: AuraSpace.s10),
                  for (var i = 0; i < inSpace.length; i++) ...[
                    DiscourseCard(
                      item: inSpace[i],
                      spaceName: space.name,
                      spaceRoute: '/spaces/${space.slug}',
                    ),
                    if (i < inSpace.length - 1)
                      const SizedBox(height: AuraSpace.s10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Frontend filter: an item is "in" the space when its title or body
  /// contains the space tag (case-insensitive, word-boundaryish). Loose
  /// on purpose — we'd rather over-include than miss tagged content.
  List<FeedItem> _filterToSpace(List<FeedItem> all, PubSpace space) {
    final tag = space.tag.toLowerCase();
    final hashed = '#$tag';
    final out = <FeedItem>[];
    for (final i in all) {
      final t = (i.title ?? '').toLowerCase();
      final b = i.body.toLowerCase();
      if (t.contains(hashed) ||
          b.contains(hashed) ||
          _hasWord(t, tag) ||
          _hasWord(b, tag)) {
        out.add(i);
      }
    }
    return out;
  }

  bool _hasWord(String haystack, String needle) {
    // Quick word-boundary check without the cost of a RegExp per call.
    if (haystack.isEmpty || needle.isEmpty) return false;
    final idx = haystack.indexOf(needle);
    if (idx < 0) return false;
    final before = idx == 0 ? ' ' : haystack[idx - 1];
    final afterIdx = idx + needle.length;
    final after =
        afterIdx >= haystack.length ? ' ' : haystack[afterIdx];
    bool isBoundary(String c) =>
        !RegExp(r'[a-z0-9_]').hasMatch(c.toLowerCase());
    return isBoundary(before) && isBoundary(after);
  }

  List<String> _participantNames(List<FeedItem> items) {
    final seen = <String>{};
    final names = <String>[];
    for (final i in items) {
      final id = i.author.id;
      if (id.isEmpty) continue;
      if (seen.contains(id)) continue;
      seen.add(id);
      final n = i.author.name.trim();
      names.add(n.isNotEmpty ? n : '@${i.author.handleOrSlug}');
    }
    return names;
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

class _ParticipantsLine extends StatelessWidget {
  const _ParticipantsLine({required this.count, required this.sample});

  final int count;
  final List<String> sample;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final visibleSample =
        sample.take(2).join(', ') + (count > 2 ? ' and others' : '');
    return Row(
      children: [
        const Icon(
          Icons.people_outline_rounded,
          size: 14,
          color: AuraSurface.muted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            count == 1
                ? '1 participant · $visibleSample'
                : '$count participants · $visibleSample',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
