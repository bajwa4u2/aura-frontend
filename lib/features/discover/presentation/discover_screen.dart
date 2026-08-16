import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// DISCOVER — AURA'S EXTENSIBLE DISCOVERY FRAMEWORK (founder-frozen,
/// C3 post-closeout correction, 2026-08-16).
///
/// Discover is not a page of links; it is the platform's discovery
/// framework, with search as the always-available mechanism and a
/// governed set of DISCOVERY DOMAINS as its structure. Immediate
/// domains: PEOPLE · INSTITUTIONS · SPACES · ARTICLES.
///
/// Framework rules (frozen):
///  * Each domain is a DISTINCT object universe — never merged, never
///    ranked against each other.
///  * A domain appears here only truthfully: a declared domain whose
///    experience does not exist yet says so honestly (no dead CTA, no
///    faking it with a different object type). Articles is currently
///    declared-not-available (Long-Form Publishing is a founder-owned
///    roadmap gap; Post ≠ Article ≠ Announcement is frozen).
///  * No fabricated personalization: a domain may only claim
///    "relevant to you" when a real signal produces that relevance.
///  * Discover DISCOVERS. It carries no onboarding, workspace, or
///    self-promotion affordances ("Add your institution" lives in the
///    global chrome action, never here).
///  * Verification is identity truth, never relevance ranking.
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
            'Find people, institutions, spaces, and conversations across Aura.',
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

/// The governed discovery-domain registry. Extending Discover means
/// adding an entry here. `route: null` = CANONICALLY DECLARED, NOT YET
/// AVAILABLE: the domain exists in the taxonomy and the registry, but it
/// is NOT rendered in the live experience — founder visibility ruling
/// (2026-08-16): "Do not fill the live Discover experience with a
/// prominent dead 'Coming soon' destination merely to prove the taxonomy
/// has four members." It becomes interactive the moment a truthful
/// route exists.
typedef DiscoveryDomain = ({
  IconData icon,
  String title,
  String body,
  String? route,
  String? unavailableNote,
});

const List<DiscoveryDomain> kDiscoveryDomains = [
  (
    icon: Icons.groups_outlined,
    title: 'People',
    // Honest scope: today People discovery IS search (always
    // available). Personalized discovery may only be added when a real
    // relevance signal exists — never fabricated, never a leaderboard.
    body: 'People suggested for you — search always available.',
    route: '/discover/people',
    unavailableNote: null,
  ),
  (
    icon: Icons.account_balance_outlined,
    title: 'Institutions',
    body: 'Discover institutions and their public participation.',
    route: '/institutions',
    unavailableNote: null,
  ),
  (
    icon: Icons.forum_outlined,
    title: 'Spaces',
    body: 'Shared subject contexts for continuing conversations.',
    route: '/spaces',
    unavailableNote: null,
  ),
  (
    icon: Icons.article_outlined,
    title: 'Articles',
    // The FOURTH domain, REAL as of 2026-08-16 (founder addendum): the
    // Article lifecycle (write → draft → publish → read) shipped; Post ≠
    // Article ≠ Announcement stays frozen.
    body: 'Substantial authored thought — durable long-form writing.',
    route: '/discover/articles',
    unavailableNote: null,
  ),
];

class _FacetGrid extends StatelessWidget {
  const _FacetGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        // Only domains with a truthful route render — declared-but-
        // unavailable domains (Articles) stay canonical in the registry
        // without occupying the live experience (founder ruling).
        final live =
            kDiscoveryDomains.where((f) => f.route != null).toList();
        final children = [
          for (final f in live)
            AuraCard(
              onTap: () => context.push(f.route!),
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
          // Domains read best two-up; a single wide row compresses each
          // card below comfortable reading width.
          const gap = AuraSpace.s12;
          final cardWidth = (c.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final child in children)
                SizedBox(width: cardWidth, child: child),
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
