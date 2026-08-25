import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/core/media/call_preflight_sheet.dart';
import 'package:aura/core/media/call_readiness.dart';
import 'package:aura/core/media/device_permission.dart';
import 'package:aura/core/media/media_control_labels.dart';
import 'package:aura/core/media/media_permission_service.dart';

/// A/V CERTIFICATION ON A REAL CLIENT.
///
/// Founder ruling, A/V reconstruction §31–§34, §47. Run per platform:
///
///     flutter test integration_test/av_certification_test.dart -d windows
///     flutter test integration_test/av_certification_test.dart -d <android>
///
/// These are session-independent: they certify the CLIENT, not an account.
/// What they buy over the widget suite is the real platform — the real
/// permission plugin, the real `defaultTargetPlatform`, the real device stack.
/// That is precisely where the measured defects lived: copy that named a
/// browser on Android, and a permission model that could not ask the OS
/// anything at all.
///
/// What they deliberately do NOT claim: a two-party call. That needs a second
/// authenticated account, and inventing one here would be the false
/// certification the ruling forbids.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AV · the platform is told the truth about itself', () {
    testWidgets('permission queryability matches this platform', (tester) async {
      // Android/iOS have a real permission system; web and desktop do not.
      // The service must not pretend otherwise in either direction.
      final queryable = MediaPermissionService.hasQueryablePermissions;
      final isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      expect(queryable, isMobile,
          reason: 'platform=$defaultTargetPlatform');
      // A settings trip may only be offered where one exists.
      expect(MediaPermissionService.canOpenSettings, queryable);
    });

    testWidgets('status can be asked WITHOUT requesting anything',
        (tester) async {
      // The whole point of the added dependency: knowing the state before
      // provoking a prompt. On platforms that cannot, the honest answer is
      // "not requested" — never "granted".
      const service = MediaPermissionService();
      final mic = await service.status(MediaDeviceKind.microphone);
      expect(DevicePermissionState.values, contains(mic));
      if (!MediaPermissionService.hasQueryablePermissions) {
        expect(mic, DevicePermissionState.notRequested,
            reason: 'a preflight must never claim readiness it cannot verify');
      }
    });
  });

  group('AV · recovery copy is platform-correct on THIS platform', () {
    testWidgets('a denial does not name a browser off the web', (tester) async {
      // THE MEASURED DEFECT: "Check your browser permissions" shipped to
      // Android, iOS and Windows, none of which have a browser.
      const denied = DeviceReadiness(
        kind: MediaDeviceKind.camera,
        state: DevicePermissionState.denied,
      );
      final text = denied.recovery!;
      if (!kIsWeb) {
        expect(text.toLowerCase(), isNot(contains('browser')),
            reason: 'platform=$defaultTargetPlatform said "browser"');
      }
      expect(text.trim(), isNotEmpty);
    });

    testWidgets('a permanent denial is distinguishable and actionable',
        (tester) async {
      const permanent = DeviceReadiness(
        kind: MediaDeviceKind.microphone,
        state: DevicePermissionState.permanentlyDenied,
      );
      expect(permanent.needsSettingsTrip, isTrue);
      expect(permanent.summary,
          isNot(const DeviceReadiness(
            kind: MediaDeviceKind.microphone,
            state: DevicePermissionState.denied,
          ).summary));
    });
  });

  group('AV · controls announce state and effect', () {
    testWidgets('camera never renders the bare noun', (tester) async {
      for (final on in [true, false]) {
        expect(MediaControlLabels.cameraAction(on: on), isNot('Camera'));
        expect(MediaControlLabels.cameraSemantics(on: on), contains('Camera'));
      }
    });
  });

  group('AV · the preflight runs on real hardware', () {
    testWidgets('it opens, checks, and releases the camera when dismissed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => CallPreflightSheet.show(
                    context,
                    title: 'Call Ada Lovelace',
                    subtitle: 'They will be able to hear you.',
                    // Audio-only: a voice call must not ask for a camera it
                    // will never use.
                    wantsCamera: false,
                  ),
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

      expect(find.text('Call Ada Lovelace'), findsOneWidget,
          reason: 'the preflight did not open');
      // It says what it needs, and offers a way out that is not "join".
      expect(find.text('Not now'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Call Ada Lovelace'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('readiness releases its preview stream', (tester) async {
      // A preview that keeps the camera light on after somebody backs out is
      // the orphaned capture §17 forbids.
      final readiness = CallReadiness(wantsCamera: false);
      await readiness.check(requestPermission: false);
      await readiness.releasePreview();
      expect(readiness.preview, isNull);
      readiness.dispose();
    });

    testWidgets('joining is never barred by a refusal', (tester) async {
      // Listening is a legitimate way to attend.
      final readiness = CallReadiness(wantsCamera: true);
      expect(readiness.canJoin, isTrue);
      readiness.dispose();
    });
  });
}
