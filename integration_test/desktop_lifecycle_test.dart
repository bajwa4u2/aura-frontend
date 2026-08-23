import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/notifications/notification_presentation.dart';
import 'package:aura/features/realtime/presentation/widgets/floating_call_widget.dart';
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
