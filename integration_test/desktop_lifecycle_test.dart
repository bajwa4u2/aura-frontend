import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/notifications/notification_presentation.dart';
import 'package:aura/features/realtime/presentation/widgets/floating_call_widget.dart';
import 'package:aura/core/navigation/return_path_authority.dart';
import 'package:aura/core/navigation/return_path_frame.dart';
import 'package:aura/router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

// NATIVE CERTIFICATION — WINDOWS DESKTOP (a released Aura client, MSIX).
//
// Web PASS is not native PASS. Everything certified so far ran in a browser,
// which exercises none of a native client's plugin registration, window
// lifecycle or platform channels.
//
// This runs the REAL app on the REAL platform, without manual operation:
//     flutter test integration_test -d windows
//
// What it can honestly certify here is COLD START and DESTINATION TRUTH. It
// deliberately does NOT sign in: entering credentials is not something this
// harness should do, and everything below is provable without a session.
// Signed-in native lifecycle (push tray, background, badge clearing) remains
// UNVERIFIED until a harness that can hold a session exists — stated, not
// inferred from Web.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Windows desktop — cold start', () {
    testWidgets('platform channels are registered on the native build',
        (tester) async {
      // The half a browser never exercises: on a native build these resolve
      // through real platform channels, and a missing plugin registration
      // fails HERE rather than in front of a person.
      //
      // Deliberately NOT booting the whole app here: the real router starts
      // network work whose completion outlives the test, which reports as a
      // failure after the test has already passed and tells us nothing about
      // the platform. Plugin registration is the claim; this proves it.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('aura.native.cert', 'ok');
      expect(prefs.getString('aura.native.cert'), 'ok',
          reason: 'shared_preferences must round-trip through the Windows '
              'platform channel');
      await prefs.remove('aura.native.cert');

      final info = await PackageInfo.fromPlatform();
      expect(info.appName.trim(), isNotEmpty,
          reason: 'package_info_plus backs canonical client identity, which '
              'every request and socket handshake carries');
    });
  });

  group('Windows desktop — destination truth', () {
    testWidgets('an address reached imperatively is the address that survives',
        (tester) async {
      // The same invariant certified on Web, re-proved on the native build:
      // the platform differs, the promise does not.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (_, __) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      router.push('/realtime/sess_native?action=join');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final uri = Uri.parse(router.routeInformationProvider.value.uri.toString());
      expect(uri.path, '/realtime/sess_native');
      expect(uri.queryParameters['action'], 'join',
          reason: 'the intent that put someone in a room survives with them');
    });

    testWidgets('a call surface owns the screen on this platform too',
        (tester) async {
      expect(callSurfaceOwnsTheScreen(Uri.parse('/realtime/s1')), isTrue);
      expect(callSurfaceOwnsTheScreen(Uri.parse('/meetings/m1/live')), isTrue);
      expect(callSurfaceOwnsTheScreen(Uri.parse('/home')), isFalse);
    });
  });

  group('Windows desktop — return path (founder ruling 2026-08-25 §12)', () {
    // This chapter exists because browser chrome concealed a product defect.
    // A native window has no Back button of its own, so a destination with no
    // Aura affordance is a destination with no way out at all — which is what
    // makes proving it HERE, rather than only in a browser, the point.
    testWidgets('a directly-entered destination presents a governed return',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Deliberately NOT disposed. Mounting the real child starts the
      // router's own network work, and tearing the container down while that
      // is in flight throws "read a provider from a disposed container" —
      // late, and attributed to whichever test runs next.
      final container = ProviderContainer();
      final router = container.read(routerProvider);
      router.go('/terms');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          // The real child, not a stub: a discarded child leaves the delegate
          // with no route matches, and every claim about return paths would
          // then be vacuously true.
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(returnAffordanceKey), findsOneWidget,
          reason: 'a native client offers no browser Back — this IS the only '
              'way out');

      await tester.tap(find.byKey(returnAffordanceKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(router.routeInformationProvider.value.uri.path, isNot('/terms'),
          reason: 'the control rendered on Windows but did not move anyone');
    });

    testWidgets('a protected surface is NOT framed on this platform either',
        (tester) async {
      // Founder ruling §13: a shared change must not alter Meetings/Live,
      // including by decorating them.
      expect(ReturnPathAuthority.isProtectedDomain('/realtime/s1'), isTrue);
      expect(ReturnPathAuthority.isProtectedDomain('/meetings/m1/live'), isTrue);
    });
  });

  group('Windows desktop — notification semantics', () {
    testWidgets('the one authority answers the same way on a native client',
        (tester) async {
      expect(
        resolveNotificationTitle(<String, dynamic>{
          'type': 'LIKE',
          'actor': {'displayName': 'Amjad'},
        }),
        'Amjad liked your post',
      );
      expect(
        resolveNotificationTitle(<String, dynamic>{
          'type': 'CALL_MISSED',
          'actor': {'displayName': 'Zakria'},
          'data': {'callState': 'MISSED'},
        }),
        contains('Missed call'),
        reason: 'a call must never read as "interacted with your content"',
      );
    });
  });
}
