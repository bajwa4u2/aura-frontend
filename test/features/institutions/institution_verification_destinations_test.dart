import 'dart:io';

import 'package:aura/core/navigation/canonical_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/generate_route_registry.dart' as generator;

/// WHERE A VERIFICATION NOTICE TAKES SOMEBODY.
///
/// A notification is the one surface a person meets without having gone
/// looking, so its destination is the one most likely to be wrong and the
/// least likely to be noticed. This release already shipped one notice
/// pointing at `/verify-identity` in builds whose router had no such route,
/// and a reviewer notice pointing at `/admin/identity-review`, WHICH THE
/// ROUTER HAS NEVER DECLARED AT ALL.
///
/// So every destination minted here is checked against THE ROUTER, through the
/// same resolver the route-registry gate uses. A destination that no route
/// serves is a red suite rather than a person tapping a notice and getting
/// nothing.
void main() {
  late Set<String> declared;

  setUpAll(() {
    // THE ROUTER ITSELF, through the same resolver the doctrine gate uses.
    //
    // Not `routes.json`, and not a second parser: a route declared through a
    // constant (`/verify-identity` is one) lives in a different list there,
    // and a reader that only looked at literals would call a real route a
    // phantom. One resolver means this test and the registry gate cannot
    // disagree about what the router declares.
    declared = generator.allDeclaredRoutes(
      File('lib/router.dart').readAsStringSync(),
      Directory('lib'),
    );

    // Positive control: if the resolver returned nothing, every assertion
    // below would pass by finding nothing to contradict.
    expect(declared.length, greaterThan(100));
    expect(declared, contains('/institution/:institutionId/verification'));
    expect(declared, contains('/verify-identity'));
  });

  /// A concrete path matches a declared route, allowing for `:params`.
  bool isServedByARoute(String path) {
    final actual = path.split('/').where((s) => s.isNotEmpty).toList();
    for (final route in declared) {
      final parts = route.split('/').where((s) => s.isNotEmpty).toList();
      if (parts.length != actual.length) continue;
      var ok = true;
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].startsWith(':')) continue;
        if (parts[i] != actual[i]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  group('institution verification notices', () {
    const subjectTypes = [
      'INSTITUTION_VERIFICATION_UNDER_REVIEW',
      'INSTITUTION_VERIFICATION_NEEDS_INFO',
      'INSTITUTION_VERIFICATION_CONFIRMED',
      'INSTITUTION_VERIFICATION_REJECTED',
      'INSTITUTION_VERIFICATION_EXPIRED',
      'INSTITUTION_AUTHORITY_GRANTED',
      'INSTITUTION_AUTHORITY_SUSPENDED',
      'INSTITUTION_AUTHORITY_REVOKED',
    ];

    test('EVERY SUBJECT NOTICE LANDS ON THAT INSTITUTION', () {
      for (final type in subjectTypes) {
        final destination = institutionVerificationDestination(type, 'inst_1');
        expect(
          destination,
          '/institution/inst_1/verification',
          reason: '$type should open the institution it is about',
        );
        expect(isServedByARoute(destination!), isTrue,
            reason: '$type resolves to a route the router does not declare');
      }
    });

    test('THE REVIEWER QUEUE NOTICE GOES TO THE QUEUE, not an institution', () {
      final destination = institutionVerificationDestination(
        'INSTITUTION_VERIFICATION_SUBMITTED',
        'inst_1',
      );
      // A reviewer arrives wanting the next thing waiting, and must not be
      // dropped into the applicant's own page.
      expect(destination, '/admin/integrity/institution-verification');
      expect(destination, isNot(contains('inst_1')));
    });

    test('WITHOUT AN INSTITUTION THE TAP IS INERT, never someone else', () {
      // The alternative to nothing is landing on whichever institution
      // happened to be first, which is worse than a tap that does nothing.
      for (final ref in [null, '', '   ']) {
        expect(
          institutionVerificationDestination('INSTITUTION_AUTHORITY_REVOKED', ref),
          isNull,
        );
      }
    });

    test('an unrelated type resolves to nothing', () {
      expect(institutionVerificationDestination('LIKE', 'inst_1'), isNull);
      expect(institutionVerificationDestination(null, 'inst_1'), isNull);
      // Identity is a DIFFERENT family and must not be captured by this one.
      expect(
        institutionVerificationDestination('IDENTITY_VERIFICATION_APPROVED', 'inst_1'),
        isNull,
      );
    });
  });

  group('identity verification notices', () {
    test('the subject notice lands on a route that exists', () {
      final destination =
          identityVerificationDestination('IDENTITY_VERIFICATION_APPROVED');
      expect(destination, '/verify-identity');
      expect(isServedByARoute(destination!), isTrue);
    });

    test('THE REVIEWER NOTICE NO LONGER POINTS AT A PHANTOM', () {
      // It pointed at `/admin/identity-review`, which the router has never
      // declared. A reviewer tapping "a verification is waiting for review"
      // was sent nowhere — the same phantom-destination shape the identity
      // destination authority was written to prevent, on the other side of
      // the same family.
      final destination =
          identityVerificationDestination('IDENTITY_VERIFICATION_SUBMITTED');
      expect(destination, isNot('/admin/identity-review'));
      expect(isServedByARoute(destination!), isTrue,
          reason: 'the reviewer notice must land on a declared route');
    });
  });
}
