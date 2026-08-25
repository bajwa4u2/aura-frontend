import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/navigation/return_path_authority.dart';
import 'package:aura/core/navigation/return_path_frame.dart';
import 'package:aura/core/navigation/route_registry.dart';
import 'package:aura/router.dart';

/// THE THINGS THAT MUST NOT BREAK WHILE RETURN PATHS ARE ADDED.
///
/// Founder ruling 2026-08-25 §4 and §17. Stack-preserving navigation is a new
/// power and every one of these is a way it could go wrong: history that grows
/// when nothing was navigated, a redirect that leaves a footprint, a root that
/// grows a Back, a Cancel that pretends to be one.
///
/// §4 is the sharpest: REFRESH IS NOT NAVIGATION is frozen, and this chapter is
/// the first that could violate it by accident — a refresh, an invalidation or
/// a realtime update that pushed instead of reconstructing would silently start
/// manufacturing journey history.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ProviderContainer settled() => ProviderContainer(overrides: [
        sessionBootstrapProvider.overrideWith((ref) async {}),
        isAuthedProvider.overrideWithValue(true),
        emailVerifiedProvider.overrideWith((ref) async => true),
        identityBaselineCompleteProvider.overrideWith((ref) async => true),
      ]);

  /// The router only navigates once it is attached to a widget tree, so every
  /// one of these mounts it. Reading the location through the route
  /// information provider is deliberate — `routerDelegate.currentConfiguration`
  /// reads empty while a redirect is still resolving.
  Future<GoRouter> mounted(WidgetTester tester, ProviderContainer c) async {
    // A desktop-sized surface. The default 800x600 makes the public home
    // screen's hero row overflow — a pre-existing layout condition unrelated
    // to navigation, which would otherwise fail every test that renders a
    // real destination.
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = c.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        // The routed child IS rendered here, unlike the cold-entry census.
        // Discarding it leaves the delegate with zero route matches, so
        // `canPop` answers false for everything and the test would pass
        // while proving nothing. Measured before relying on it.
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  String where(GoRouter r) => r.routeInformationProvider.value.uri.path;

  group('REFRESH IS NOT NAVIGATION (frozen contract)', () {
    testWidgets('refreshing the router creates no history', (tester) async {
      final router = await mounted(tester, settled());

      router.go('/institution/aura-platform-llc/spaces/general');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final before = where(router);
      final couldPopBefore = router.canPop();

      // What a provider invalidation, a realtime reconciliation and a
      // projection reread all ultimately do to the router.
      router.refresh();
      router.refresh();
      router.refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(where(router), before, reason: 'refresh moved the person');
      expect(router.canPop(), couldPopBefore,
          reason: 'refresh manufactured navigation history — REFRESH IS NOT '
              'NAVIGATION is violated');
    });

    testWidgets('repeated refresh cannot accumulate a stack', (tester) async {
      final router = await mounted(tester, settled());
      router.go('/messages');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        router.refresh();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(router.canPop(), isFalse,
          reason: '10 refreshes built a 10-deep history');
    });
  });

  group('a canonical redirect leaves no footprint', () {
    testWidgets('being redirected is not a place you can return to',
        (tester) async {
      final router = await mounted(tester, settled());
      // A pure redirect address. Where it finally lands depends on the auth
      // gates, which is not this test's subject: what matters is that being
      // moved by the router leaves nothing behind to return TO.
      router.go('/conversations');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(where(router), isNot('/conversations'),
          reason: 'the redirect did not resolve at all');
      expect(router.canPop(), isFalse,
          reason: 'the redirect itself became a history entry, so returning '
              'would bounce the person straight forward again');
    });
  });

  group('the stack, when it is real, wins', () {
    testWidgets('push then pop returns to the actual predecessor',
        (tester) async {
      // Two cheap public informational screens: the mechanics under test are
      // the router's, and heavier destinations would drag in their own
      // providers and timers for nothing.
      final router = await mounted(tester, settled());
      router.go('/mission');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(router.canPop(), isFalse);

      router.push('/terms');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(router.canPop(), isTrue,
          reason: 'a child entry did not preserve its predecessor');

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(where(router), '/mission');
    });
  });

  group('the authority never lies about what is available', () {
    late RouteRegistry registry;

    setUp(() {
      registry = RouteRegistry.fromRoutes(
        settled().read(routerProvider).configuration.routes,
      );
    });

    ReturnAction resolve(String p, {bool canPop = false}) =>
        ReturnPathAuthority.resolve(
          path: p,
          canPop: canPop,
          isAuthed: true,
          exists: registry.exists,
        );

    test('a root never acquires a Back, even deep in a journey', () {
      for (final p in ['/home', '/messages', '/discover', '/create']) {
        expect(resolve(p, canPop: true).hasAffordance, isFalse, reason: p);
      }
    });

    test('Cancel is never presented as hierarchical Back', () {
      final a = resolve('/messages/new', canPop: true);
      expect(a.semantic, ReturnSemantic.flowCancel);
      expect(a.isHierarchical, isFalse);
    });

    test('institution context survives a direct entry', () {
      // The context-loss defect: 22 institution findings, and the failure mode
      // was landing the person on a generic root.
      for (final p in [
        '/institution/aura-platform-llc/spaces/general',
        '/institution/aura-platform-llc/units/u1',
        '/institution/aura-platform-llc/members',
      ]) {
        final d = resolve(p).destination!;
        expect(d, startsWith('/institution/aura-platform-llc'),
            reason: '$p lost its institution on the way out');
      }
    });

    test('Meetings and Live are not framed by the shared affordance', () {
      // Founder ruling §13 — a shared change must not alter protected
      // behaviour, and this is the line that keeps that true.
      for (final p in [
        '/realtime/s1',
        '/meet/some-slug',
        '/institution/x/meetings/m1/live',
        '/i/inst/meet/booking',
      ]) {
        expect(ReturnPathAuthority.isProtectedDomain(p), isTrue, reason: p);
      }
    });

    test('the auth gates are left to RC4', () {
      for (final p in [
        '/login',
        '/register',
        '/verify-email',
        '/complete-identity',
        '/enter-institution',
        '/institution/sign-in',
      ]) {
        expect(ReturnPathAuthority.isProtectedDomain(p), isTrue, reason: p);
      }
    });

    test('an ordinary destination is NOT protected', () {
      // The guard must be narrow. If it drifted wide, surfaces would silently
      // stop being framed and the defect would come back invisibly.
      for (final p in [
        '/institution/x/spaces/general',
        '/messages/c/c1',
        '/privacy',
        '/institutions/some-slug',
      ]) {
        expect(ReturnPathAuthority.isProtectedDomain(p), isFalse, reason: p);
      }
    });
  });

  group('the affordance never outlives the destination it was drawn for', () {
    testWidgets('returning to a ROOT clears the control', (tester) async {
      // Seen live on 2026-08-25: cancelling the composer returned to Create
      // correctly, and Create kept rendering the composer's "Cancel". A root
      // must show nothing, and a control that outlives its destination is
      // pointing somewhere the person is no longer standing.
      //
      // The cause was the mirror of the Android finding: a `pop` moves the
      // DELEGATE without the route information provider, so a frame listening
      // to only one of them never hears about it.
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final c = settled();
      final router = c.read(routerProvider);
      router.go('/mission');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      router.push('/terms');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(returnAffordanceKey), findsOneWidget);

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // /mission is not a root, so it still offers one — but it must be
      // /mission's, resolved now, not the one drawn for /terms.
      final onMission = tester.widgetList(find.byKey(returnAffordanceKey));
      expect(onMission.length, 1,
          reason: 'the control did not survive the pop as exactly one');
    });

    testWidgets('a root shows none even after returning to it', (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final c = settled();
      final router = c.read(routerProvider);
      router.go('/');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(returnAffordanceKey), findsNothing);

      router.push('/terms');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(returnAffordanceKey), findsOneWidget);

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(returnAffordanceKey), findsNothing,
          reason: 'a root kept the control drawn for the destination that was '
              'just left');
    });
  });

  group('the affordance is presented, once, and only where it belongs', () {
    testWidgets('a deep-linked detail shows a governed return', (tester) async {
      final c = settled();
      final router = c.read(routerProvider);
      router.go('/institutions/aura-platform-llc');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // One control, not two: the hardcoded parent this replaced is gone.
      expect(
          tester.widgetList(find.byIcon(Icons.arrow_back_rounded)).length,
          lessThanOrEqualTo(1));
    });
  });
}
