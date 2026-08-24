import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/identity/person_identity_model.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/trust/trust_marks.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../search/search_repository.dart';
import '../data/discover_repository.dart';
import '../data/people_discovery.dart';
import '../widgets/discover_domain_cards.dart';
import '../widgets/person_suggestion_card.dart';
import 'discover_search.dart';

/// DISCOVER — AURA'S LIVE, CURATED, ACTIONABLE DISCOVERY DASHBOARD.
///
/// Founder ruling, 2026-08-24. It expands a person's horizon beyond what they
/// already know or follow. It is not another Home, not a public feed, not a
/// directory, not a taxonomy wall, and not four large buttons.
///
/// FOUR DOMAINS AND NOTHING ELSE: People, Spaces, Institutions, Articles. Each
/// arrives already ordered by the relevance authority and already filtered by
/// the eligibility authority, and each is presented as the kind of thing it
/// actually is rather than as a row in a shared template.
///
/// PUBLIC-FIRST CAUSAL ORDER. People come first because people and purposeful
/// public participation are the originating context; then the Spaces they take
/// part in; then institutions; then the durable knowledge layer. Institutions
/// stay first-class and deliberately restrained — institutional taxonomy is
/// not Aura's acquisition premise, and the 24-sector ontology lives inside
/// Institution discovery rather than on this landing.
///
/// SEARCH IS PART OF THIS SURFACE. With no query it is the dashboard; with a
/// query it becomes cross-domain discovery in place. Nothing navigates away to
/// a separate search screen, and returning from a result restores the query,
/// the narrowing and the scroll.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key, this.autofocusSearch = false});

  /// True when arrived at through the search address, so the field takes focus
  /// and the person can simply type.
  final bool autofocusSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searching = ref.watch(discoverIsSearchingProvider);

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        // Restores where the reader was when they come back from an object.
        key: const PageStorageKey('discover'),
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          const SizedBox(height: AuraSpace.s8),
          const Text('Discover', style: AuraText.display),
          const SizedBox(height: AuraSpace.s6),
          Text(
            'People, spaces, institutions and writing beyond what you already follow.',
            style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
          ),
          const SizedBox(height: AuraSpace.s16),
          DiscoverSearchField(autofocus: autofocusSearch),
          const SizedBox(height: AuraSpace.s20),
          if (searching)
            const _SearchResults()
          else
            const _CuratedDashboard(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THE CURATED DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

/// Composed rather than stacked.
///
/// On a wide viewport the domains form an asymmetric layout: participation
/// contexts take the larger column while institutions and knowledge sit
/// beside them. On a narrow one they stack in the same causal order. This is
/// deliberately not four identical carousels, and deliberately not the same
/// layout scaled down.
class _CuratedDashboard extends StatelessWidget {
  const _CuratedDashboard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;

        // People lead at every width — identity is the originating context,
        // and a horizontal run of faces reads as people rather than as rows.
        const people = _PeopleSection();

        if (!wide) {
          return const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              people,
              _SpacesSection(),
              _InstitutionsSection(),
              _ArticlesSection(),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            people,
            // Unbounded height: this Row sits inside a ListView, so every
            // Column beneath it sizes to its content rather than trying to
            // fill an infinite box.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(flex: 3, child: _SpacesSection()),
                SizedBox(width: AuraSpace.s20),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InstitutionsSection(),
                      _ArticlesSection(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A section heading and the way deeper into that domain.
class _DomainHeader extends StatelessWidget {
  const _DomainHeader({
    required this.title,
    required this.subtitle,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final VoidCallback onOpen;

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
                Text(subtitle,
                    style: AuraText.small.copyWith(color: AuraSurface.muted)),
              ],
            ),
          ),
          AuraSecondaryButton(label: 'Explore', onPressed: onOpen),
        ],
      ),
    );
  }
}

/// A domain that cannot be filled says nothing at all. Founder ruling: a
/// section may disappear rather than render an empty promise.
class _DomainSection extends StatelessWidget {
  const _DomainSection({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AuraSpace.s24),
        child: child,
      );
}

/// Domain-shaped loading. A skeleton the size of what is coming, not a spinner
/// in the middle of the page.
class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height, this.count = 1});
  final double height;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            height: height,
            margin: const EdgeInsets.only(bottom: AuraSpace.s10),
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.card),
            ),
          ),
      ],
    );
  }
}

class _PeopleSection extends ConsumerWidget {
  const _PeopleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(peopleDiscoveryProvider);

    return page.when(
      loading: () => const _DomainSection(child: _Skeleton(height: 216)),
      // The domain door in the header still works, so a failed section is
      // absent rather than an error the reader cannot act on.
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.suggestions.isEmpty) return const SizedBox.shrink();
        return _DomainSection(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DomainHeader(
                title: 'People',
                subtitle: data.coldStart
                    ? 'Active on Aura — a starting point while Aura learns '
                        'what matters to you'
                    : 'Suggested from who and what you already follow',
                onOpen: () =>
                    context.push(NavigationAuthority.discoverPeopleRoute),
              ),
              SizedBox(
                height: 216,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final s in data.suggestions.take(8))
                      PersonSuggestionCard(suggestion: s, dense: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpacesSection extends ConsumerWidget {
  const _SpacesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(discoverSpacesPreviewProvider);

    return page.when(
      loading: () =>
          const _DomainSection(child: _Skeleton(height: 132, count: 2)),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return _DomainSection(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DomainHeader(
                title: 'Spaces',
                subtitle: 'Public contexts you can take part in',
                onOpen: () => context.push(NavigationAuthority.spacesRoute),
              ),
              for (final s in data.items) ...[
                SpaceEnvironmentTile(space: s),
                const SizedBox(height: AuraSpace.s10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InstitutionsSection extends ConsumerWidget {
  const _InstitutionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(discoverInstitutionsPreviewProvider);

    return page.when(
      loading: () =>
          const _DomainSection(child: _Skeleton(height: 140, count: 2)),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return _DomainSection(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DomainHeader(
                title: 'Institutions',
                subtitle: 'Presences participating in public',
                onOpen: () => context
                    .push(NavigationAuthority.discoverInstitutionsRoute),
              ),
              for (final i in data.items) ...[
                InstitutionPresenceCard(institution: i),
                const SizedBox(height: AuraSpace.s10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ArticlesSection extends ConsumerWidget {
  const _ArticlesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(discoverArticlesPreviewProvider);

    return page.when(
      loading: () =>
          const _DomainSection(child: _Skeleton(height: 96, count: 3)),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return _DomainSection(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DomainHeader(
                title: 'Articles',
                subtitle: 'Durable, authored writing',
                onOpen: () =>
                    context.push(NavigationAuthority.discoverArticlesRoute),
              ),
              for (final a in data.items) ArticleEditorialCard(article: a),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH RESULTS — the same surface, answering a query
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  const _SearchResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(discoverQueryProvider).trim();
    final result = ref.watch(discoverSearchResultProvider);
    final narrowed = ref.watch(discoverNarrowedDomainProvider);

    return result.when(
      // Results stay on screen while the next request is in flight, so typing
      // does not flash the surface back to a spinner on every keystroke.
      loading: () => const _Skeleton(height: 84, count: 4),
      error: (_, __) => AuraProductState(
        state: ProductState.retryableError,
        headline: 'Search could not be reached',
        onRecover: () => ref.invalidate(discoverSearchResultProvider),
      ),
      data: (data) {
        if (data.isEmpty) {
          return AuraProductState(
            state: ProductState.empty,
            headline: 'Nothing matched "$query"',
            detail: 'Try a different name, handle, subject or title — or '
                'explore a domain below.',
            action: AuraSecondaryButton(
              label: ProductLabels.of(ProductAction.retry),
              onPressed: () => ref.invalidate(discoverSearchResultProvider),
              icon: Icons.refresh_rounded,
            ),
          );
        }

        final domains = narrowed != null
            ? [narrowed]
            : data.answeringDomains;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DiscoverDomainChips(result: data),
            const SizedBox(height: AuraSpace.s20),
            for (final domain in domains) ...[
              _ResultGroup(domain: domain, rows: data.forDomain(domain)),
              const SizedBox(height: AuraSpace.s20),
            ],
          ],
        );
      },
    );
  }
}

/// One domain's results, in that domain's own presentation.
class _ResultGroup extends StatelessWidget {
  const _ResultGroup({required this.domain, required this.rows});

  final SearchDomain domain;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s10),
          child: Text(domain.label, style: AuraText.title),
        ),
        switch (domain) {
          SearchDomain.people => Column(
              children: [for (final r in rows) _PersonResultTile(row: r)],
            ),
          SearchDomain.spaces => Column(
              children: [
                for (final r in rows) ...[
                  SpaceEnvironmentTile(space: _spaceFrom(r)),
                  const SizedBox(height: AuraSpace.s10),
                ],
              ],
            ),
          SearchDomain.institutions => Column(
              children: [
                for (final r in rows) ...[
                  InstitutionPresenceCard(institution: _institutionFrom(r)),
                  const SizedBox(height: AuraSpace.s10),
                ],
              ],
            ),
          SearchDomain.articles => Column(
              children: [
                for (final r in rows)
                  ArticleEditorialCard(article: _articleFrom(r)),
              ],
            ),
        },
      ],
    );
  }
}

/// Search returns the object, not a recommendation, so the discovery-only
/// fields are absent rather than guessed: no relevance reason, and follow
/// state the card resolves for itself when the person acts.
DiscoveredSpace _spaceFrom(Map<String, dynamic> r) => DiscoveredSpace(
      id: (r['id'] ?? '').toString(),
      slug: (r['slug'] ?? '').toString(),
      name: (r['name'] ?? '').toString(),
      description: (r['description'] ?? '').toString(),
      iconKey: (r['iconKey'] ?? '').toString(),
      participantCount: 0,
      postCount: 0,
      lastActivityAt: null,
      viewerFollows: false,
      reason: null,
    );

DiscoveredInstitution _institutionFrom(Map<String, dynamic> r) =>
    DiscoveredInstitution(
      id: (r['id'] ?? '').toString(),
      slug: (r['slug'] ?? '').toString(),
      name: (r['name'] ?? '').toString(),
      tagline: _ns(r['tagline']),
      description: _ns(r['description']),
      logoUrl: _ns(r['logoUrl']),
      city: _ns(r['city']),
      country: _ns(r['country']),
      institutionClass: _ns(r['institutionClass']),
      domainTags: const [],
      verified: r['verified'] == true || r['status'] == 'VERIFIED',
      memberCount: 0,
      viewerFollows: false,
      reason: null,
    );

DiscoveredArticle _articleFrom(Map<String, dynamic> r) {
  final author = r['author'] is Map
      ? Map<String, dynamic>.from(r['author'] as Map)
      : const <String, dynamic>{};
  return DiscoveredArticle(
    id: (r['id'] ?? '').toString(),
    slug: _ns(r['slug']),
    title: (r['title'] ?? '').toString(),
    coverMediaId: _ns(r['coverMediaId']),
    coverUrl: _ns(r['coverUrl']),
    publishedAt: DateTime.tryParse((r['publishedAt'] ?? '').toString()),
    readingMinutes: 0,
    authorName: _ns(author['displayName']),
    authorHandle: _ns(author['handle']),
    authorAvatarUrl: _ns(author['avatarUrl']),
    reason: null,
  );
}

/// A person in results. Identity comes through the canonical reader, so a
/// person found by searching looks like the same person everywhere else.
class _PersonResultTile extends StatelessWidget {
  const _PersonResultTile({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final person = AuraPersonIdentity.fromJson(row);
    final handle = person.handle;

    return InkWell(
      onTap: handle.isEmpty
          ? null
          : () => context.push(NavigationAuthority.personRoute(handle)),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: Container(
        margin: const EdgeInsets.only(bottom: AuraSpace.s8),
        padding: const EdgeInsets.all(AuraSpace.s12),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          children: [
            AuraAvatar(
              name: person.label,
              imageUrl: person.avatarUrl,
              size: 40,
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          person.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.body
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (person.verification.hasAny) ...[
                        const SizedBox(width: AuraSpace.s4),
                        PersonVerificationMarks(
                          verification: person.verification,
                          size: TrustMarkSize.micro,
                        ),
                      ],
                    ],
                  ),
                  if (handle.isNotEmpty)
                    Text('@$handle',
                        style:
                            AuraText.micro.copyWith(color: AuraSurface.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _ns(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}
