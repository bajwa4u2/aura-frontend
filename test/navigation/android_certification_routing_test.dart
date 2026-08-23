import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// TWO ROUTING DEFECTS ANDROID FOUND THAT THE WEB COULD NOT.
///
/// Both are shared-architecture defects. Neither is Android-specific — they
/// were simply invisible in a browser, which is exactly why native
/// certification exists.
///
/// These are source assertions rather than widget tests because both live in
/// the router's redirect closure, which is not independently constructible
/// without standing up the whole provider graph. A source gate pins the
/// DECISION; the device verified the behaviour.
void main() {
  final router = File('lib/router.dart').readAsStringSync();

  group('a signed-in member does not land on the acquisition page', () {
    /// `/` renders PublicHomeScreen unconditionally and nothing redirected an
    /// authenticated member away from it. The web never showed this: a browser
    /// retains its URL, so a returning member reopens `/messages` or `/home`
    /// and never sees the root. Android has no such memory — every cold start
    /// begins at `/` — so each launch put a signed-in member on the page that
    /// explains what Aura is, with the bottom nav highlighting "Home" beside
    /// content that was not their home.
    test('the bare root redirects an authenticated member to /home', () {
      expect(
        router,
        contains("if (isLoggedIn && path == '/') {"),
        reason: 'the authenticated root redirect is gone',
      );
    });

    test('it is decided AFTER authority has resolved', () {
      // Deciding while standing is still loading is the RC2 defect, and here
      // it would also bounce a member off a legitimate deep link mid-flight.
      final loadingGuard = router.indexOf('appAdminLoading)) {');
      final rootRedirect = router.indexOf("if (isLoggedIn && path == '/') {");

      expect(loadingGuard, greaterThan(0));
      expect(rootRedirect, greaterThan(loadingGuard),
          reason: 'the root redirect must sit after the loading guards');
    });

    test('only the bare root is touched', () {
      // A prefix match would have swallowed every deep link and every
      // notification destination.
      expect(router, isNot(contains("isLoggedIn && path.startsWith('/')")));
    });
  });

  group('a person without standing is told so, not asked to log in again', () {
    /// Founder ruling D5/D6, and the frozen doctrine that institution standing
    /// is a RELATIONSHIP a person holds rather than a second account.
    ///
    /// The gate sent them to `/enter-institution`, which asks for an
    /// institution email and password and offers to create an institutional
    /// account — the legacy model in which an institution was its own login.
    /// On the device an already-authenticated member, named in the header, was
    /// shown "Institution sign in — Private institutional access".
    ///
    /// Same shape as the 2026-08-14 meetings regression on a different route
    /// family, and it contradicted the standing route declared in the same
    /// file, which "never pretends the person entered".
    test('the no-access gate sends them to the standing surface', () {
      final gate = RegExp(
        r'requiresInstitutionAccess\(path\) && !institutionAccess\.hasAccess\)'
        r'[\s\S]{0,400}?\);',
      ).firstMatch(router)?.group(0);

      expect(gate, isNotNull, reason: 'the institution access gate is gone');
      expect(gate, contains('kInstitutionNoAffiliationDestination'));
    });

    test('it never routes them to an institution sign-in form', () {
      final gate = RegExp(
        r'requiresInstitutionAccess\(path\) && !institutionAccess\.hasAccess\)'
        r'[\s\S]{0,400}?\);',
      ).firstMatch(router)?.group(0);

      expect(
        gate,
        isNot(contains('kEnterInstitutionRoute')),
        reason:
            'an authenticated person does not authenticate a second time to '
            'discover they hold no standing',
      );
    });

    test('the refusal is terminal — there is nothing here to pass', () {
      final gate = RegExp(
        r'requiresInstitutionAccess\(path\) && !institutionAccess\.hasAccess\)'
        r'[\s\S]{0,400}?\);',
      ).firstMatch(router)?.group(0);

      expect(gate, contains('ExitKind.terminalDenial'));
    });
  });
}
