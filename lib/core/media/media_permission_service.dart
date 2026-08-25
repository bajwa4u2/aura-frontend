import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'device_permission.dart';

/// THE ONE PLACE AURA ASKS FOR A CAMERA OR A MICROPHONE.
///
/// Founder ruling, A/V reconstruction §6 and §7. The measured state before
/// this existed:
///
/// * no `permission_handler` dependency at all, so nothing could ask what the
///   current permission state *was* — only trigger the OS prompt as a side
///   effect of `getUserMedia`, mid-join, with no explanation beforehand;
/// * no way to tell a refusal apart from a permanent refusal, and so no way
///   to offer the only recovery that works for the latter — app settings;
/// * `classifyMediaError` and [DevicePermissionState] existed but were
///   consumed by exactly one Meetings widget; the media engine itself hardcoded
///   browser-flavoured strings and told Windows and Android people to check
///   "this browser".
///
/// ## Why this is platform-split rather than one implementation
///
/// The platforms genuinely differ, and pretending otherwise is how the
/// browser-flavoured copy got shipped in the first place:
///
/// * **Android / iOS** have a real permission system that can be queried
///   before asking, can report a permanent denial, and can be sent to a
///   settings page. `permission_handler` is used there and nowhere else.
/// * **Web** has no queryable permission API that is reliable across browsers
///   (`navigator.permissions.query({name:'camera'})` is not universally
///   supported), and no concept of "open app settings". The only honest
///   answer is: we do not know until we ask, and asking IS `getUserMedia`.
/// * **Windows / macOS / Linux** grant device access at the OS level outside
///   the app's control. `getUserMedia` either works or reports why.
///
/// So the *product* question — "may I use the camera, and if not what can this
/// person do about it" — is answered uniformly; the *mechanism* is not
/// pretended to be uniform.
class MediaPermissionService {
  const MediaPermissionService();

  /// Whether this platform has a permission system that can be asked about a
  /// permission separately from using the device.
  static bool get hasQueryablePermissions =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether this platform can send someone to a settings page that fixes a
  /// permanent denial. Only true where such a page exists AND we can open it.
  static bool get canOpenSettings => hasQueryablePermissions;

  /// What the current state is, WITHOUT asking for anything.
  ///
  /// On platforms with no queryable permission system this returns
  /// [DevicePermissionState.notRequested] — which is honest: nothing has been
  /// asked, and nothing can be known until it is. It must NOT be reported as
  /// "granted", because a preflight that claims readiness it has not verified
  /// is worse than one that admits it does not know yet.
  Future<DevicePermissionState> status(MediaDeviceKind kind) async {
    if (!hasQueryablePermissions) return DevicePermissionState.notRequested;
    try {
      return _fromPlugin(await _permission(kind).status);
    } catch (_) {
      return DevicePermissionState.unknown;
    }
  }

  /// Ask for the permission, and report what the answer actually was.
  ///
  /// This is the explicit ask the audit found missing. On Android/iOS it is a
  /// real permission request that happens when the product decides to make it,
  /// not as an accident of acquiring media.
  Future<DevicePermissionState> request(MediaDeviceKind kind) async {
    if (!hasQueryablePermissions) {
      // The ask and the use are the same act here. The caller performs it via
      // getUserMedia and classifies the outcome with `classifyMediaError`.
      return DevicePermissionState.notRequested;
    }
    try {
      return _fromPlugin(await _permission(kind).request());
    } catch (_) {
      return DevicePermissionState.unknown;
    }
  }

  /// Ask for both, in one pass, so a person sees at most two system prompts
  /// back to back rather than one now and another after they have already
  /// committed to joining.
  Future<Map<MediaDeviceKind, DevicePermissionState>> requestBoth({
    required bool camera,
    required bool microphone,
  }) async {
    final result = <MediaDeviceKind, DevicePermissionState>{};
    if (!hasQueryablePermissions) {
      if (microphone) {
        result[MediaDeviceKind.microphone] = DevicePermissionState.notRequested;
      }
      if (camera) {
        result[MediaDeviceKind.camera] = DevicePermissionState.notRequested;
      }
      return result;
    }
    try {
      final requested = <ph.Permission>[
        if (microphone) ph.Permission.microphone,
        if (camera) ph.Permission.camera,
      ];
      if (requested.isEmpty) return result;
      final statuses = await requested.request();
      statuses.forEach((permission, status) {
        final kind = permission == ph.Permission.camera
            ? MediaDeviceKind.camera
            : MediaDeviceKind.microphone;
        result[kind] = _fromPlugin(status);
      });
    } catch (_) {
      if (microphone) result[MediaDeviceKind.microphone] = DevicePermissionState.unknown;
      if (camera) result[MediaDeviceKind.camera] = DevicePermissionState.unknown;
    }
    return result;
  }

  /// Open the place where a permanent denial can actually be undone.
  ///
  /// Returns false where no such place exists — the caller must not offer this
  /// as an action in that case, because an affordance that does nothing is
  /// worse than none. See [canOpenSettings].
  Future<bool> openSettings() async {
    if (!canOpenSettings) return false;
    try {
      return await ph.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Devices this platform can actually see.
  ///
  /// Labels are frequently empty before permission is granted — that is a
  /// browser privacy rule, not a bug — so a device picker built on this must
  /// tolerate unnamed devices rather than showing blanks.
  Future<List<MediaDeviceInfo>> enumerate() async {
    try {
      return await navigator.mediaDevices.enumerateDevices();
    } catch (_) {
      return const [];
    }
  }

  ph.Permission _permission(MediaDeviceKind kind) =>
      kind == MediaDeviceKind.camera ? ph.Permission.camera : ph.Permission.microphone;

  DevicePermissionState _fromPlugin(ph.PermissionStatus status) {
    // `permanentlyDenied` and `restricted` are deliberately NOT collapsed:
    // one is a choice the person can reverse in settings, the other is a
    // policy they cannot change from inside Aura at all, and telling someone
    // to go change a setting they are forbidden to change is its own defect.
    if (status.isGranted || status.isLimited) return DevicePermissionState.granted;
    if (status.isPermanentlyDenied) return DevicePermissionState.permanentlyDenied;
    if (status.isRestricted) return DevicePermissionState.restricted;
    if (status.isDenied) return DevicePermissionState.denied;
    return DevicePermissionState.unknown;
  }
}
