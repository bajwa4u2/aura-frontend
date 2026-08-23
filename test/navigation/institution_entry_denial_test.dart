import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/institutions/institution_route_authority.dart';

// THREE DESTINATIONS THAT WERE ONE CONSTANT.
//
// kInstitutionDashboardRoute answered three different questions at once:
// where entering an institution LANDS, where a refused person is SENT (RC4
// terminal denial), and where a shorthand resolves for someone who holds NO
// institution. One string, three meanings, so changing one silently changed
// the others.
//
// Founder ruling 2026-08-22 moves institution ENTRY to Explore. Repointing the
// shared constant would have handed a denied person the very workspace they
// had just been refused.
void main() {
  test('entering an institution lands on Explore, not Overview', () {
    expect(institutionEntryDestination('inst_1'), '/institution/inst_1/explore');
  });

  test('entry is id-scoped, and degrades honestly without one', () {
    expect(institutionEntryDestination(''), kInstitutionNoAffiliationDestination);
    expect(institutionEntryDestination('   '), kInstitutionNoAffiliationDestination,
        reason: 'a blank id is not an institution');
  });

  test('refusal is NOT the entry destination', () {
    expect(kInstitutionDenialDestination,
        isNot(institutionEntryDestination('inst_1')),
        reason: 'a person refused admin standing has not earned the front door');
  });

  test('RC4 terminal denial still routes to the denial destination', () {
    final router = File('lib/router.dart').readAsStringSync();
    final denialBlocks = RegExp(
      r'gate: kInstitutionDenialDestination,[\s\S]{0,160}?ExitKind\.terminalDenial',
    ).allMatches(router).length;

    expect(denialBlocks, 2,
        reason: 'both institution terminal-denial gates must use the denial '
            'destination, never the entry one');
  });

  test('no terminal-denial gate points at the entry destination', () {
    final router = File('lib/router.dart').readAsStringSync();
    expect(
      RegExp(r'gate: institutionEntryDestination').hasMatch(router),
      isFalse,
      reason: 'entry and refusal must never converge',
    );
  });
}
