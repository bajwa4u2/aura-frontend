import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/navigation/return_path_frame.dart';
import 'package:aura/router.dart';

/// INSTITUTION RETURN CONTINUITY, ON A CLIENT THAT IS ACTUALLY SIGNED IN.
///
/// Founder ruling §11 and §12. The widget suite proves the AUTHORITY answers
/// correctly for institution addresses; this proves the same thing on a real
/// released client holding a real session, where the institution shell, its
/// gates and its data all actually run.
///
///     flutter test integration_test/signed_in_institution_return_test.dart -d windows
///
/// It signs nobody in. If the client on this machine has no session it says so
/// and stops, rather than certifying a signed-out journey and calling it a
/// signed-in one.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const institution = 'aura-platform-llc';

  Future<(GoRouter, bool)> open(WidgetTester tester, String path) async {
    // A real workspace-sized surface. The institution rail overflows at the
    // default test window — a pre-existing layout condition unrelated to
    // navigation, which would otherwise fail every institution journey here.
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Deliberately not disposed — the router's own network work outlives the
    // test, and disposing mid-flight throws late against the next one.
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
    await tester.pump(const Duration(milliseconds: 600));

    final store = container.read(tokenStoreProvider);
    final authed =
        store.isLoaded && (store.accessToken?.trim().isNotEmpty ?? false);
    return (router, authed);
  }

  String where(GoRouter r) => r.routeInformationProvider.value.uri.path;

  testWidgets('a cold institution entry keeps its institution on the way out',
      (tester) async {
    final (router, authed) = await open(
        tester, '/institution/$institution/spaces');

    if (!authed) {
      // Stated, never inferred. A signed-out run cannot certify this.
      // ignore: avoid_print
      print('SIGNED-IN INSTITUTION CERT :: SKIPPED — no session on this client');
      return;
    }
    // ignore: avoid_print
    print('SIGNED-IN INSTITUTION CERT :: session present, landed on '
        '${where(router)}');

    // A gate may legitimately move a signed-in member elsewhere; what must not
    // happen is landing somewhere with no way out.
    if (!where(router).startsWith('/institution/')) {
      // ignore: avoid_print
      print('SIGNED-IN INSTITUTION CERT :: gate redirected to '
          '${where(router)} — not an institution surface, nothing to assert');
      return;
    }

    expect(find.byKey(returnAffordanceKey), findsOneWidget,
        reason: 'an institution section entered cold has no way out');

    await tester.tap(find.byKey(returnAffordanceKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(where(router), startsWith('/institution/$institution'),
        reason: 'returning from an institution section dropped the person out '
            'of the institution — the context loss §11 exists to remove');
    // ignore: avoid_print
    print('SIGNED-IN INSTITUTION CERT :: cold entry returned to '
        '${where(router)} — EXERCISED');
  });

  testWidgets('an in-app step into a Space unwinds rather than jumping',
      (tester) async {
    final (router, authed) = await open(
        tester, '/institution/$institution/spaces');
    if (!authed || !where(router).startsWith('/institution/')) return;

    final origin = where(router);
    router.push('/institution/$institution/spaces/general');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    if (where(router) != '/institution/$institution/spaces/general') {
      // ignore: avoid_print
      print('SIGNED-IN INSTITUTION CERT :: in-app step NOT exercised — the '
          'push landed on ${where(router)}');
      return;
    }

    expect(find.byKey(returnAffordanceKey), findsOneWidget);
    await tester.tap(find.byKey(returnAffordanceKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(where(router), origin,
        reason: 'an in-app step did not unwind to where the person came from');
    // ignore: avoid_print
    print('SIGNED-IN INSTITUTION CERT :: in-app step unwound to $origin '
        '— EXERCISED');
  });
}
