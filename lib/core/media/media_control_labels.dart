import 'device_permission.dart';

/// WHAT A CAMERA BUTTON SAYS — founder ruling, A/V reconstruction §18 and §34.
///
/// The measured defect: the in-call camera control read
///
///     label: cameraOn ? 'Camera' : 'Camera off'
///
/// so its ON state named the *thing* rather than its state or its effect,
/// while the microphone beside it named the *action* ('Mute' / 'Unmute').
/// Two controls, side by side, using two different grammars, one of which
/// says nothing at all about what pressing it will do.
///
/// Neither carried any `Semantics`, so a screen reader was given the visible
/// word and nothing else: "Camera" — on or off, no way to tell which, and no
/// statement of what activating it achieves.
///
/// This is the shared vocabulary. It lives in core rather than in Meetings
/// because the A/V system must not depend on Meetings' presentation layer to
/// name its own controls (§2, §43).
class MediaControlLabels {
  const MediaControlLabels._();

  /// The short word under the button. Names the EFFECT of pressing it, which
  /// is what a button label is for, and matches the microphone's grammar.
  static String cameraAction({required bool on}) =>
      on ? 'Turn off' : 'Turn on';

  static String microphoneAction({required bool on}) => on ? 'Mute' : 'Unmute';

  /// What a screen reader hears: the thing, its current state, and what
  /// pressing it will do. All three, because a control that announces only
  /// its name cannot be operated without sight.
  static String cameraSemantics({
    required bool on,
    DeviceReadiness? readiness,
  }) =>
      _semantics(
        thing: 'Camera',
        on: on,
        onWord: 'on',
        offWord: 'off',
        turnOn: 'turn camera on',
        turnOff: 'turn camera off',
        readiness: readiness,
      );

  static String microphoneSemantics({
    required bool on,
    DeviceReadiness? readiness,
  }) =>
      _semantics(
        thing: 'Microphone',
        on: on,
        onWord: 'on',
        offWord: 'muted',
        turnOn: 'unmute',
        turnOff: 'mute',
        readiness: readiness,
      );

  static String _semantics({
    required String thing,
    required bool on,
    required String onWord,
    required String offWord,
    required String turnOn,
    required String turnOff,
    DeviceReadiness? readiness,
  }) {
    // A control that cannot work must say so instead of offering an action it
    // will not perform. Announcing "double tap to turn camera on" at somebody
    // whose camera was refused is a promise the product cannot keep.
    if (readiness != null &&
        !readiness.isUsable &&
        readiness.state != DevicePermissionState.notRequested) {
      return '$thing unavailable. ${readiness.summary}';
    }
    return on
        ? '$thing $onWord, activate to $turnOff'
        : '$thing $offWord, activate to $turnOn';
  }
}
