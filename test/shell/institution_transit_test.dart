import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/institutions/institution_access_provider.dart';

// THE PUBLIC -> INSTITUTION TRANSIT.
//
// Founder-observed 2026-08-22: "a user entering Aura or refreshing goes to a
// transit phase between public user and institution context - narrow, but
// visibly noted."
//
// `myAffiliationsProvider` answers with an empty list in BOTH states: the
// person holds no institution, and we have not found out yet - because
// `valueOrNull` destroys that distinction. The shell then treated empty as
// "none": it hid the affiliation line and offered "Add your institution" to
// somebody who already speaks for one, until the answer arrived and both
// flipped.
//
// UNKNOWN IS NOT ABSENT. The router already follows this rule for institution
// routes (decideInstitutionRoute returns *unresolved* rather than guessing);
// the shell simply was not consuming it.
void main() {
  test('while access is still loading, affiliations are NOT resolved', () {
    final container = ProviderContainer(
      overrides: [
        institutionAccessProvider.overrideWith(
          (ref) => Completer<InstitutionAccess>().future,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(myAffiliationsResolvedProvider), isFalse,
        reason: 'an empty list here means "not yet", never "none"');
    expect(container.read(myAffiliationsProvider), isEmpty,
        reason: 'and this is exactly why empty cannot be read as an answer');
  });

  test('resolved with no institution IS an answer', () async {
    final container = ProviderContainer(
      overrides: [
        institutionAccessProvider.overrideWith(
          (ref) async =>
              const InstitutionAccess(state: InstitutionAccessState.none),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(institutionAccessProvider.future);

    expect(container.read(myAffiliationsResolvedProvider), isTrue);
    expect(container.read(myAffiliationsProvider), isEmpty,
        reason: 'resolved-and-none is when presenting "none" becomes truthful');
  });
}
