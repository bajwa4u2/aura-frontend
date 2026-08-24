import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/identity/person_identity_model.dart';
import 'package:aura/features/discover/data/discover_repository.dart';
import 'package:aura/features/discover/data/people_discovery.dart';
import 'package:aura/features/discover/presentation/discover_screen.dart';
import 'package:aura/features/discover/presentation/discover_search.dart';
import 'package:aura/features/public/data/public_spaces_registry.dart';
import 'package:aura/features/search/providers.dart';
import 'package:aura/features/search/search_repository.dart';

/// DISCOVER — AURA'S LIVE, CURATED, ACTIONABLE DISCOVERY DASHBOARD.
///
/// Founder ruling 2026-08-24 replaced the previous composition. The landing is
/// no longer four large domain doors over a search box that navigated away; it
/// is four live domains, each presented as the kind of object it holds, with a
/// search experience that operates in place.
///
/// These pin the parts of that ruling a future change could quietly undo:
///
///   * exactly four domains, and Posts is not one of them;
///   * a domain that cannot be filled disappears rather than promising;
///   * search is part of this surface, not a redirect to another one;
///   * narrowing keeps the query, and clearing restores the dashboard;
///   * the sector taxonomy does not live on the landing;
///   * Discover DISCOVERS — no onboarding or workspace affordances.
void main() {
  // ── Harness ───────────────────────────────────────────────────────────────
  //
  // Every domain reads a governed projection. They are overridden rather than
  // left to reach the network: a widget test that fetches is not
  // deterministic, and its pending timers fail the suite for reasons unrelated
  // to the assertion.

  PersonSuggestion person(String name, String handle) => PersonSuggestion(
        person: AuraPersonIdentity.fromJson({
          'id': handle,
          'displayName': name,
          'handle': handle,
        }),
        reasons: const ['Followed by someone you follow'],
        followState: 'NONE',
      );

  DiscoveredSpace space(String slug, String name) => DiscoveredSpace(
        id: 'pubsp_$slug',
        slug: slug,
        name: name,
        description: 'A public context.',
        iconKey: 'account_balance_outlined',
        participantCount: 3,
        postCount: 7,
        lastActivityAt: DateTime.utc(2026, 8, 20),
        viewerFollows: false,
        reason: null,
      );

  DiscoveredInstitution institution(String slug, String name) =>
      DiscoveredInstitution(
        id: slug,
        slug: slug,
        name: name,
        tagline: 'An institutional presence.',
        description: null,
        logoUrl: null,
        city: 'Taylor',
        country: 'United States',
        institutionClass: null,
        domainTags: const [],
        verified: true,
        memberCount: 5,
        viewerFollows: false,
        reason: null,
      );

  DiscoveredArticle article(String id, String title) => DiscoveredArticle(
        id: id,
        slug: id,
        title: title,
        coverMediaId: null,
        coverUrl: null,
        publishedAt: DateTime.utc(2026, 8, 1),
        readingMinutes: 4,
        authorName: 'A Person',
        authorHandle: 'aperson',
        authorAvatarUrl: null,
        reason: null,
      );

  Widget harness({
    List<PersonSuggestion> people = const [],
    List<DiscoveredSpace> spaces = const [],
    List<DiscoveredInstitution> institutions = const [],
    List<DiscoveredArticle> articles = const [],
    SearchResult? searchResult,
  }) {
    return ProviderScope(
      overrides: [
        peopleDiscoveryProvider.overrideWith(
          (ref) async =>
              PeopleDiscoveryPage(suggestions: people, coldStart: false),
        ),
        discoverSpacesPreviewProvider.overrideWith(
          (ref) async => DiscoverPage(items: spaces, total: spaces.length),
        ),
        discoverInstitutionsPreviewProvider.overrideWith(
          (ref) async =>
              DiscoverPage(items: institutions, total: institutions.length),
        ),
        discoverArticlesPreviewProvider.overrideWith(
          (ref) async => DiscoverPage(items: articles, total: articles.length),
        ),
        if (searchResult != null)
          discoverSearchResultProvider.overrideWith((ref) async => searchResult),
      ],
      child: const MaterialApp(home: Material(child: DiscoverScreen())),
    );
  }

  Future<void> tall(WidgetTester tester) async {
    // The ListView builds lazily; a short viewport would simply not construct
    // the lower domains and the assertions would measure the fold.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 4000);
    addTearDown(tester.view.reset);
  }

  group('the landing holds four live domains', () {
    testWidgets('each domain renders its own objects', (tester) async {
      await tall(tester);
      await tester.pumpWidget(harness(
        people: [person('A Person', 'aperson')],
        spaces: [space('civic', 'Civic')],
        institutions: [institution('aura-platform-llc', 'Aura Platform')],
        articles: [article('a1', 'What We Build')],
      ));
      await tester.pumpAndSettle();

      for (final heading in ['People', 'Spaces', 'Institutions', 'Articles']) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      // Real objects, not just headings.
      expect(find.text('A Person'), findsOneWidget);
      expect(find.text('Civic'), findsOneWidget);
      expect(find.text('Aura Platform'), findsOneWidget);
      expect(find.text('What We Build'), findsOneWidget);
    });

    testWidgets('objects carry their natural action', (tester) async {
      await tall(tester);
      await tester.pumpWidget(harness(
        people: [person('A Person', 'aperson')],
        spaces: [space('civic', 'Civic')],
        institutions: [institution('aura-platform-llc', 'Aura Platform')],
      ));
      await tester.pumpAndSettle();

      // Follow on the person, the Space and the institution — the dashboard is
      // somewhere to act, not only to look.
      expect(find.text('Follow'), findsNWidgets(3));
      // And a way deeper into each domain.
      expect(find.text('Explore'), findsNWidgets(3));
    });

    testWidgets('a domain with nothing to show disappears', (tester) async {
      // Founder ruling: a section may disappear rather than render an empty
      // promise. The previous composition announced "People suggested for you"
      // and showed none.
      await tall(tester);
      await tester.pumpWidget(harness(spaces: [space('civic', 'Civic')]));
      await tester.pumpAndSettle();

      expect(find.text('Spaces'), findsOneWidget);
      expect(find.text('People'), findsNothing);
      expect(find.text('Institutions'), findsNothing);
      expect(find.text('Articles'), findsNothing);
    });

    testWidgets('the sector taxonomy does not live on the landing',
        (tester) async {
      // It belongs inside Institution discovery. A wall of institutional
      // classification must not be Aura's acquisition premise — and with no
      // institution classified, every sector leads nowhere.
      await tall(tester);
      await tester.pumpWidget(harness(
        institutions: [institution('aura-platform-llc', 'Aura Platform')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Browse by sector'), findsNothing);
    });

    testWidgets('Home keeps ongoing discourse — Discover does not', (tester) async {
      await tall(tester);
      await tester.pumpWidget(harness(spaces: [space('civic', 'Civic')]));
      await tester.pumpAndSettle();

      expect(find.text('Happening on Aura'), findsNothing);
    });
  });

  group('search operates inside Discover', () {
    testWidgets('the dashboard yields to grouped results and comes back',
        (tester) async {
      await tall(tester);
      final container = ProviderContainer(overrides: [
        peopleDiscoveryProvider.overrideWith(
          (ref) async => PeopleDiscoveryPage(
              suggestions: [person('A Person', 'aperson')], coldStart: false),
        ),
        discoverSpacesPreviewProvider.overrideWith(
          (ref) async => const DiscoverPage(items: [], total: 0),
        ),
        discoverInstitutionsPreviewProvider.overrideWith(
          (ref) async => const DiscoverPage(items: [], total: 0),
        ),
        discoverArticlesPreviewProvider.overrideWith(
          (ref) async => const DiscoverPage(items: [], total: 0),
        ),
        discoverSearchResultProvider.overrideWith(
          (ref) async => const SearchResult(
            people: [
              {'id': 'u1', 'displayName': 'Found Person', 'handle': 'found'}
            ],
            institutions: [],
            spaces: [],
            articles: [],
          ),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Material(child: DiscoverScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A Person'), findsOneWidget); // dashboard

      container.read(discoverQueryProvider.notifier).state = 'found';
      await tester.pumpAndSettle();

      expect(find.text('Found Person'), findsOneWidget); // results
      expect(find.text('A Person'), findsNothing); // dashboard yielded

      // Clearing restores the curated dashboard.
      container.read(discoverQueryProvider.notifier).state = '';
      await tester.pumpAndSettle();
      expect(find.text('A Person'), findsOneWidget);
    });

    test('a one-character query is not a query', () {
      // Single letters match almost everything; the dashboard is the better
      // answer until there is enough to go on.
      expect(kMinQueryLength, greaterThanOrEqualTo(2));
    });

    test('Posts is not a Discover domain', () {
      // The backend search returns posts. Surfacing them here would put the
      // feed back inside Discover through the search box.
      expect(SearchDomain.values.map((d) => d.label).toList(),
          ['People', 'Spaces', 'Institutions', 'Articles']);
      final source =
          File('lib/features/search/search_repository.dart').readAsStringSync();
      expect(source.contains("listOf('posts')"), isFalse);
    });

    test('search reads the canonical authority, not a second backend', () {
      final source =
          File('lib/features/search/search_repository.dart').readAsStringSync();
      expect(source, contains("'/search'"));
      // No parallel discovery-only search endpoint.
      expect(source.contains('/discover/search'), isFalse);
    });

    test('the retired search screen is gone, and its address still works', () {
      expect(
        File('lib/features/search/presentation/search_screen.dart').existsSync(),
        isFalse,
        reason: 'the legacy search product is retired, not merely bypassed',
      );
      final router = File('lib/router.dart').readAsStringSync();
      expect(router, contains("path: '/search'"));
      expect(router, contains('_DiscoverSearchEntryPoint'));
    });

    test('search state survives navigation by living outside the widget', () {
      // Query and narrowing must be restored when a person opens an object and
      // comes back. autoDispose would drop both the moment the surface is
      // covered.
      final source =
          File('lib/features/discover/presentation/discover_search.dart')
              .readAsStringSync();
      expect(source.contains('StateProvider.autoDispose'), isFalse);
      expect(source, contains('discoverQueryProvider'));
      expect(source, contains('discoverNarrowedDomainProvider'));
    });
  });

  group('Discover DISCOVERS — no onboarding/workspace tenancy (source pins)',
      () {
    test('discovery surfaces carry no onboarding or workspace affordances',
        () {
      const files = [
        'lib/features/discover/presentation/discover_screen.dart',
        'lib/features/public/presentation/public_institutions_directory_screen.dart',
        'lib/features/public/presentation/institution_sector_screen.dart',
        'lib/features/public/presentation/spaces_discovery_screen.dart',
      ];
      for (final path in files) {
        final src = File(path).readAsStringSync();
        expect(src.contains('/institutions/get-started'), isFalse,
            reason: '$path re-grew an onboarding affordance — institution '
                'onboarding is the GLOBAL chrome action, never a Discover '
                'tenant.');
        expect(src.contains('/institution/dashboard'), isFalse,
            reason: '$path re-grew a workspace affordance — workspace entry '
                'is not a discovery concern.');
      }
    });

    test('verification is never a ranking cohort in directory rendering', () {
      const files = [
        'lib/features/public/presentation/public_institutions_directory_screen.dart',
        'lib/features/public/presentation/institution_sector_screen.dart',
      ];
      for (final path in files) {
        final src = File(path).readAsStringSync();
        expect(RegExp(r'items:\s*page\.(verified|other)\b').hasMatch(src),
            isFalse,
            reason: '$path renders a verification cohort as its own '
                'section — verification is identity truth on each card, '
                'never relevance ranking (C2).');
      }
    });

    test('Spaces discovery reads the backend, not a compiled-in universe', () {
      // The registry survives as a fallback for icons and legacy addresses;
      // it is no longer the product authority for what exists.
      final src =
          File('lib/features/public/presentation/spaces_discovery_screen.dart')
              .readAsStringSync();
      expect(src.contains('publicSpacesProvider'), isFalse,
          reason: 'the hardcoded registry must not decide what is '
              'discoverable — four of its ten entries existed nowhere else');
      expect(src, contains('discoverRepositoryProvider'));
    });
  });

  group('DISCOVER ROUTE MOUNT + old-taxonomy retirement (live-defect pins, '
      '2026-08-16)', () {
    test('/discover mounts the canonical DiscoverScreen', () {
      final router = File('lib/router.dart').readAsStringSync();
      final mount = RegExp(
        r"path:\s*'/discover',\s*\n\s*builder:\s*\(_, __\) => const DiscoverScreen\(\)",
      );
      expect(mount.hasMatch(router), isTrue,
          reason: 'The canonical /discover route must mount DiscoverScreen '
              '(features/discover). A different widget here is the '
              'stale-landing defect.');
      expect(
        RegExp(r'class DiscoverScreen\b')
            .allMatches(
                File('lib/features/discover/presentation/discover_screen.dart')
                    .readAsStringSync())
            .length,
        1,
        reason: 'Exactly one DiscoverScreen implementation may exist.',
      );
    });

    test('the old taxonomy label "Creators" is retired platform-wide', () {
      // Aura discovers PEOPLE, not a privileged creator class (frozen).
      final offenders = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        // Scan CODE only — doc comments may name the banned label in
        // order to ban it.
        final src = f
            .readAsStringSync()
            .replaceAll(RegExp(r'///.*'), '')
            .replaceAll(RegExp(r'//.*'), '');
        if (src.contains("'Creators'") || src.contains('"Creators"')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: '"Creators" is banned user-facing vocabulary: $offenders');
    });
  });

  group('Spaces taxonomy registry integrity', () {
    test('slugs, ids, and tags are unique and stable-shaped', () {
      // The registry is now a fallback rather than the authority, but its
      // frozen wire contracts still have to hold: the backend rows were seeded
      // from exactly these slugs.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final spaces = container.read(publicSpacesProvider);
      expect(spaces.length, greaterThanOrEqualTo(6));
      expect(spaces.map((s) => s.slug).toSet().length, spaces.length);
      expect(spaces.map((s) => s.id).toSet().length, spaces.length);
      expect(spaces.map((s) => s.tag).toSet().length, spaces.length);
      for (final s in spaces) {
        expect(RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(s.slug), isTrue,
            reason: 'slug ${s.slug} must stay URL-stable');
      }
    });
  });
}
