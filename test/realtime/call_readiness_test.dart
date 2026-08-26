import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/device_permission.dart';

/// THE PERMISSION MODEL — founder ruling, A/V reconstruction §7.
///
/// The ruling requires the states to be distinguished, not collapsed:
/// NOT_REQUESTED, GRANTED, DENIED, PERMANENTLY_DENIED / RESTRICTED,
/// DEVICE_UNAVAILABLE, DEVICE_BUSY, OS_POLICY_RESTRICTED, UNKNOWN / ERROR.
///
/// Two of those did not exist before this chapter. These tests pin the whole
/// set, and — more usefully — pin the RECOVERY each one implies, because the
/// measured defect was never that the states were wrong. It was that one
/// sentence was shown for all of them, and that sentence named a browser on
/// three platforms that do not have one.
void main() {
  DeviceReadiness camera(DevicePermissionState state) =>
      DeviceReadiness(kind: MediaDeviceKind.camera, state: state);
  DeviceReadiness mic(DevicePermissionState state) =>
      DeviceReadiness(kind: MediaDeviceKind.microphone, state: state);

  group('every state the ruling names exists and is distinct', () {
    test('a permanent refusal is not the same state as a refusal', () {
      // They differ in the only way that matters: a plain denial may re-prompt,
      // a permanent one never will, so only one of them makes "try again" a
      // lie.
      expect(DevicePermissionState.values,
          contains(DevicePermissionState.permanentlyDenied));
      expect(camera(DevicePermissionState.denied).summary,
          isNot(camera(DevicePermissionState.permanentlyDenied).summary));
    });

    test('"could not tell" exists and is NOT reported as a refusal', () {
      // Accusing somebody of refusing access they never refused is worse than
      // admitting the check did not work.
      expect(DevicePermissionState.values, contains(DevicePermissionState.unknown));
      final unknown = camera(DevicePermissionState.unknown);
      expect(unknown.summary.toLowerCase(), isNot(contains('refused')));
      expect(unknown.summary.toLowerCase(), isNot(contains('denied')));
    });

    test('every state says something, and no two say the same thing', () {
      final said = <String>{};
      for (final state in DevicePermissionState.values) {
        final text = camera(state).summary;
        expect(text.trim(), isNotEmpty, reason: '$state says nothing');
        expect(said.add(text), isTrue,
            reason: '$state cannot be told apart from another state');
      }
    });
  });

  group('recovery matches the actual problem', () {
    test('a busy device is not sent to settings — closing the app fixes it',
        () {
      final busy = camera(DevicePermissionState.inUse);
      expect(busy.needsSettingsTrip, isFalse);
      expect(busy.recovery, contains('Close the other app'));
      expect(busy.canRetryInApp, isTrue);
    });

    test('a policy restriction does not tell somebody to change what they cannot',
        () {
      final restricted = mic(DevicePermissionState.restricted);
      expect(restricted.recovery, contains('cannot be changed from Aura'));
      expect(restricted.needsSettingsTrip, isFalse,
          reason: 'settings offers no such control under policy restriction');
    });

    test('a missing device offers no fix, because there is none', () {
      final absent = camera(DevicePermissionState.unavailable);
      expect(absent.needsSettingsTrip, isFalse);
      expect(absent.canRetryInApp, isFalse);
      expect(absent.recovery, contains('join without it'));
    });

    test('only a refusal — of either kind — sends anyone to settings', () {
      for (final state in DevicePermissionState.values) {
        final expected = state == DevicePermissionState.denied ||
            state == DevicePermissionState.permanentlyDenied;
        expect(camera(state).needsSettingsTrip, expected, reason: '$state');
      }
    });

    test('nothing is said when nothing is wrong', () {
      expect(camera(DevicePermissionState.granted).recovery, isNull);
      expect(camera(DevicePermissionState.notRequested).recovery, isNull,
          reason: 'the product scolded somebody before it had asked');
    });

    test('"could not tell" offers a retry, not an accusation', () {
      final unknown = mic(DevicePermissionState.unknown);
      expect(unknown.canRetryInApp, isTrue);
      expect(unknown.recovery, isNotNull);
    });
  });

  group('no recovery instruction names a browser off the web', () {
    test('the denial instruction is platform-shaped', () {
      // THE MEASURED DEFECT: "Check your browser permissions" was shown on
      // Android, iOS and Windows. In the test environment defaultTargetPlatform
      // is not web, so the instruction must name a real settings path.
      final text = camera(DevicePermissionState.denied).recovery!;
      expect(text.toLowerCase(), isNot(contains('browser')));
      expect(text.toLowerCase(), contains('settings'));
    });

    test('a permanent refusal gives the same actionable path', () {
      final text = mic(DevicePermissionState.permanentlyDenied).recovery!;
      expect(text.toLowerCase(), contains('settings'));
    });
  });

  group('readiness ranks by consequence', () {
    test('being unheard outranks being unseen', () {
      const readiness = MediaReadiness(
        microphone: DeviceReadiness(
          kind: MediaDeviceKind.microphone,
          state: DevicePermissionState.permanentlyDenied,
        ),
        camera: DeviceReadiness(
          kind: MediaDeviceKind.camera,
          state: DevicePermissionState.unavailable,
        ),
      );
      expect(readiness.primaryConcern?.kind, MediaDeviceKind.microphone);
    });

    test('a call is joinable even when both were refused', () {
      // Listening is a legitimate way to attend; refusing entry would be worse
      // than joining silent and dark.
      const refused = MediaReadiness(
        microphone: DeviceReadiness(
          kind: MediaDeviceKind.microphone,
          state: DevicePermissionState.denied,
        ),
        camera: DeviceReadiness(
          kind: MediaDeviceKind.camera,
          state: DevicePermissionState.denied,
        ),
      );
      expect(refused.canJoin, isTrue);
    });
  });

  group('the preflight fits the screen it is shown on', () {
    // FOUND BY USING IT — 2026-08-25, starting a real call from a 1512x812
    // browser window: the self-preview plus header and device lines pushed
    // "Start video call" and "Not now" off the bottom, and the sheet could not
    // scroll to reach them. The call could not be started and the sheet could
    // not be dismissed by any visible control.
    //
    // It fitted on the Pixel's tall screen, which is exactly why a phone-only
    // check would have missed it.
    test('the sheet is bounded and its content scrolls', () {
      final src = File(
        'lib/core/media/call_preflight_sheet.dart',
      ).readAsStringSync();
      expect(src, contains('maxHeight: maxSheet'),
          reason: 'the sheet is unbounded again and can exceed the viewport');
      expect(src, contains('SingleChildScrollView'),
          reason: 'the content cannot scroll, so anything overflowing is lost');
      expect(src, contains('height: previewHeight'),
          reason: 'the preview is uncapped and can crowd out the actions');
      // Asserted on the values rather than the formatting: dart format wraps
      // the clamp across lines.
      expect(src, contains('previewHeight'));
      expect(src, contains('120.0'),
          reason: 'the preview lower bound is gone');
      expect(src, contains('240.0'),
          reason: 'the preview cap is gone; ConstrainedBox around AspectRatio '
              'did NOT clamp in practice, which is why it is a fixed height');
    });

    test('the decision controls stay OUTSIDE the scrollable', () {
      // A control that decides whether to start a call must not be able to
      // scroll away — that is the same defect wearing a scrollbar.
      final src = File(
        'lib/core/media/call_preflight_sheet.dart',
      ).readAsStringSync();
      final scrollEnd = src.indexOf('const SizedBox(height: AuraSpace.s20),',
          src.indexOf('SingleChildScrollView'));
      final notNow = src.indexOf("'Not now'");
      final confirm = src.indexOf('widget.confirmLabel');
      expect(notNow, greaterThan(scrollEnd),
          reason: 'the cancel control moved inside the scrollable');
      expect(confirm, greaterThan(scrollEnd),
          reason: 'the confirm control moved inside the scrollable');
    });
  });
}
