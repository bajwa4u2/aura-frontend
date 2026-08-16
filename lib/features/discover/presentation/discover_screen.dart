import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// C3 — DISCOVER: the canonical consolidated intention
/// "find something or someone relevant" (founder-frozen).
///
/// Search is the MECHANISM and lives here as the primary affordance;
/// People / Institutions / Spaces remain DISTINCT objects, reachable as
/// truthful facets. This surface consolidates the previously fragmented
/// entry points (`/search`, the institutions directory, spaces
/// discovery) into one destination intention — it does not merge those
/// objects, invent ranking, or become an institution-first directory.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          const SizedBox(height: AuraSpace.s8),
          const Text('Discover', style: AuraText.display),
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Find people, institutions, spaces, and conversations that matter to you.',
            style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
          ),
          const SizedBox(height: AuraSpace.s16),
          // The search mechanism, embedded as Discover's primary affordance.
          const _DiscoverSearchEntry(),
          const SizedBox(height: AuraSpace.s20),
          const _FacetGrid(),
        ],
      ),
    );
  }
}

class _DiscoverSearchEntry extends StatelessWidget {
  const _DiscoverSearchEntry();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/search'),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s14,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AuraSurface.muted),
            const SizedBox(width: AuraSpace.s10),
            Text(
              'Search people, institutions, or conversations…',
              style: AuraText.body.copyWith(color: AuraSurface.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacetGrid extends StatelessWidget {
  const _FacetGrid();

  @override
  Widget build(BuildContext context) {
    const facets = [
      (
        icon: Icons.groups_outlined,
        title: 'People',
        body: 'Find people to follow and talk with.',
        route: '/search',
      ),
      (
        icon: Icons.account_balance_outlined,
        title: 'Institutions',
        body: 'Organizations participating on Aura, on the record.',
        route: '/institutions',
      ),
      (
        icon: Icons.forum_outlined,
        title: 'Spaces',
        body: 'Shared contexts for continuing conversations.',
        route: '/spaces',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        final children = [
          for (final f in facets)
            AuraCard(
              onTap: () => context.push(f.route),
              child: Row(
                children: [
                  Icon(f.icon, size: 28, color: AuraSurface.accentText),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.title,
                            style: AuraText.headline
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          f.body,
                          style: AuraText.small
                              .copyWith(color: AuraSurface.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AuraSurface.faint),
                ],
              ),
            ),
        ];
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i != children.length - 1)
                  const SizedBox(width: AuraSpace.s12),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (final child in children) ...[
              child,
              const SizedBox(height: AuraSpace.s10),
            ],
          ],
        );
      },
    );
  }
}
