import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/core/navigation/return_path_frame.dart';
import 'package:aura/router.dart';

/// THE AFFORDANCE IS ACTUALLY ON SCREEN.
///
/// The recensus proves the AUTHORITY answers correctly for all 175 routes.
/// That is not the same claim as "a person can see a way out", and the whole
/// reason this chapter exists is that `AuraScaffold` accepted a `leading:`
/// argument for months and rendered nothing. An authority nobody renders would
/// be the same defect with better paperwork.
///
/// So these mount the real app at real addresses and look for the control.
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

  Future<GoRouter> open(WidgetTester tester, String path, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = settled();
    final router = c.read(routerProvider);
    router.go(path);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    return router;
  }

  group('a directly-entered destination shows a way out', () {
    for (final path in const [
      '/privacy',
      '/terms',
      '/mission',
      '/white-paper',
    ]) {
      testWidgets('$path presents a return control', (tester) async {
        await open(tester, path);
        expect(find.byKey(returnAffordanceKey), findsOneWidget,
            reason: '$path renders no governed return affordance');
      });
    }
  });

  group('MOBILE — the surface this chapter exists for', () {
    // Browser chrome hid the defect on desktop; a phone has none. These run at
    // a real handset size.
    const phone = Size(1080, 2400);

    for (final path in const ['/privacy', '/mission']) {
      testWidgets('$path presents a return control on a phone-sized surface',
          (tester) async {
        await open(tester, path, size: phone);
        expect(find.byKey(returnAffordanceKey), findsOneWidget,
            reason: '$path has no way out on mobile');
      });
    }
  });

  group('a root does NOT show one', () {
    testWidgets('the public home has no back control', (tester) async {
      await open(tester, '/');
      expect(find.byKey(returnAffordanceKey), findsNothing);
    });
  });

  testWidgets('the control actually navigates', (tester) async {
    // Presenting a control that does nothing would pass every structural test
    // in this chapter.
    final router = await open(tester, '/terms');
    expect(router.routeInformationProvider.value.uri.path, '/terms');

    expect(find.byKey(returnAffordanceKey), findsOneWidget,
        reason: 'exactly one governed control per surface');
    await tester.tap(find.byKey(returnAffordanceKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(router.routeInformationProvider.value.uri.path, isNot('/terms'),
        reason: 'the return control rendered but did not move anyone');
  });
}
