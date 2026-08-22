import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/router.dart';

// SCREEN IDENTITY AND NAVIGATIONAL IDENTITY MUST NOT DIVERGE.
//
// Founder-observed, and measured live on 2026-08-22: pressing the call button
// rendered the call room while the browser still carried /messages/c/<id>.
// Refreshing there would have reconstructed the conversation and discarded the
// call — the person moved backward without navigating anywhere.
//
// The cause was not the call route. go_router does not reflect imperative
// navigation in the URL unless `optionURLReflectsImperativeAPIs` is set, and it
// defaults to false. Aura has 186 `context.push(...)` sites, so EVERY one of
// them changed the screen without changing the address.
//
// This is also why a route census kept passing while the founder kept seeing
// the defect: a census navigates BY ADDRESS, so address and screen agree for it
// by construction. A person navigates BY TAPPING.

String _location(GoRouter r) => r.routeInformationProvider.value.uri.toString();

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ProviderContainer _authedContainer() => ProviderContainer(
        overrides: [
          sessionBootstrapProvider.overrideWith((ref) async {}),
          isAuthedProvider.overrideWithValue(true),
          emailVerifiedProvider.overrideWith((ref) async => true),
          identityBaselineCompleteProvider.overrideWith((ref) async => true),
        ],
      );

  testWidgets('the address follows an imperative push, not only a go',
      (tester) async {
    final container = _authedContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          // The invariant is about the ADDRESS, not the page, and real
          // screens would fire real providers here.
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_location(router), '/home');

    // The founder-observed shape: arrive somewhere by TAPPING.
    router.push('/saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      _location(router),
      '/saved',
      reason: 'a screen reached by tapping must be the screen the address '
          'names, or a refresh reconstructs the one before it',
    );
  });

  testWidgets('a pushed object address is the address that survives',
      (tester) async {
    final container = _authedContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          // The invariant is about the ADDRESS, not the page, and real
          // screens would fire real providers here.
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Exactly the divergence measured live: the call room reached from a
    // conversation. The address must name the room, not the conversation.
    router.push('/realtime/sess_abc?action=join');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final uri = Uri.parse(_location(router));
    expect(uri.path, '/realtime/sess_abc');
    expect(uri.queryParameters['action'], 'join',
        reason: 'the intent that got the person into the room has to survive '
            'a refresh with them');
  });
}
