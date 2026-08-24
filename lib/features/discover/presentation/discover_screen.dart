import '../../../core/navigation/navigation_authority.dart';
import '../widgets/person_suggestion_card.dart';
import '../data/people_discovery.dart';
import '../../institution_ontology/providers.dart';
import '../../institution_ontology/models.dart';
import '../../feed/presentation/unified_feed_card.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/product/product_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            'People, institutions, spaces and writing across Aura.',
            style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
          ),
          const SizedBox(height: AuraSpace.s16),
          // The search mechanism, embedded as Discover's primary affordance.
          const _DiscoverSearchEntry(),
          const SizedBox(height: AuraSpace.s20),
          // The four domain doors are PRESERVED - they remain the way into
          // each object universe - but they are no longer the whole surface.
          const _FacetGrid(),
          const SizedBox(height: AuraSpace.s24),
          const _PeopleStrip(),
          const _SectorStrip(),
          const _PublicActivitySection(),
        ],
      ),
    );
  }
}

/// A section heading with an optional way into the full domain.
class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AuraText.title),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            AuraSecondaryButton(label: actionLabel!, onPressed: onAction),
        ],
      ),
    );
  }
}

/// PEOPLE, ACTUALLY SHOWN.
///
/// The landing used to state that people were "suggested for you" and then
/// show none - the claim was the whole feature. This renders the same
/// canonical `/discover/people` projection the People domain screen reads,
/// through the same card, with the same real Follow control. Nothing is
/// ranked, scored or personalised here; the server decides who is
/// discoverable and this shows what it returned.
class _PeopleStrip extends ConsumerWidget {
  const _PeopleStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(peopleDiscoveryProvider);

    return page.when(
      // A landing section that cannot load is not worth a page-width spinner
      // or an error the reader cannot act on: the People door directly above
      // still works, so this section simply is not there.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.suggestions.isEmpty) return const SizedBox.shrink();
        final shown = data.suggestions.take(8).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHead(
              title: 'People',
              subtitle: data.coldStart
                  ? 'Active on Aura — a starting point while Aura learns what '
                      'matters to you'
                  : 'Suggested for you',
              actionLabel: 'See all',
              onAction: () => context.push(NavigationAuthority.discoverPeopleRoute),
            ),
            SizedBox(
              height: 216,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                children: [
                  for (final s in shown)
                    PersonSuggestionCard(suggestion: s, dense: true),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s24),
          ],
        );
      },
    );
  }
}

/// TOPICAL ENTRY WITHOUT RANKING.
///
/// The institution ontology is a fixed, public taxonomy - not a
/// recommendation. Surfacing it lets someone start from a subject they care
/// about rather than a name they already know, which is the thing Discover
/// could not previously do. Collapses whole when the taxonomy is unavailable;
/// the sector pages behind these are the existing ecosystem views.
class _SectorStrip extends ConsumerWidget {
  const _SectorStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ontology = ref.watch(institutionOntologyProvider);
    final classes = ontology.valueOrNull?.classes ?? const <InstitutionClassDef>[];
    if (classes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHead(
          title: 'Browse by sector',
          subtitle: 'Each sector opens the institutions working in it.',
        ),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            for (final c in classes)
              InkWell(
                onTap: () => context.push(NavigationAuthority.institutionSectorRoute(c.id)),
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s12,
                    vertical: AuraSpace.s8,
                  ),
                  decoration: BoxDecoration(
                    color: AuraSurface.card,
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: Text(
                    c.label,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s24),
      ],
    );
  }
}

/// WHAT IS ACTUALLY BEING SAID IN PUBLIC.
///
/// The one thing that lets a person discover something without first choosing
/// a directory or knowing what to search for. This is the existing
/// `/feed/public` projection - the same merged public feed the home surface
/// and the civic-signal derivations already read - in its own
/// reverse-chronological order. No ranking, no personalisation, no new
/// backend truth, and the card is the canonical single render path, so each
/// item keeps its own visibility badge and its own authority.
class _PublicActivitySection extends ConsumerWidget {
  const _PublicActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(globalPublicFeedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHead(
          title: 'Happening on Aura',
          subtitle: 'Public posts, most recent first.',
        ),
        feed.when(
          loading: () => const AuraProductState(state: ProductState.loading),
          error: (_, __) => AuraProductState(
            state: ProductState.retryableError,
            headline: 'Public activity could not be loaded',
            detail: 'Search and the domains above are still available.',
            onRecover: () => ref.invalidate(globalPublicFeedProvider),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return const AuraProductState(
                state: ProductState.empty,
                headline: 'Nothing public yet',
                detail: 'When people and institutions post publicly, '
                    'it appears here.',
              );
            }
            return Column(
              children: [
                for (final item in page.items.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                    child: UnifiedFeedCard(item: item),
                  ),
              ],
            );
          },
        ),
      ],
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
