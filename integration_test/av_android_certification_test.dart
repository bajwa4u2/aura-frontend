import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/media/call_preflight_sheet.dart';
import 'package:aura/core/media/call_readiness.dart';
import 'package:aura/core/media/device_permission.dart';
import 'package:aura/core/media/media_control_labels.dart';
import 'package:aura/core/media/media_permission_service.dart';

/// A/V — PHYSICAL ANDROID CERTIFICATION.
///
/// Founder ruling, *CONTINUE A/V RECONSTRUCTION — ANDROID DEVICE RESTORED*.
/// Run on the handset:
///
///     flutter test integration_test/av_android_certification_test.dart -d <id>
///
/// Certifies the FINAL CURRENT A/V code on real hardware. The previous
/// NOT_EXECUTED classification is not carried forward and none of the
/// Meetings-chapter Android evidence is reused — that certified different code.
///
/// **What is deliberately not simulated.** Nothing here fakes a second
/// participant, and nothing asserts a two-party outcome. The real two-party
/// lifecycle stays an open gate until a second identity exists.
///
/// **Permission states.** Where the OS state itself must be a particular
/// value, it is set from outside by `adb shell pm grant|revoke` before the run
/// and asserted here — not mocked. Tests that would raise a system dialog are
/// written to query rather than request, because an automated run cannot
/// answer a modal the OS owns.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final isAndroid = !kIsWeb && Platform.isAndroid;

  group('ANDROID · the permission system is real here', () {
    testWidgets('Android reports queryable permissions', (tester) async {
      // On Windows this is false by design. On Android it must be true, or the
      // whole native flow silently degrades to the web behaviour.
      expect(MediaPermissionService.hasQueryablePermissions, isAndroid,
          reason: 'platform=$defaultTargetPlatform');
      expect(MediaPermissionService.canOpenSettings, isAndroid,
          reason: 'a settings trip must be offered only where one exists');
    });

    testWidgets('status is readable WITHOUT provoking a system dialog',
        (tester) async {
      // The capability that did not exist before this chapter at all.
      const service = MediaPermissionService();
      final mic = await service.status(MediaDeviceKind.microphone);
      final cam = await service.status(MediaDeviceKind.camera);
      for (final state in [mic, cam]) {
        expect(DevicePermissionState.values, contains(state));
        // "unknown" would mean the plugin threw — the query path is broken.
        expect(state, isNot(DevicePermissionState.unknown),
            reason: 'the Android permission query failed');
      }
      debugPrint('[cert] android mic=$mic camera=$cam');
    });

    testWidgets('the OS state set from outside is the state Aura reports',
        (tester) async {
      // Driven by `adb shell pm revoke ... android.permission.CAMERA` before
      // this run. When the harness has not set it, the assertion is skipped
      // rather than faked — see the certification record for which run
      // carried which state.
      const service = MediaPermissionService();
      final cam = await service.status(MediaDeviceKind.camera);
      const expected = String.fromEnvironment('EXPECT_CAMERA');
      if (expected.isEmpty) {
        debugPrint('[cert] no EXPECT_CAMERA supplied; observed $cam');
        return;
      }
      expect(cam.name, expected,
          reason: 'Aura disagreed with the OS about camera permission');
    });
  });

  group('ANDROID · recovery language is Android language', () {
    testWidgets('a denial names Android settings, never a browser',
        (tester) async {
      // THE MEASURED DEFECT: "Check your browser permissions" shipped to a
      // platform with no browser.
      const denied = DeviceReadiness(
        kind: MediaDeviceKind.camera,
        state: DevicePermissionState.denied,
      );
      final text = denied.recovery!;
      expect(text.toLowerCase(), isNot(contains('browser')));
      if (isAndroid) {
        expect(text, contains('Settings'));
        expect(text, contains('Apps'),
            reason: 'Android recovery must name the Android path');
      }
    });

    testWidgets('a permanent denial reads differently and needs settings',
        (tester) async {
      const permanent = DeviceReadiness(
        kind: MediaDeviceKind.microphone,
        state: DevicePermissionState.permanentlyDenied,
      );
      const plain = DeviceReadiness(
        kind: MediaDeviceKind.microphone,
        state: DevicePermissionState.denied,
      );
      expect(permanent.summary, isNot(plain.summary));
      expect(permanent.needsSettingsTrip, isTrue);
      expect(permanent.recovery!.toLowerCase(), isNot(contains('browser')));
    });

    testWidgets('a policy restriction does not send anyone to settings',
        (tester) async {
      const restricted = DeviceReadiness(
        kind: MediaDeviceKind.camera,
        state: DevicePermissionState.restricted,
      );
      expect(restricted.needsSettingsTrip, isFalse);
      expect(restricted.recovery, contains('cannot be changed from Aura'));
    });
  });

  group('ANDROID · degraded participation is allowed and described', () {
    testWidgets('a refusal never bars joining', (tester) async {
      const bothRefused = MediaReadiness(
        microphone: DeviceReadiness(
          kind: MediaDeviceKind.microphone,
          state: DevicePermissionState.permanentlyDenied,
        ),
        camera: DeviceReadiness(
          kind: MediaDeviceKind.camera,
          state: DevicePermissionState.denied,
        ),
      );
      expect(bothRefused.canJoin, isTrue,
          reason: 'listening is a legitimate way to attend');
      // ...but the product must say what is actually true.
      expect(bothRefused.isFullyReady, isFalse);
      expect(bothRefused.primaryConcern?.kind, MediaDeviceKind.microphone,
          reason: 'being unheard outranks being unseen');
    });

    testWidgets('an audio call never reports the camera as refused',
        (tester) async {
      // A voice call must not ask for a camera, and must not then describe
      // the camera it never wanted as a problem.
      final readiness = CallReadiness(wantsCamera: false);
      await readiness.check(requestPermission: false);
      expect(readiness.readiness.camera.state,
          DevicePermissionState.notRequested);
      readiness.dispose();
    });

    testWidgets('control announcements match capability, not just state',
        (tester) async {
      const refused = DeviceReadiness(
        kind: MediaDeviceKind.camera,
        state: DevicePermissionState.permanentlyDenied,
      );
      final text =
          MediaControlLabels.cameraSemantics(on: false, readiness: refused);
      expect(text, contains('unavailable'));
      expect(text, isNot(contains('activate to')),
          reason: 'it promised an action it cannot perform');
    });
  });

  group('ANDROID · the preflight, on the handset', () {
    Future<void> openPreflight(
      WidgetTester tester, {
      required bool wantsCamera,
      bool? result,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await CallPreflightSheet.show(
                      context,
                      title: 'Call Ada Lovelace',
                      subtitle: wantsCamera
                          ? 'They will be able to see and hear you.'
                          : 'They will be able to hear you.',
                      wantsCamera: wantsCamera,
                    );
                  },
                  child: const Text('call'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('call'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('it opens, names who is being called, and offers a way out',
        (tester) async {
      await openPreflight(tester, wantsCamera: false);
      // Section 13: governed identity, never "User" or "Someone".
      expect(find.text('Call Ada Lovelace'), findsOneWidget);
      expect(find.text('They will be able to hear you.'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Call Ada Lovelace'), findsNothing);
    });

    testWidgets('its controls meet Android touch-target size', (tester) async {
      await openPreflight(tester, wantsCamera: false);
      for (final label in ['Not now', 'Start call']) {
        final finder = find.text(label);
        if (finder.evaluate().isEmpty) continue;
        final size = tester.getSize(
          find.ancestor(of: finder, matching: find.byType(Padding)).first,
        );
        expect(size.height, greaterThanOrEqualTo(40.0),
            reason: '$label is too small to hit reliably on a phone');
      }
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('device state is announced, not just drawn', (tester) async {
      final handle = tester.ensureSemantics();
      await openPreflight(tester, wantsCamera: false);
      // The microphone line must carry a spoken state; colour and icon alone
      // are what section 34 forbids.
      expect(
        find.bySemanticsLabel(RegExp('[Mm]icrophone')),
        findsWidgets,
        reason: 'the microphone state was not announced',
      );
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      handle.dispose();
    });

    testWidgets('it composes without overflow on this screen', (tester) async {
      await openPreflight(tester, wantsCamera: true);
      expect(tester.takeException(), isNull,
          reason: 'the preflight overflowed on a real phone viewport');
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('ANDROID · lifecycle and cleanup', () {
    testWidgets('backgrounding and returning does not break the preflight',
        (tester) async {
      final readiness = CallReadiness(wantsCamera: false);
      await readiness.check(requestPermission: false);

      // Android pause/resume, as the OS delivers it.
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 300));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // Re-entry must re-answer the question rather than trust a stale answer.
      await readiness.check(requestPermission: false);
      expect(readiness.hasChecked, isTrue);
      readiness.dispose();
    });

    testWidgets('disposing DURING a check does not explode or leak',
        (tester) async {
      // FOUND ON THIS HANDSET, 2026-08-25. check() is async and on Android it
      // is genuinely slow — a permission request plus a real device open.
      // Dismissing the preflight while it runs disposed the notifier, and the
      // continuation then called notifyListeners() on a dead object. Windows
      // never exposed it: its check returns almost instantly, so there is no
      // window to be dismissed in.
      final readiness = CallReadiness(wantsCamera: false);
      final inflight = readiness.check(requestPermission: false);
      readiness.dispose();
      await inflight;
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: 'a preflight dismissed mid-check threw');
      // And whatever the check opened must still have been handed back.
      expect(readiness.preview, isNull,
          reason: 'the camera stayed open after dismissal');
    });

    testWidgets('releasing the preview is idempotent and leaves nothing open',
        (tester) async {
      // Section 17: leaving must release devices. Called twice because a
      // dismiss followed by a dispose is the real sequence.
      final readiness = CallReadiness(wantsCamera: false);
      await readiness.check(requestPermission: false);
      await readiness.releasePreview();
      await readiness.releasePreview();
      expect(readiness.preview, isNull);
      readiness.dispose();
      expect(tester.takeException(), isNull);
    });

    testWidgets('system Back closes the preflight without starting anything',
        (tester) async {
      bool? outcome;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    outcome = await CallPreflightSheet.show(
                      context,
                      title: 'Call Ada Lovelace',
                      subtitle: 'They will be able to hear you.',
                      wantsCamera: false,
                    );
                  },
                  child: const Text('call'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('call'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Call Ada Lovelace'), findsOneWidget);

      // The Android system Back gesture.
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          const MethodCall('popRoute'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Call Ada Lovelace'), findsNothing);
      // THE INVARIANT: dismissing must never read as "proceed".
      expect(outcome, isNot(true),
          reason: 'system Back was treated as consent to start a call');
    });
  });

  group('ANDROID · the ordering invariant', () {
    // CALL INTENT → PREFLIGHT → READINESS → USER PROCEEDS → SESSION CREATED
    //             → OTHER PARTY RUNG
    //
    // `startLive()` is the single act that both creates the session and rings
    // the recipient. It must be unreachable until the preflight has resolved
    // AND the person has chosen to proceed.
    testWidgets('dismissal yields a non-proceed answer', (tester) async {
      bool? outcome;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    outcome = await CallPreflightSheet.show(
                      context,
                      title: 'Call Ada Lovelace',
                      subtitle: 'They will be able to hear you.',
                      wantsCamera: false,
                    );
                  },
                  child: const Text('call'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('call'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(outcome, isFalse,
          reason: 'a caller who backed out would still have rung somebody');
    });
  });
}
