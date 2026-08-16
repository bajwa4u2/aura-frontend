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
      // Articles is CANONICALLY DECLARED, not implemented (Long-Form
      // Publishing is a founder-owned roadmap gap). Founder visibility
      // ruling: declared domains without truthful capability are NOT
      // rendered in the live experience — no route, no CTA, no card.
      expect(byTitle['Articles']!.route, isNull);
      expect(byTitle['Articles']!.unavailableNote, isNotNull);
    });

    test('every unavailable domain carries an honest note; available ones do not',
        () {
      for (final d in kDiscoveryDomains) {
        expect((d.route == null), (d.unavailableNote != null), reason: d.title);
      }
    });
  });

  group('Discover renders the framework honestly', () {
    testWidgets(
        'live domains render; declared-unavailable Articles renders NOTHING '
        '(no dead card in the live experience — founder visibility ruling)',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Material(child: DiscoverScreen())),
        ),
      );
      for (final title in ['People', 'Institutions', 'Spaces']) {
        expect(find.text(title), findsOneWidget);
      }
      // Articles is canonically declared in the registry but must not
      // occupy the live experience until truthful capability exists.
      expect(find.text('Articles'), findsNothing);
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
