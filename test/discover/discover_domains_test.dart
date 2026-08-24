import 'package:aura/features/institution_ontology/providers.dart';
import 'package:aura/features/institution_ontology/models.dart';
import 'package:aura/features/feed/domain/feed_item.dart';
import 'package:aura/features/feed/data/unified_feed_providers.dart';
import 'package:aura/features/discover/data/people_discovery.dart';
import 'package:aura/core/identity/person_identity_model.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/discover/presentation/discover_screen.dart';
import 'package:aura/features/public/data/public_spaces_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DISCOVER — AURA'S EXTENSIBLE DISCOVERY FRAMEWORK (founder-frozen,
/// C3 post-closeout correction, 2026-08-16). These pins enforce the
/// frozen framework rules:
///   * four immediate domains: People · Institutions · Spaces · Articles;
///   * a declared-not-available domain renders HONESTLY — no dead CTA,
///     no navigation affordance, an explicit unavailable note;
///   * Discover DISCOVERS — no onboarding/workspace affordances anywhere
///     in the discovery surfaces;
///   * verification is identity truth, never relevance ranking.
void main() {
  group('discovery-domain registry (frozen framework)', () {
    test('the four immediate domains, in order', () {
      expect(
        kDiscoveryDomains.map((d) => d.title).toList(),
        ['People', 'Institutions', 'Spaces', 'Articles'],
      );
    });

    test('implemented domains navigate; declared-unavailable domains do not',
        () {
      final byTitle = {for (final d in kDiscoveryDomains) d.title: d};
      expect(byTitle['People']!.route, '/discover/people');
      expect(byTitle['Institutions']!.route, '/institutions');
      expect(byTitle['Spaces']!.route, '/spaces');
      // Articles is REAL (2026-08-16 addendum): the fourth domain renders
      // and routes to the Article discovery/reading surface.
      expect(byTitle['Articles']!.route, '/discover/articles');
      expect(byTitle['Articles']!.unavailableNote, isNull);
    });

    test('every unavailable domain carries an honest note; available ones do not',
        () {
      for (final d in kDiscoveryDomains) {
        expect((d.route == null), (d.unavailableNote != null), reason: d.title);
      }
    });
  });

  group('Discover renders the framework honestly', () {
    /// The landing now reads three governed projections. They are overridden
    /// rather than left to fire real requests: a widget test that reaches the
    /// network is not deterministic, and the pending timers it leaves behind
    /// fail the suite for reasons unrelated to what is being asserted.
    Widget harness({
      List<PersonSuggestion> people = const [],
      InstitutionOntology ontology = InstitutionOntology.empty,
      List<FeedItem> feed = const [],
    }) {
      return ProviderScope(
        overrides: [
          peopleDiscoveryProvider.overrideWith(
            (ref) async =>
                PeopleDiscoveryPage(suggestions: people, coldStart: false),
          ),
          institutionOntologyProvider.overrideWith((ref) async => ontology),
          globalPublicFeedProvider
              .overrideWith((ref) async => FeedPage(items: feed)),
        ],
        child: const MaterialApp(home: Material(child: DiscoverScreen())),
      );
    }

    testWidgets(
        'all four domains render — Articles is real (2026-08-16 addendum)',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      for (final title in [
        'People',
        'Institutions',
        'Spaces',
        'Articles',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('a section with nothing to show does not claim to have '
        'something', (tester) async {
      // Founder finding, 2026-08-23: the landing announced "People suggested
      // for you" while showing no people. A section that cannot be filled is
      // absent, not asserted — the domain door above it still works.
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Suggested for you'), findsNothing);
      expect(find.text('Browse by sector'), findsNothing);
      // The public section stays and says, truthfully, that there is nothing.
      expect(find.text('Happening on Aura'), findsOneWidget);
    });

    testWidgets('real projections produce real, actionable content',
        (tester) async {
      // Tall surface: the ListView builds lazily, so a short viewport would
      // simply not construct the lower sections and the assertions would be
      // measuring the fold rather than the content.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 3000);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(
        people: [
          PersonSuggestion(
            person: AuraPersonIdentity.fromJson(const {
              'id': 'u1',
              'displayName': 'A Person',
              'handle': 'aperson',
            }),
            reasons: const ['Active in Civic'],
            followState: 'NONE',
          ),
        ],
        ontology: const InstitutionOntology(
          classes: [
            InstitutionClassDef(
              id: 'CIVIC_BODY',
              label: 'Civic body',
              description: 'Public institutions.',
            ),
          ],
          types: [],
          domainTags: [],
          maxDomainTagsPerInstitution: 3,
        ),
      ));
      await tester.pumpAndSettle();

      // A person, shown — with the follow control that makes the section a
      // place to act rather than a place to read a claim.
      expect(find.text('A Person'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);

      // Topical entry, from the public taxonomy.
      expect(find.text('Browse by sector'), findsOneWidget);
      expect(find.text('Civic body'), findsOneWidget);
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
        // Rendering must consume the unified activity-ordered list, not
        // section the page by the verification cohorts (which survive
        // only as transitional wire fields for released clients).
        expect(RegExp(r'items:\s*page\.(verified|other)\b').hasMatch(src),
            isFalse,
            reason: '$path renders a verification cohort as its own '
                'section — verification is identity truth on each card, '
                'never relevance ranking (C2).');
      }
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
              '(features/discover) — the frozen four-domain framework. A '
              'different widget here is the stale-landing defect.');
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

  group('ADD INSTITUTION lifecycle action (live-defect pins, 2026-08-16)',
      () {
    final headerSrc =
        File('lib/app/shell/shell_header_tools.dart').readAsStringSync();

    test('visible at EVERY width for a person with no institution — gated '
        'only by canonical relationship truth', () {
      // 2026-08-22: the gate gained a RESOLUTION term. Offering to ADD an
      // institution asserts the person has none, and an empty affiliation list
      // means "none" only after access resolves — before that it means "not
      // yet". A member who already speaks for an institution was being invited
      // to acquire one on every entry and refresh (the founder-observed
      // public -> institution transit).
      //
      // The pin's original intent is unchanged and still asserted below: the
      // action must never be gated on width, route or shell. Resolution truth
      // is not one of those.
      expect(
          RegExp(r'if \(affiliationsResolved && !hasInstitution\) \.\.\.\[')
              .hasMatch(headerSrc),
          isTrue,
          reason: 'The Add Institution action must render whenever the person '
              'is KNOWN to have no institution relationship — not desktop-only, '
              'and not while that is still unknown.');
      expect(headerSrc.contains('myAffiliationsProvider'), isTrue,
          reason: 'Visibility must derive from canonical relationship '
              'truth, never route/shell/cached assumptions.');
      expect(
          RegExp(r'isDesktop\s*&&\s*!hasInstitution').hasMatch(headerSrc),
          isFalse,
          reason: 'Width must not gate the lifecycle action.');
    });

    test('disappears once a relationship exists — no buried menu fallback',
        () {
      expect(headerSrc.contains("'add_institution'"), isFalse,
          reason: 'The account-menu variant is retired: with an '
              'institution relationship the onboarding action is ABSENT, '
              'not relocated into a menu.');
    });

    test('resolves directly to the ONE canonical onboarding journey', () {
      expect(
          headerSrc.contains('NavigationAuthority.institutionOnboardingRoute'),
          isTrue);
    });
  });

  group('Spaces taxonomy registry integrity', () {
    test('slugs, ids, and tags are unique and stable-shaped', () {
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
