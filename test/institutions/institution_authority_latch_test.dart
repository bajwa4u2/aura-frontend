import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/institutions/institution_route_authority.dart';

/// A RE-CHECK MUST NOT UN-ESTABLISH THE INSTITUTION AUTHORITY.
///
/// Measured against the deployed client on 2026-08-24. Institution access
/// resolved once and was then re-run; the re-run carried no previous value, so
/// the route boundary's "still finding out" test (`isLoading && !hasValue`)
/// became true a second time and stayed true. Every institution route — the
/// members roster, the Spaces list, a Space detail — sat on a spinner
/// indefinitely. The child route builder never ran, so no screen-owned request
/// was ever issued, which is why the failure looked like a dead surface rather
/// than a slow one.
///
/// The repair latches the last ESTABLISHED answer at the producer, so the
/// boundary waits only for the first resolution. These pin that property from
/// the outside, including the part that must NOT change: a genuine first load,
/// where nothing has been learned yet, still waits.
void main() {
  const anInstitution = InstitutionAccess(
    state: InstitutionAccessState.verifiedMember,
    memberships: [
      MemberAffiliation(
        id: 'inst-1',
        name: 'Aura Platform',
        slug: 'aura-platform-llc',
        role: 'OWNER',
        canSpeakOfficially: true,
        isVerified: true,
      ),
    ],
  );

  setUp(() => lastEstablishedInstitutionAccess = null);
  tearDown(() => lastEstablishedInstitutionAccess = null);

  ProviderContainer withAccess(Future<InstitutionAccess> Function() body) {
    final c = ProviderContainer(overrides: [
      institutionAccessProvider.overrideWith((ref) => body()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('a FIRST load that has learned nothing still waits', () {
    final c = withAccess(() => Completer<InstitutionAccess>().future);
    final snapshot = c.read(institutionAuthoritySnapshotProvider);
    expect(snapshot.resolved, isFalse,
        reason: 'nothing is known yet — waiting is the honest answer');
  });

  test('an established authority survives a re-check that is still in flight',
      () {
    // The exact production shape: a completed resolution, then a re-run that
    // has not produced a value.
    lastEstablishedInstitutionAccess = anInstitution;
    final c = withAccess(() => Completer<InstitutionAccess>().future);

    final snapshot = c.read(institutionAuthoritySnapshotProvider);
    expect(snapshot.resolved, isTrue,
        reason: 'a re-check is not a loss of knowledge');
    expect(snapshot.slugToId['aura-platform-llc'], 'inst-1',
        reason: 'and the established answer is the one still in force');
  });

  test('the latch is written by the producer, not by an observer', () {
    // An observer only sees a value while it is being watched, and the
    // boundary is routinely mounted after a completed run was already
    // superseded — so the producer is the only place that can record it
    // reliably. Asserted on the source because a test that overrides the
    // provider replaces the very body this property lives in.
    final src = File(
      'lib/core/institutions/institution_access_provider.dart',
    ).readAsStringSync();
    final start = src.indexOf('final institutionAccessProvider =');
    expect(start, greaterThan(0));
    final body = src.substring(start, start + 400);
    expect(body, contains('lastEstablishedInstitutionAccess = result'),
        reason: 'the completed resolution must latch itself');
  });

  test('a fresh value still wins over the latched one', () async {
    lastEstablishedInstitutionAccess = anInstitution;
    const other = InstitutionAccess(
      state: InstitutionAccessState.none,
      memberships: [],
    );
    final c = withAccess(() async => other);
    await c.read(institutionAccessProvider.future);

    final snapshot = c.read(institutionAuthoritySnapshotProvider);
    expect(snapshot.resolved, isTrue);
    // The latch is a fallback for an in-flight re-check, never an override of
    // what the server has just said.
    expect(snapshot.slugToId, isEmpty);
  });
}
