import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/navigation/return_path_authority.dart';
import 'package:aura/core/navigation/return_path_frame.dart';
import 'package:aura/core/navigation/route_registry.dart';
import 'package:aura/router.dart';

/// ANDROID — THE PLATFORM THIS CHAPTER EXISTS FOR.
///
/// Founder ruling 2026-08-25 §12: browser chrome concealed a product defect,
/// so the fix must be certified as Aura navigation, not browser navigation.
/// A phone has no browser Back at all, and it has something no desktop harness
/// can exercise: a SYSTEM back gesture that the app must answer coherently
/// with its own visible control.
///
///     flutter test integration_test/android_return_path_test.dart -d <device>
///
/// It does not sign in. Everything asserted here is provable without a
/// session, and entering credentials is not something this harness should do.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Mounts the real app at [path] and returns its router.
  ///
  /// The routed child is rendered. Discarding it leaves the delegate with zero
  /// route matches, so `canPop` answers false for everything and every claim
  /// below would be vacuously true — measured, not assumed.
  Future<GoRouter> open(WidgetTester tester, String path) async {
    // Deliberately not disposed: mounting the real child starts the router's
    // own network work, and tearing the container down mid-flight throws from
    // a provider read, late, against whichever test runs next.
    final container = ProviderContainer();
    final router = container.read(routerProvider);
    router.go(path);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return router;
  }

  String where(GoRouter r) => r.routeInformationProvider.value.uri.path;

  group('Android — the visible way out', () {
    testWidgets('a directly-entered destination presents a governed return',
        (tester) async {
      final router = await open(tester, '/terms');
      expect(where(router), '/terms');

      expect(find.byKey(returnAffordanceKey), findsOneWidget,
          reason: 'on a phone there is no browser Back — this IS the only way '
              'out, and 47 destinations had none when this chapter opened');

      await tester.tap(find.byKey(returnAffordanceKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(where(router), isNot('/terms'),
          reason: 'the control rendered on Android but did not move anyone');
    });

    testWidgets('a root offers none', (tester) async {
      final router = await open(tester, '/');
      expect(where(router), '/');
      expect(find.byKey(returnAffordanceKey), findsNothing,
          reason: 'a top-level destination grew a Back that lies');
    });

    testWidgets('exactly ONE control, never two', (tester) async {
      // The convergence: screens that drew their own arrow were retired onto
      // the governed one, and two arrows on one screen is what that ended.
      await open(tester, '/privacy');
      expect(find.byKey(returnAffordanceKey), findsOneWidget);
      expect(
        tester.widgetList(find.byIcon(Icons.arrow_back_rounded)).length,
        lessThanOrEqualTo(1),
        reason: 'a second back control reappeared on this surface',
      );
    });
  });

  group('Android — SYSTEM back', () {
    // The half only a real handset can answer. Founder ruling §12: system
    // back, the visible affordance and the shell must converge on one
    // navigation authority rather than drifting apart.
    testWidgets('system back unwinds a real journey', (tester) async {
      final router = await open(tester, '/mission');
      expect(where(router), '/mission');

      router.push('/terms');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(where(router), '/terms');
      expect(router.canPop(), isTrue,
          reason: 'a child entry did not preserve its predecessor, so system '
              'back has nothing to unwind');

      // The real thing: Android's back button, delivered as the platform
      // delivers it.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(where(router), '/mission',
          reason: 'system back did not return to the actual predecessor');
    });

    testWidgets('system back and the visible control agree', (tester) async {
      // Two mechanisms, one authority. If these ever disagree, one of them is
      // lying to the person about where they are.
      final a = await open(tester, '/mission');
      a.push('/terms');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final viaSystem = where(a);

      final b = await open(tester, '/mission');
      b.push('/terms');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(returnAffordanceKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final viaControl = where(b);

      expect(viaControl, viaSystem,
          reason: 'the visible control and Android system back reached '
              'different destinations from the same journey: '
              'system=$viaSystem control=$viaControl');
    });
  });

  group('Android — the protected boundary', () {
    testWidgets('Meetings and Live are not framed here either', (tester) async {
      // §13: a shared change must not alter protected behaviour, including by
      // decorating it.
      for (final p in [
        '/realtime/s1',
        '/meet/some-slug',
        '/institution/x/meetings/m1/live',
      ]) {
        expect(ReturnPathAuthority.isProtectedDomain(p), isTrue, reason: p);
      }
    });
  });

  group('Android — deep-link escape', () {
    testWidgets('an institution address entered cold keeps its institution',
        (tester) async {
      // The context-loss defect, on the platform where it mattered most: 22
      // institution findings, all of which dropped the person at a generic
      // root.
      final container = ProviderContainer();
      final registry = RouteRegistry.fromRoutes(
        container.read(routerProvider).configuration.routes,
      );

      final action = ReturnPathAuthority.resolve(
        path: '/institution/aura-platform-llc/members',
        canPop: false,
        isAuthed: true,
        exists: registry.exists,
      );
      expect(action.destination, startsWith('/institution/aura-platform-llc'),
          reason: 'a cold institution entry loses its institution on the way '
              'out');
    });
  });
}
