// OVERVIEW IS ADDRESSABLE — founder ruling, institution addendum.
//
// `/institution/:institutionId/dashboard` used to redirect to the id-less
// address, discarding the institution the URL named. A person holding two
// institutions could not bookmark, link or refresh institution B's Overview:
// every id-bearing address collapsed to whichever membership was ambient.
//
// These pin the decision the route now makes, through the same authority every
// other canonical institution destination uses.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/institutions/institution_route_authority.dart';

String? redirectFor({
  required bool resolved,
  String? activeId,
  List<String> authorized = const [],
  String? pathId,
}) {
  return institutionCanonicalRedirect(
    decideInstitutionRoute(
      snapshot: InstitutionAuthoritySnapshot(
        resolved: resolved,
        activeId: activeId,
        authorizedIds: authorized,
      ),
      pathId: pathId,
    ),
    section: 'dashboard',
    dashboardRoute: '/institution/dashboard',
  );
}

void main() {
  group('Overview addressability', () {
    test('a validated id is honoured, not swapped for the ambient one', () {
      // The defect this replaced: holding A and B, addressing B delivered A.
      expect(
        redirectFor(
          resolved: true,
          activeId: 'inst-a',
          authorized: ['inst-a', 'inst-b'],
          pathId: 'inst-b',
        ),
        isNull,
        reason: 'the URL named an institution the person holds',
      );
    });

    test('the current institution proceeds unchanged', () {
      expect(
        redirectFor(
          resolved: true,
          activeId: 'inst-a',
          authorized: ['inst-a'],
          pathId: 'inst-a',
        ),
        isNull,
      );
    });

    test('an unresolved authority decides nothing', () {
      // RC2 — loading is not absence. Deciding here is what made refresh fail.
      expect(
        redirectFor(resolved: false, pathId: 'inst-a'),
        isNull,
      );
    });

    test('a foreign id is refused rather than silently substituted', () {
      expect(
        redirectFor(
          resolved: true,
          activeId: 'inst-a',
          authorized: ['inst-a'],
          pathId: 'inst-zzz',
        ),
        '/institution/dashboard',
      );
    });

    test('holding nothing lands on the standing surface', () {
      expect(
        redirectFor(resolved: true, pathId: 'inst-a'),
        '/institution/dashboard',
      );
    });
  });
}
