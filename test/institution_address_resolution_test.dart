// CANONICAL INSTITUTION ADDRESSING — resolution, never authorization.
//
// Founder rulings AD2/AD4 (2026-08-23). The workspace addresses an institution
// by its canonical slug; a legacy id-shaped address must resolve and then be
// CANONICALIZED rather than merely tolerated, because production holds durable
// id-shaped links that would otherwise keep two address forms alive forever.
//
// The frozen rule these must never soften: resolving an address says WHICH
// institution is addressed. It never says the viewer may be there.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/institutions/institution_route_authority.dart';

InstitutionAuthoritySnapshot snapshot({
  bool resolved = true,
  String? activeId,
  Map<String, String> slugs = const {},
}) {
  return InstitutionAuthoritySnapshot(
    resolved: resolved,
    activeId: activeId,
    authorizedIds: slugs.values.toList(),
    slugToId: {
      for (final e in slugs.entries) e.key.toLowerCase(): e.value,
    },
    idToSlug: {for (final e in slugs.entries) e.value: e.key},
  );
}

void main() {
  final held = snapshot(
    activeId: 'inst-a',
    slugs: {'aura-platform-llc': 'inst-a', 'other-inst': 'inst-b'},
  );

  group('address resolution', () {
    test('the canonical slug resolves and needs no redirect', () {
      final a = resolveInstitutionAddress(held, 'aura-platform-llc')!;

      expect(a.institutionId, 'inst-a');
      expect(a.canonicalSlug, 'aura-platform-llc');
      expect(a.isCanonical, isTrue);
    });

    test('a raw persistence id resolves but is NOT canonical', () {
      // The founder-observed defect: /institution/cmmg1ildu…/profile. It must
      // keep working — durable links exist — and must converge on arrival.
      final a = resolveInstitutionAddress(held, 'inst-a')!;

      expect(a.institutionId, 'inst-a');
      expect(a.canonicalSlug, 'aura-platform-llc');
      expect(a.isCanonical, isFalse);
    });

    test('a differently-cased slug is the same identity, canonicalized', () {
      // Two spellings of one address are one institution; only one of them is
      // the address that gets linked.
      final a = resolveInstitutionAddress(held, 'Aura-Platform-LLC')!;

      expect(a.institutionId, 'inst-a');
      expect(a.canonicalSlug, 'aura-platform-llc');
      expect(a.isCanonical, isFalse);
    });

    test('an unknown address resolves to nothing rather than guessing', () {
      // Includes a HISTORICAL slug: retired addresses live server-side, so the
      // snapshot must not invent an answer it does not have.
      expect(resolveInstitutionAddress(held, 'never-existed'), isNull);
      expect(resolveInstitutionAddress(held, ''), isNull);
      expect(resolveInstitutionAddress(held, null), isNull);
    });

    test('it resolves only institutions the person actually holds', () {
      final none = snapshot(slugs: const {});
      expect(resolveInstitutionAddress(none, 'aura-platform-llc'), isNull);
    });
  });

  group('resolution is not authorization', () {
    test('knowing a slug grants no standing', () {
      // Resolution succeeds for a held institution, and the DECISION is still
      // made by the authority below it — these are separate answers.
      final a = resolveInstitutionAddress(held, 'other-inst')!;
      expect(a.institutionId, 'inst-b');

      // The authority, asked about an institution the person does NOT hold,
      // refuses regardless of how the address was spelled.
      final outsider = snapshot(activeId: 'inst-a', slugs: {'aura-platform-llc': 'inst-a'});
      final decision = decideInstitutionRoute(
        snapshot: outsider,
        pathId: 'inst-b',
      );
      expect(decision.outcome, InstitutionRouteOutcome.notAuthorized);
    });

    test('an unresolved snapshot decides nothing (RC2)', () {
      final loading = snapshot(resolved: false);
      expect(resolveInstitutionAddress(loading, 'aura-platform-llc'), isNull);

      final decision = decideInstitutionRoute(
        snapshot: loading,
        pathId: 'inst-a',
      );
      expect(decision.outcome, InstitutionRouteOutcome.unresolved);
    });
  });
}
