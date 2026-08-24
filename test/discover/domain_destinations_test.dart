import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A DOMAIN DESTINATION IS A DISCOVERY EXPERIENCE, NOT AN OLD LIST.
///
/// Founder ruling: tapping People, Institutions, Spaces or Articles must not
/// merely open a legacy directory and declare the journey complete. Each
/// destination reads the relevance-ordered projection, presents its objects in
/// that domain's own visual language, and carries the natural next action.
///
/// These pin the properties that a later change could quietly undo.
void main() {
  String codeOnly(String src) => src
      .split(String.fromCharCode(10))
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('///') && !t.startsWith('*');
      })
      .join(String.fromCharCode(10));

  const destinations = {
    'spaces': 'lib/features/public/presentation/spaces_discovery_screen.dart',
    'institutions':
        'lib/features/discover/presentation/institutions_discovery_screen.dart',
    'articles':
        'lib/features/discover/presentation/articles_discovery_screen.dart',
  };

  group('every destination reads the discovery authority', () {
    destinations.forEach((name, path) {
      test('$name consumes the relevance-ordered projection', () {
        final code = codeOnly(File(path).readAsStringSync());
        expect(code, contains('discoverRepositoryProvider'),
            reason: '$name must not go back to a raw list endpoint');
      });

      test('$name answers loading, error and empty distinctly', () {
        // The founder's recurring defect was a surface that rendered nothing
        // for all three. Each must be its own answer.
        final code = codeOnly(File(path).readAsStringSync());
        expect(code, contains('ProductState.loading'));
        expect(code, contains('ProductState.retryableError'));
        expect(code, contains('ProductState.empty'));
      });
    });
  });

  group('the sector ontology lives in Institutions, not on the landing', () {
    test('the Institutions destination offers sector narrowing', () {
      final code = codeOnly(
          File(destinations['institutions']!).readAsStringSync());
      expect(code, contains('institutionOntologyProvider'));
      expect(code, contains('institutionClass:'));
    });

    test('an empty sector says so, differently from an empty corpus', () {
      // No institution currently carries a classification, so every sector is
      // empty. "No institutions in this sector yet" and "no institutions at
      // all" are different facts and must read differently.
      final src =
          File(destinations['institutions']!).readAsStringSync();
      expect(src, contains('No institutions in this sector yet'));
      expect(src, contains('No institutions to show yet'));
    });

    test('the landing does not carry the taxonomy', () {
      final landing = codeOnly(
          File('lib/features/discover/presentation/discover_screen.dart')
              .readAsStringSync());
      expect(landing.contains('institutionOntologyProvider'), isFalse);
    });
  });

  group('public addresses stay browsable without a session', () {
    test('discovery falls back to public projections when signed out', () {
      // /discover, /spaces and /institutions are PUBLIC routes by
      // classification. The discovery endpoints are auth-only because
      // relevance is personal, so an anonymous viewer reads the public
      // projections instead — the same objects, no relevance, no follow state.
      final repo = codeOnly(
          File('lib/features/discover/data/discover_repository.dart')
              .readAsStringSync());
      expect(repo, contains('isAuthedProvider'));
      expect(repo, contains("'/public-spaces'"));
      expect(repo, contains("'/public/institutions'"));
      expect(repo, contains("'/articles'"));
    });

    test('the public routes are still classified public', () {
      final classification =
          File('lib/app/route_classification.dart').readAsStringSync();
      for (final path in ["'/discover'", "'/spaces'", "'/institutions'"]) {
        expect(classification, contains(path));
      }
    });
  });

  group('the legacy list is retired, not merely bypassed', () {
    test('the old articles list no longer exists', () {
      final src =
          File('lib/features/articles/presentation/article_screen.dart')
              .readAsStringSync();
      expect(src.contains('class ArticlesDiscoveryScreen'), isFalse,
          reason: 'exactly one Articles discovery surface may exist');
    });

    test('both destinations are mounted', () {
      final router = File('lib/router.dart').readAsStringSync();
      expect(router, contains("path: '/discover/institutions'"));
      expect(router, contains("path: '/discover/articles'"));
      // The public directory keeps its own address.
      expect(router, contains("path: '/institutions'"));
    });
  });
}
