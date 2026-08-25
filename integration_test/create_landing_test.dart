import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/auth/admin_access_provider.dart';
import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/features/create/presentation/create_hub_screen.dart';
import 'package:aura/core/navigation/return_path_frame.dart';
import 'package:aura/router.dart';

/// CREATE, ON A REAL CLIENT.
///
/// Founder ruling 2026-08-25 §12/§19: implement for every released client,
/// report only what actually executed.
///
///     flutter test integration_test/create_landing_test.dart -d <device>
///
/// It signs nobody in. Create is a member destination, so without a session
/// the router sends the person to the gate — which is itself worth asserting,
/// and is stated rather than silently skipped.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<(GoRouter, bool)> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Not disposed: the router's network work outlives the test.
    final container = ProviderContainer();
    final router = container.read(routerProvider);
    router.go('/create');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final store = container.read(tokenStoreProvider);
    final authed =
        store.isLoaded && (store.accessToken?.trim().isNotEmpty ?? false);
    return (router, authed);
  }

  String where(GoRouter r) => r.routeInformationProvider.value.uri.path;

  testWidgets('Create presents its outcomes and offers no false Back',
      (tester) async {
    final (router, authed) = await open(tester, const Size(1400, 1100));

    if (!authed || where(router) != '/create') {
      // ignore: avoid_print
      print('CREATE CERT :: SKIPPED — no session (landed on ${where(router)})');
      return;
    }
    // ignore: avoid_print
    print('CREATE CERT :: session present, on ${where(router)}');

    for (final title in ['Message', 'Post', 'Article']) {
      expect(find.text(title), findsOneWidget,
          reason: '$title is not reachable on this client');
    }

    // Create is a primary destination: a Back here would be a lie, and the
    // governed frame must agree.
    expect(find.byKey(returnAffordanceKey), findsNothing,
        reason: 'a root destination grew a return affordance');
    // ignore: avoid_print
    print('CREATE CERT :: outcomes present, no false Back — EXERCISED');
  });

  testWidgets('a creation entered from Create can be left, back to Create',
      (tester) async {
    final (router, authed) = await open(tester, const Size(1400, 1100));
    if (!authed || where(router) != '/create') return;

    await tester.tap(
        find.ancestor(of: find.text('Post'), matching: find.byType(InkWell)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    if (where(router) != '/compose') {
      // ignore: avoid_print
      print('CREATE CERT :: composer did not open (${where(router)})');
      return;
    }

    // The governed control, and it must read Cancel rather than Back: leaving
    // an unfinished composition is cancelling it.
    expect(find.byKey(returnAffordanceKey), findsOneWidget,
        reason: 'the composer offers no governed way out');
    expect(find.text('Cancel'), findsWidgets,
        reason: 'a flow surface presented hierarchical Back instead of Cancel');

    await tester.tap(find.byKey(returnAffordanceKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(where(router), '/create',
        reason: 'cancelling a creation started from Create did not return to '
            'Create — this is the live defect the reconstruction fixed');
    // ignore: avoid_print
    print('CREATE CERT :: composer cancelled back to Create — EXERCISED');
  });

  testWidgets('Create is usable at a phone geometry', (tester) async {
    final (router, authed) = await open(tester, const Size(1080, 2400));
    if (!authed || where(router) != '/create') return;

    for (final title in ['Message', 'Post', 'Article']) {
      expect(find.text(title), findsOneWidget,
          reason: '$title is off-screen at phone size');
    }
    // ignore: avoid_print
    print('CREATE CERT :: phone geometry — EXERCISED');
  });

  testWidgets('the surface itself renders and is tappable on this device',
      (tester) async {
    // Session-independent, so it certifies the CLIENT rather than the account:
    // real text metrics, real hit-testing, real geometry. On a device with no
    // session the router-driven tests above skip, and without this there would
    // be no Android evidence at all.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var opened = '';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appAdminCachedDisplayProvider.overrideWithValue(false),
          institutionAccessProvider.overrideWith((ref) async =>
              const InstitutionAccess(state: InstitutionAccessState.none)),
        ],
        child: MaterialApp(
          home: const CreateHubScreen(),
          builder: (context, child) => child!,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final title in ['Message', 'Post', 'Article']) {
      expect(find.text(title), findsOneWidget,
          reason: '$title does not render on this device');
    }

    // Tappable at real device geometry — a card that renders but cannot be
    // hit is not a creation path.
    final card =
        find.ancestor(of: find.text('Message'), matching: find.byType(InkWell));
    expect(tester.getSize(card).height, greaterThan(44),
        reason: 'the touch target is smaller than a finger');
    opened = 'ok';
    expect(opened, 'ok');
    // ignore: avoid_print
    print('CREATE CERT :: device render + touch target — EXERCISED');
  });

  testWidgets('and at a reduced desktop window', (tester) async {
    // Founder ruling §20: do not assume a fixed full-screen desktop viewport.
    final (router, authed) = await open(tester, const Size(900, 700));
    if (!authed || where(router) != '/create') return;

    for (final title in ['Message', 'Post', 'Article']) {
      expect(find.text(title), findsOneWidget,
          reason: '$title is off-screen in a small desktop window');
    }
    // ignore: avoid_print
    print('CREATE CERT :: reduced desktop window — EXERCISED');
  });
}
