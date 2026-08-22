// THE CONTINUITY INVARIANT, PROVEN AS BEHAVIOUR.
//
//   INTENDED ROUTE
//     -> bootstrap/auth unresolved
//     -> the route does NOT change
//     -> the destination does NOT mount prematurely
//     -> auth resolves
//     -> the SAME intended route mounts, if authorised
//
// The 171-route census proves no route in the population can land on the boot
// path. This file proves the mechanism itself, on representative classes, by
// driving the real router rather than reading source strings.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/router.dart';
import 'package:aura/app/route_classification.dart';
import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/navigation/boot_gate.dart';
import 'package:aura/core/navigation/destination_continuity.dart';

/// Representative of every routing class Aura has. Chosen so that a defect in
/// one shape cannot hide behind another.
const Map<String, String> kRepresentativeRoutes = {
  'public': '/public',
  'authenticated': '/home',
  'object (article by slug)': '/articles/the-quiet-work-that-holds-people-together',
  'object (post by id)': '/posts/cmt2id26t003prw0cqhwmnmnz',
  'person profile by handle': '/u/bajwa',
  'institution canonical': '/institution/cmmg1ildu0000k201gtwg60rr/profile',
  'institution shorthand': '/institution/profile',
  'nested object': '/institution/cmmg1ildu0000k201gtwg60rr/posts/cmt2id26t003prw0cqhwmnmnz',
};

/// What the browser address bar would show.
///
/// `routerDelegate.currentConfiguration` reflects the MATCHED route list,
/// which is empty while an async redirect is still resolving — reading it
/// there yields '' and makes an assertion pass vacuously. The route
/// information provider is the location itself, which is the thing this
/// invariant is actually about.
String _location(GoRouter r) => r.routeInformationProvider.value.uri.toString();

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('while authentication is UNRESOLVED', () {
    late Completer<void> restore;
    late ProviderContainer container;
    late GoRouter router;

    setUp(() {
      restore = Completer<void>();
      container = ProviderContainer(
        overrides: [
          // Held open deliberately: this is the exact window in which the old
          // router navigated away to /_boot.
          sessionBootstrapProvider.overrideWith((ref) => restore.future),
          isAuthedProvider.overrideWithValue(true),
          emailVerifiedProvider.overrideWith((ref) async => true),
          identityBaselineCompleteProvider.overrideWith((ref) async => true),
        ],
      );
      router = container.read(routerProvider);
    });

    for (final entry in kRepresentativeRoutes.entries) {
      testWidgets('${entry.key}: the route does NOT change', (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              builder: (_, __) => const SizedBox.shrink(),
            ),
          ),
        );
        router.go(entry.value);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(_location(router), entry.value,
            reason: 'Restoring a session is not navigation. The URL the person '
                'asked for must survive it untouched.');
        expect(isBootPath(Uri.parse(_location(router)).path), isFalse);

        restore.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // AND STILL THERE once authentication resolves.
        expect(_location(router), entry.value,
            reason: 'Resolving authentication must not relocate anyone either.');
      });
    }
  });

  group('the destination must NOT mount prematurely', () {
    testWidgets('BootGate renders INSTEAD of the child while restoring',
        (tester) async {
      // This is why staying put is safe. An overlay would leave the
      // destination mounted, and its providers would fire requests while
      // authentication is still unknown — which is the real work the old
      // redirect to /_boot was doing.
      var childBuilt = false;
      final restore = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          sessionBootstrapProvider.overrideWith((ref) => restore.future),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: BootGate(
              child: Builder(
                builder: (_) {
                  childBuilt = true;
                  return const Text('destination');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(childBuilt, isFalse,
          reason: 'A destination that is not in the tree cannot fire requests '
              'while authentication is unknown.');
      expect(find.text('destination'), findsNothing);

      restore.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(childBuilt, isTrue,
          reason: 'Once authentication resolves the intended destination must '
              'mount — the whole point of having waited.');
      expect(find.text('destination'), findsOneWidget);
    });
  });

  group('terminal denial remains terminal', () {
    test('a temporary gate preserves the destination', () {
      // RC4: a gate the person can pass must return them afterwards.
      final r = gateRedirect(
        gate: '/login',
        target: '/articles/a-real-slug',
      );
      expect(r, contains('redirect='));
      expect(Uri.decodeComponent(r.split('redirect=').last),
          '/articles/a-real-slug');
    });

    test('a TERMINAL denial keeps nothing, even under refresh continuity', () {
      // Refresh continuity must never become an authorisation bypass. A
      // non-admin does not become an admin by reloading the page.
      final r = gateRedirect(
        gate: '/home',
        target: '/admin/communications',
        kind: ExitKind.terminalDenial,
      );
      expect(r, '/home');
      expect(r, isNot(contains('redirect=')));
    });

    test('the boot path is never accepted as a return target', () {
      // Otherwise a stale address could bounce someone back into machinery.
      expect(validatedReturnTarget('/_boot'), isNull);
      expect(validatedReturnTarget('/_boot?redirect=/home'), isNull);
    });

    test('an external destination is refused outright', () {
      for (final hostile in const [
        'https://evil.test/x',
        '//evil.test',
        '/%2f%2fevil.test',
      ]) {
        expect(validatedReturnTarget(hostile), isNull,
            reason: '$hostile must not survive validation');
      }
    });
  });
}
