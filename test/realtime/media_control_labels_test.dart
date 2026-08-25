import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/device_permission.dart';
import 'package:aura/core/media/media_control_labels.dart';

/// CALL CONTROLS SAY WHAT THEY DO — A/V reconstruction §18 and §34.
///
/// The measured defect, in the released in-call dock:
///
///     label: cameraOn ? 'Camera' : 'Camera off'
///
/// The ON state named the *thing*, not its state or its effect, while the
/// microphone beside it named the *action* ('Mute' / 'Unmute'). Two controls,
/// side by side, two grammars, one of which told you nothing about what
/// pressing it would do.
///
/// Neither carried any `Semantics`, so a screen reader received the visible
/// word and nothing more — "Camera" — with the actual state carried only by
/// icon and colour.
void main() {
  group('the visible label names the effect, consistently', () {
    test('camera and microphone use the SAME grammar', () {
      // Both must describe what pressing does, not what the control is.
      expect(MediaControlLabels.cameraAction(on: true), 'Turn off');
      expect(MediaControlLabels.cameraAction(on: false), 'Turn on');
      expect(MediaControlLabels.microphoneAction(on: true), 'Mute');
      expect(MediaControlLabels.microphoneAction(on: false), 'Unmute');
    });

    test('no state renders the bare noun "Camera"', () {
      for (final on in [true, false]) {
        expect(MediaControlLabels.cameraAction(on: on), isNot('Camera'));
        expect(MediaControlLabels.cameraAction(on: on), isNot('Camera off'));
      }
    });

    test('the two states never read the same', () {
      expect(MediaControlLabels.cameraAction(on: true),
          isNot(MediaControlLabels.cameraAction(on: false)));
      expect(MediaControlLabels.microphoneAction(on: true),
          isNot(MediaControlLabels.microphoneAction(on: false)));
    });
  });

  group('the announcement carries thing, state AND effect', () {
    test('camera announces all three', () {
      final on = MediaControlLabels.cameraSemantics(on: true);
      expect(on, contains('Camera'));
      expect(on, contains('on'));
      expect(on, contains('turn camera off'));

      final off = MediaControlLabels.cameraSemantics(on: false);
      expect(off, contains('off'));
      expect(off, contains('turn camera on'));
      expect(on, isNot(off));
    });

    test('microphone announces all three, and muted is said as muted', () {
      final live = MediaControlLabels.microphoneSemantics(on: true);
      final muted = MediaControlLabels.microphoneSemantics(on: false);
      expect(live, contains('Microphone'));
      expect(live, contains('mute'));
      expect(muted, contains('muted'));
      expect(muted, contains('unmute'));
      expect(live, isNot(muted));
    });
  });

  group('a control that cannot work does not promise it will', () {
    test('an unusable device announces WHY instead of offering the action',
        () {
      // Announcing "activate to turn camera on" at somebody whose camera was
      // permanently refused is a promise the product cannot keep.
      const refused = DeviceReadiness(
        kind: MediaDeviceKind.camera,
        state: DevicePermissionState.permanentlyDenied,
      );
      final text =
          MediaControlLabels.cameraSemantics(on: false, readiness: refused);
      expect(text, contains('unavailable'));
      expect(text, contains(refused.summary));
      expect(text, isNot(contains('activate to')));
    });

    test('a device that was simply never asked about still offers the action',
        () {
      // "Not requested" is not a failure, and must not be presented as one.
      const unasked = DeviceReadiness.unknown(MediaDeviceKind.camera);
      final text =
          MediaControlLabels.cameraSemantics(on: false, readiness: unasked);
      expect(text, contains('activate to turn camera on'));
    });

    test('a granted device behaves exactly as with no readiness supplied', () {
      const granted = DeviceReadiness(
        kind: MediaDeviceKind.microphone,
        state: DevicePermissionState.granted,
      );
      expect(
        MediaControlLabels.microphoneSemantics(on: true, readiness: granted),
        MediaControlLabels.microphoneSemantics(on: true),
      );
    });
  });
}
