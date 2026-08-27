// PREFERENCES — what the reconstruction must keep true.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHAT THIS PROVES, AND WHAT IT DOES NOT
//
// The Trace chapter established the distinction the hard way: a test that
// constructs the expected UI state by hand proves only that IF the state
// exists, the UI can render it. It says nothing about whether the state is
// produced, persisted, or read back.
//
// So the WRITE→READBACK proof for preferences is not here — it ran against
// production and is recorded in the chapter document:
//
//   communication preference   BOTH → NONE → read back NONE → restored BOTH
//   block                      0 → block → listed with identity → unblock → 0
//
// What IS here is the wiring those proofs cannot see: that the entry points
// lead to the landing, that every row leads somewhere the router actually
// declares, and that the unblock control calls the authority and refreshes
// both caches. Each of these was wrong before this chapter.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/navigation/navigation_authority.dart';
import 'package:aura/features/me/presentation/preferences_screen.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('THE ENTRY POINTS LEAD TO PREFERENCES', () {
    // Both said they did and neither did: "Preferences" opened the
    // communications screen and "Settings" opened security, so a person
    // choosing between two words got whichever narrow screen sat behind the
    // one they picked.

    test('the account menu has ONE preferences entry, to the landing', () {
      final src = _read('lib/app/shell/shell_header_tools.dart');
      expect(src, contains('kMePreferencesRoute'));
      // The second entry is gone rather than relabelled — two names for one
      // idea is what produced the confusion.
      expect(src, isNot(contains("_menuItem('settings'")));
      expect(src, isNot(contains("context.go('/security')")));
    });

    test('the left drawer has ONE preferences entry, to the landing', () {
      final src = _read('lib/app/shell/member_shell.dart');
      expect(src, contains('kMePreferencesRoute'));
      expect(src, isNot(contains("go('/me/settings/communications')")));
      expect(src, isNot(contains("go('/security')")));
    });

    test('the profile is no longer a third settings hub', () {
      // It listed Security and Devices and never mentioned communication
      // preferences, so it answered part of the question and looked complete.
      final src = _read('lib/features/me/presentation/me_screen.dart');
      expect(src, contains('kMePreferencesRoute'));
      expect(src, isNot(contains("context.push('/devices')")));
    });
  });

  group('ADVERSARIAL — the entry points the first pass missed', () {
    // Fixing the two obvious entries is not the same as fixing them all.
    // These two were found by searching for what still pointed at the narrow
    // screens, rather than by trusting the two that had been changed.

    test('a bare /settings link resolves to the landing, not to security', () {
      // The legacy alias sent anyone following an old link straight past
      // everything except sessions.
      final src = _read('lib/app/route_targets.dart');
      expect(src, contains("normalizedPath = '/me/preferences'"));
      expect(src, isNot(contains("normalizedPath = '/security'")));
    });

    test('the own-profile header was a FOURTH mislabelled entry', () {
      final src =
          _read('lib/features/profile/presentation/author_profile_screen.dart');
      expect(src, contains('NavigationAuthority.preferencesRoute'));
      // The old action is gone, not merely joined by a new one.
      expect(src, isNot(contains("icon: Icons.settings_outlined")));
    });
  });

  group('EVERY ROW LEADS SOMEWHERE THE ROUTER DECLARES', () {
    // A row that leads nowhere is the specific failure a settings landing
    // invites, because nothing about the row looks different when it is dead.

    test('the landing uses the navigation authority, not literals', () {
      final src = _read('lib/features/me/presentation/preferences_screen.dart');
      // The C3 ratchet already enforces this repo-wide; asserting it here says
      // WHY it matters for this surface, where scattered literals are exactly
      // how three hubs came to disagree.
      expect(src, isNot(contains("push('/")));
      expect(src, contains('NavigationAuthority.'));
    });

    test('every destination the landing names is a real route', () {
      final router = _read('lib/router.dart');
      const destinations = [
        NavigationAuthority.preferencesRoute,
        NavigationAuthority.blockedPeopleRoute,
        NavigationAuthority.communicationPreferencesRoute,
        NavigationAuthority.securityRoute,
        NavigationAuthority.devicesRoute,
        NavigationAuthority.changePasswordRoute,
        NavigationAuthority.editProfileRoute,
        NavigationAuthority.accountDeletionRoute,
      ];
      for (final d in destinations) {
        expect(
          router.contains("'$d'") ||
              router.contains(_constantNameFor(d)) ,
          isTrue,
          reason: 'Preferences leads to $d and the router does not declare it.',
        );
      }
    });

    testWidgets('the landing renders every group', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: PreferencesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      for (final group in [
        'Account',
        'Notifications',
        'Security',
        'Privacy',
        'Data and account',
      ]) {
        expect(find.text(group), findsOneWidget, reason: '$group is missing');
      }
    });

    testWidgets('there is NO appearance group', (tester) async {
      // Aura is single-theme. A theme control would be a row that changes
      // nothing, which is the exact failure this reconstruction removes.
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PreferencesScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsNothing);
      expect(find.textContaining('Theme'), findsNothing);
    });
  });

  group('THE THREE THINGS CALLED "DEVICE" ARE NAMED APART', () {
    // /auth/sessions, /auth/trusted-devices and /devices/me all answered to
    // the word "device" and nothing in the product distinguished them.

    test('security names sessions and trusted devices for what they do', () {
      final src = _read('lib/features/me/presentation/security_screen.dart');
      expect(src, contains('Where else you are signed in'));
      expect(src, contains('Devices that skip verification'));
      expect(src, isNot(contains("title: 'Other active sessions'")));
      expect(src, isNot(contains("title: 'Trusted devices'")));
    });

    test('the push-device screen says which device it means', () {
      final src = _read('lib/features/devices/presentation/devices_screen.dart');
      expect(src, contains("title: 'Your devices'"));
    });
  });

  group('THE SIGN-IN HISTORY IS BOUNDED', () {
    test('it renders a fixed number and states what it is not showing', () {
      // It rendered every event the endpoint returned, inside a panel with no
      // height of its own — a wall a person had to scroll past to reach
      // anything below it.
      final src = _read('lib/features/me/presentation/security_screen.dart');
      expect(src, contains('const shown = 6'));
      expect(src, contains('older sign-ins not shown'));
      // The remainder is disclosed, not silently truncated.
      expect(src, contains('events.length - visible.length'));
    });

    test('the copy is written for a person, not a log', () {
      final src = _read('lib/features/me/presentation/security_screen.dart');
      expect(src, contains("'Wrong password'"));
      expect(src, contains("'Signed in'"));
      expect(src, isNot(contains("'Failed password'")));
      // An unrecognised result must not print its own enum name at a person.
      expect(src, isNot(contains('_ => (\n                            result,')));
    });
  });

  group('BLOCKED PEOPLE — the control that had no caller', () {
    test('the screen calls unblock and refreshes BOTH caches', () {
      // The list is what the person is looking at; the id set is what every
      // feed card consults. Refreshing one and not the other would show the
      // block gone here and still hide their posts everywhere else.
      final src =
          _read('lib/features/me/presentation/blocked_people_screen.dart');
      expect(src, contains('.unblock('));
      expect(src, contains('invalidate(blockedPeopleProvider)'));
      expect(src, contains('invalidate(blockedUserIdsProvider)'));
    });

    test('a failed load is not presented as an empty list', () {
      // Showing "you have not blocked anyone" when the request failed would
      // tell a person something false about their own boundaries.
      final src =
          _read('lib/features/me/presentation/blocked_people_screen.dart');
      expect(src, contains('ProductState.error'));
      expect(src, contains('onRecover'));
    });

    test('unblocking states its consequence before it happens', () {
      final src =
          _read('lib/features/me/presentation/blocked_people_screen.dart');
      expect(src, contains('able to see your public work and reach you again'));
      // Reversible, and said so — this is not a destructive action dressed as
      // one, nor a destructive one dressed as reversible.
      expect(src, contains('You can block them again at any time'));
    });
  });
}

/// The authority constant whose value is [path], for router lookups that
/// reference the constant rather than the literal.
String _constantNameFor(String path) {
  switch (path) {
    case '/me/preferences':
      return 'kMePreferencesRoute';
    case '/me/blocked':
      return 'kMeBlockedRoute';
    case '/me/settings/communications':
      return 'kMeCommunicationsRoute';
    default:
      return path;
  }
}
