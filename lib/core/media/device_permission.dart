/// CAMERA AND MICROPHONE READINESS — ONE CLASSIFICATION, EVERY PLATFORM.
///
/// Founder ruling 2026-08-25 §IX. The audit reported that no native
/// camera/microphone permission handling existed anywhere in the client. That
/// was half right, and the accurate half matters: the **declarations** are all
/// present — Android's manifest carries `CAMERA` and `RECORD_AUDIO`, iOS's
/// `Info.plist` carries both usage strings — and `flutter_webrtc` triggers the
/// platform's own runtime prompt when a stream is requested.
///
/// What did not exist is the part a person experiences. Every failure path
/// collapsed into one sentence:
///
///     "Camera and microphone are unavailable. Check your browser permissions."
///
/// shown identically when the person had **denied** access, when the camera was
/// **already in use by another app**, when the device had **no camera at all**,
/// and when the page was served over an **insecure origin**. It also said
/// "browser" on Android, iOS and Windows, where there is no browser. Four
/// different problems, three of them recoverable in three different ways, and
/// one instruction that was wrong for most of them.
///
/// §XXXI: *avoid generic "Try again" when a domain-specific recovery action
/// exists*. §IX: *do not fake permission success in UI*. This file is how both
/// are kept.
library;

import 'package:flutter/foundation.dart';

/// What the platform told us about a device we asked for.
enum DevicePermissionState {
  /// Never asked. On every platform this is the state before the first
  /// request, and it is NOT the same as denied — the honest thing to show is
  /// an invitation to continue, not an error.
  notRequested,

  /// Asked, and allowed.
  granted,

  /// Asked, and refused. Recoverable, but only by the person, outside Aura.
  denied,

  /// Refused by policy rather than by the person — a managed device, a
  /// parental restriction, an insecure origin. Telling somebody to "allow it
  /// in settings" here would send them somewhere that offers no such control.
  restricted,

  /// The hardware is not there.
  unavailable,

  /// The hardware is there and something else has it.
  inUse,
}

/// Which device we are talking about.
enum MediaDeviceKind { microphone, camera }

/// The readiness of one device, with the recovery that actually applies.
@immutable
class DeviceReadiness {
  const DeviceReadiness({
    required this.kind,
    required this.state,
  });

  final MediaDeviceKind kind;
  final DevicePermissionState state;

  const DeviceReadiness.unknown(this.kind)
      : state = DevicePermissionState.notRequested;

  bool get isUsable => state == DevicePermissionState.granted;

  /// Whether asking again could plausibly work. A denial cannot be re-prompted
  /// on most platforms once it is remembered, so offering "try again" there is
  /// the generic-retry defect §XXXI names.
  bool get canRetryInApp =>
      state == DevicePermissionState.notRequested ||
      state == DevicePermissionState.inUse;

  String get deviceLabel =>
      kind == MediaDeviceKind.camera ? 'Camera' : 'Microphone';

  String get _lowerLabel =>
      kind == MediaDeviceKind.camera ? 'camera' : 'microphone';

  /// What happened, said plainly and without blame.
  String get summary => switch (state) {
        DevicePermissionState.granted => '$deviceLabel ready',
        DevicePermissionState.notRequested =>
          '$deviceLabel not checked yet',
        DevicePermissionState.denied => '$deviceLabel access was refused',
        DevicePermissionState.restricted =>
          '$deviceLabel access is blocked on this device',
        DevicePermissionState.unavailable => 'No $_lowerLabel found',
        DevicePermissionState.inUse =>
          'Your $_lowerLabel is being used by another app',
      };

  /// What to do about it — platform-correct, and specific enough to act on.
  ///
  /// Returns null when there is nothing for the person to do, which is itself
  /// information: it means the product should stop talking and let them
  /// continue.
  String? get recovery => switch (state) {
        DevicePermissionState.granted => null,
        DevicePermissionState.notRequested => null,
        DevicePermissionState.denied => _deniedRecovery,
        DevicePermissionState.restricted =>
          'This is set by your device or organisation, so it cannot be '
              'changed from Aura. You can still join with your $_lowerLabel off.',
        DevicePermissionState.unavailable =>
          'You can join without it — others will still hear and see you if '
              'your other devices are working.',
        DevicePermissionState.inUse =>
          'Close the other app using your $_lowerLabel, then try again.',
      };

  /// The denial instruction is the one that was most wrong before: it named
  /// the browser on three platforms that do not have one.
  String get _deniedRecovery {
    if (kDebugMode || !kIsWeb) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return 'Open Settings › Apps › Aura › Permissions and allow the '
              '$_lowerLabel, then come back.';
        case TargetPlatform.iOS:
          return 'Open Settings › Aura and allow the $_lowerLabel, then come '
              'back.';
        case TargetPlatform.windows:
          return 'Open Windows Settings › Privacy & security › $deviceLabel '
              'and allow desktop apps to use it.';
        case TargetPlatform.macOS:
          return 'Open System Settings › Privacy & Security › $deviceLabel '
              'and allow Aura.';
        default:
          break;
      }
    }
    if (kIsWeb) {
      return 'Use the $_lowerLabel icon in your browser\'s address bar to '
          'allow access, then reload.';
    }
    return 'Allow $_lowerLabel access for Aura in your device settings, then '
        'come back.';
  }
}

/// Both devices, as a single answer the join experience can render.
@immutable
class MediaReadiness {
  const MediaReadiness({
    required this.microphone,
    required this.camera,
  });

  final DeviceReadiness microphone;
  final DeviceReadiness camera;

  static const MediaReadiness unchecked = MediaReadiness(
    microphone: DeviceReadiness.unknown(MediaDeviceKind.microphone),
    camera: DeviceReadiness.unknown(MediaDeviceKind.camera),
  );

  /// A meeting is joinable with no camera. It is not really joinable with no
  /// microphone — but Aura still lets people in, because listening is a
  /// legitimate way to attend and refusing entry would be worse.
  bool get canJoin => true;

  /// Whether anything needs saying at all.
  bool get isFullyReady => microphone.isUsable && camera.isUsable;

  /// The one thing most worth telling them, or null if all is well.
  ///
  /// Ordered by consequence: being unheard matters more than being unseen.
  DeviceReadiness? get primaryConcern {
    if (!microphone.isUsable &&
        microphone.state != DevicePermissionState.notRequested) {
      return microphone;
    }
    if (!camera.isUsable &&
        camera.state != DevicePermissionState.notRequested) {
      return camera;
    }
    return null;
  }

  MediaReadiness copyWith({
    DeviceReadiness? microphone,
    DeviceReadiness? camera,
  }) =>
      MediaReadiness(
        microphone: microphone ?? this.microphone,
        camera: camera ?? this.camera,
      );
}

/// TURN A MEDIA FAILURE INTO SOMETHING THE PRODUCT CAN SAY.
///
/// `getUserMedia` reports failures through error names that are stable across
/// browsers and are mirrored by `flutter_webrtc` on the native platforms. They
/// were previously read only by a `debugPrint` and a comment; this reads them
/// in code, which is the difference between a classification and a note.
///
/// Anything unrecognised becomes [DevicePermissionState.unavailable] rather
/// than a guess at denial — telling somebody they refused access when they did
/// not is worse than telling them the device did not work.
DevicePermissionState classifyMediaError(Object? error, {
  required MediaDeviceKind kind,
}) {
  final text = error?.toString() ?? '';
  if (text.isEmpty) return DevicePermissionState.unavailable;
  final lower = text.toLowerCase();

  // The person said no, or the platform remembers that they did.
  if (lower.contains('notallowed') ||
      lower.contains('permissiondenied') ||
      lower.contains('permission denied') ||
      lower.contains('denied by system') ||
      lower.contains('not authorized') ||
      lower.contains('notauthorized')) {
    return DevicePermissionState.denied;
  }

  // Policy, not preference — including an insecure origin, where no prompt
  // will ever appear no matter what the person does.
  if (lower.contains('security') ||
      lower.contains('restricted') ||
      lower.contains('insecure')) {
    return DevicePermissionState.restricted;
  }

  // Something else has the hardware open.
  if (lower.contains('notreadable') ||
      lower.contains('trackstart') ||
      lower.contains('could not start') ||
      lower.contains('in use') ||
      lower.contains('busy')) {
    return DevicePermissionState.inUse;
  }

  // There is no such device.
  if (lower.contains('notfound') ||
      lower.contains('devicesnotfound') ||
      lower.contains('overconstrained') ||
      lower.contains('no device')) {
    return DevicePermissionState.unavailable;
  }

  return DevicePermissionState.unavailable;
}
