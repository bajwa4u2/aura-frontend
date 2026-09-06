import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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
}
