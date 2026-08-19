// RC2 + RC3 — INSTITUTION ROUTE RESTORATION.
//
// RC2 — the route redirects read `institutionIdentityProvider`, a synchronous
// view over an async source whose null means three different things. A cold
// load of an institution destination therefore decided "no institution" while
// the answer was still in flight, and hard-landed on the dashboard. Refresh
// could never survive — not because the person lacked authority, but because
// the router asked before the answer existed.
//
// RC3 — "provider identity outranks the URL": any path id disagreeing with
// the active identity was rewritten to the active one. For a member of two
// institutions, refreshing on institution B's page silently delivered
// institution A's.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/institutions/institution_route_authority.dart';

InstitutionRouteDecision decide({
  required bool resolved,
  String? activeId,
  List<String> authorized = const [],
  String? pathId,
}) {
  return decideInstitutionRoute(
    snapshot: InstitutionAuthoritySnapshot(
      resolved: resolved,
      activeId: activeId,
      authorizedIds: authorized,
    ),
    pathId: pathId,
  );
}

void main() {
  group('RC2 — loading is not absence', () {
    test('an unresolved authority decides NOTHING, with or without a path id', () {
      expect(decide(resolved: false, pathId: null).outcome,
          InstitutionRouteOutcome.unresolved);
      expect(decide(resolved: false, pathId: 'inst-1').outcome,
          InstitutionRouteOutcome.unresolved);
    });

    test('unresolved outranks every other signal', () {
      // Not "no institution", not "unauthorized" — unknown. Nothing about a
      // half-loaded provider licenses a destination decision.
      final d = decide(
        resolved: false,
        activeId: 'inst-1',
        authorized: ['inst-1', 'inst-2'],
        pathId: 'inst-2',
      );
      expect(d.outcome, InstitutionRouteOutcome.unresolved);
      expect(d.institutionId, isNull);
    });

    test('RESOLVED-and-absent is a different answer from unresolved', () {
      expect(decide(resolved: true, pathId: null).outcome,
          InstitutionRouteOutcome.noAffiliation);
    });
  });

  group('RC3 — the path id is a claim, validated against membership', () {
    test('the active institution proceeds unchanged', () {
      final d = decide(
          resolved: true, activeId: 'inst-1', authorized: ['inst-1'], pathId: 'inst-1');
      expect(d.outcome, InstitutionRouteOutcome.proceed);
      expect(d.institutionId, 'inst-1');
    });

    test('a genuinely held institution is recognised, not discarded', () {
      // The defect was silently substituting inst-1 here and never saying so.
      final d = decide(
        resolved: true,
        activeId: 'inst-1',
        authorized: ['inst-1', 'inst-2'],
        pathId: 'inst-2',
      );
      expect(d.outcome, InstitutionRouteOutcome.authorizedElsewhere);
      expect(d.institutionId, 'inst-2',
          reason: 'The decision must name the institution that was asked for.');
    });

    test('a stale or removed membership is NOT swapped for the active one', () {
      // Quietly showing someone a different institution than the one they
      // asked for is a truthfulness defect, not a convenience.
      final d = decide(
        resolved: true,
        activeId: 'inst-1',
        authorized: ['inst-1'],
        pathId: 'inst-gone',
      );
      expect(d.outcome, InstitutionRouteOutcome.notAuthorized);
      expect(d.institutionId, isNull);
    });

    test('an unknown or foreign id is refused', () {
      for (final path in ['inst-someone-else', 'not-an-id', '../etc', '  ']) {
        final d = decide(
            resolved: true, activeId: 'inst-1', authorized: ['inst-1'], pathId: path);
        expect(
          d.outcome,
          path.trim().isEmpty
              ? InstitutionRouteOutcome.canonicalize
              : InstitutionRouteOutcome.notAuthorized,
          reason: path,
        );
      }
    });

    test('an id held but with no active context is still recognised', () {
      // Institution-account tokens and freshly-loaded members can carry
      // memberships before any workspace is bound.
      final d = decide(resolved: true, authorized: ['inst-2'], pathId: 'inst-2');
      expect(d.outcome, InstitutionRouteOutcome.authorizedElsewhere);
      expect(d.institutionId, 'inst-2');
    });
  });

  group('RC3 — shorthand routes carrying no id', () {
    test('canonicalise to the bound institution', () {
      final d = decide(resolved: true, activeId: 'inst-1', pathId: null);
      expect(d.outcome, InstitutionRouteOutcome.canonicalize);
      expect(d.institutionId, 'inst-1');
    });

    test('canonicalise to the only membership when nothing is bound yet', () {
      final d = decide(resolved: true, authorized: ['inst-9'], pathId: '');
      expect(d.outcome, InstitutionRouteOutcome.canonicalize);
      expect(d.institutionId, 'inst-9');
    });

    test('SEVERAL memberships and no bound context is not a coin toss', () {
      // Picking one arbitrarily is the ambient guess this authority exists to
      // remove; the dashboard selector is the governed answer.
      final d = decide(resolved: true, authorized: ['inst-1', 'inst-2'], pathId: null);
      expect(d.outcome, InstitutionRouteOutcome.noAffiliation);
      expect(d.institutionId, isNull);
    });

    test('no affiliation at all', () {
      expect(decide(resolved: true, pathId: '').outcome,
          InstitutionRouteOutcome.noAffiliation);
    });
  });

  group('the decision space is total', () {
    test('every combination yields exactly one outcome, and no null slips', () {
      for (final resolved in [true, false]) {
        for (final active in [null, 'inst-1']) {
          for (final authorized in [
            const <String>[],
            const ['inst-1'],
            const ['inst-1', 'inst-2'],
          ]) {
            for (final path in [null, '', 'inst-1', 'inst-2', 'inst-x']) {
              final d = decide(
                  resolved: resolved,
                  activeId: active,
                  authorized: authorized,
                  pathId: path);
              expect(InstitutionRouteOutcome.values, contains(d.outcome));
              final namesAnInstitution = d.outcome ==
                      InstitutionRouteOutcome.proceed ||
                  d.outcome == InstitutionRouteOutcome.canonicalize ||
                  d.outcome == InstitutionRouteOutcome.authorizedElsewhere;
              expect(d.institutionId != null, namesAnInstitution,
                  reason: 'r=$resolved a=$active auth=$authorized p=$path');
            }
          }
        }
      }
    });
  });

  group('mapping the decision onto a route', () {
    const dash = '/institution/dashboard';
    const park = '/_boot?redirect=%2Finstitution%2Fedit-profile';

    String? canonical({required bool resolved, String? activeId,
        List<String> authorized = const [], String? pathId}) {
      return institutionCanonicalRedirect(
        decide(resolved: resolved, activeId: activeId, authorized: authorized, pathId: pathId),
        section: 'edit-profile',
        dashboardRoute: dash,
      );
    }

    String shorthand({required bool resolved, String? activeId,
        List<String> authorized = const []}) {
      return institutionShorthandRedirect(
        decide(resolved: resolved, activeId: activeId, authorized: authorized, pathId: null),
        section: 'edit-profile',
        dashboardRoute: dash,
        parkRoute: park,
      );
    }

    test('a canonical route STAYS PUT while authority resolves', () {
      // "Decide nothing" expressed literally. The screen shows its own
      // loading state and the router re-runs this redirect when the provider
      // settles — no timer, no retry loop, no guess.
      expect(canonical(resolved: false, pathId: 'inst-1'), isNull);
    });

    test('a shorthand route PARKS, preserving the destination', () {
      // It has no builder, so it must resolve to some address. Landing on the
      // dashboard because the answer had not arrived is exactly RC2.
      expect(shorthand(resolved: false), park);
      expect(shorthand(resolved: false), isNot(dash));
    });

    test('the bound institution proceeds untouched', () {
      expect(
        canonical(resolved: true, activeId: 'inst-1', authorized: ['inst-1'], pathId: 'inst-1'),
        isNull,
      );
    });

    test('AUTHORIZED ELSEWHERE now PROCEEDS — the person asked for it', () {
      // Previously rewritten to the ambient institution, because the screens
      // read ambient state and proceeding would have shown A's data under
      // B's URL. The screens are now bound to the institution the URL names,
      // so substituting a different one would be the defect.
      expect(
        canonical(
          resolved: true,
          activeId: 'inst-1',
          authorized: ['inst-1', 'inst-2'],
          pathId: 'inst-2',
        ),
        isNull,
      );
    });

    test('a shorthand canonicalises to a real URL', () {
      expect(shorthand(resolved: true, activeId: 'inst-1'),
          '/institution/inst-1/edit-profile');
    });

    test('an UNAUTHORIZED id lands on the dashboard, not another institution', () {
      final target = canonical(
          resolved: true, activeId: 'inst-1', authorized: ['inst-1'], pathId: 'inst-gone');
      expect(target, dash);
      expect(target, isNot(contains('inst-1')),
          reason: 'Silently swapping in the active institution is the defect.');
    });

    test('no affiliation lands on the dashboard from either shape', () {
      expect(canonical(resolved: true, pathId: 'inst-1'), dash);
      expect(shorthand(resolved: true), dash);
    });
  });
}
