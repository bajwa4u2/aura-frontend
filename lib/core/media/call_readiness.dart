import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'device_permission.dart';
import 'media_permission_service.dart';

/// AM I READY TO BE SEEN AND HEARD — asked once, answered the same way
/// everywhere.
///
/// Founder ruling, A/V reconstruction §6 and §8. What was measured before this
/// existed:
///
/// * **Meetings** had a real device check (`MeetingDeviceCheck`) that
///   classified failures properly.
/// * **Thread calls** had none at all. `realtime_lobby_screen.dart` never
///   touched permissions, devices or `getUserMedia` — a person went straight
///   from "call" to a room that would then fail, mid-join, with no warning.
/// * The **media engine** did its own third thing with hardcoded copy.
///
/// Three treatments of one question. §8: *shared capability should remain
/// shared*. This is the shared one; the surfaces differ only in presentation.
///
/// It is deliberately a plain [ChangeNotifier] holding no widgets, so the
/// readiness rules are testable without pumping a UI, which is where the
/// platform-specific mistakes actually live.
class CallReadiness extends ChangeNotifier {
  CallReadiness({
    MediaPermissionService permissions = const MediaPermissionService(),
    this.wantsCamera = true,
  }) : _permissions = permissions;

  final MediaPermissionService _permissions;

  /// A voice call does not need a camera, and must not ask for one. Asking for
  /// permissions a call will never use is how products train people to refuse.
  final bool wantsCamera;

  MediaReadiness _readiness = MediaReadiness.unchecked;
  MediaReadiness get readiness => _readiness;

  bool _checking = false;
  bool get checking => _checking;

  /// DISPOSED MID-CHECK.
  ///
  /// Found on a physical Pixel 9a, 2026-08-25: `check()` is asynchronous and
  /// on Android it is genuinely slow — a permission request plus a real device
  /// open. Dismissing the preflight while it is still running disposes this
  /// object, and the continuation then called `notifyListeners()` on a dead
  /// ChangeNotifier. Windows never exposed it because its check returns almost
  /// immediately; the race needs a device slow enough to be dismissed during.
  bool _disposed = false;

  /// True once a check has completed, whatever the answer. Surfaces use this
  /// to tell "not asked yet" apart from "asked and everything is fine" —
  /// which look identical if you only inspect the states.
  bool _hasChecked = false;
  bool get hasChecked => _hasChecked;

  MediaStream? _preview;

  /// The live local stream, for a self-view. Owned here and released by
  /// [releasePreview] or [dispose] — a preview that keeps the camera light on
  /// after someone backs out is the leak §17 forbids.
  MediaStream? get preview => _preview;

  /// Whether joining is possible at all. Deliberately permissive: listening is
  /// a legitimate way to attend, so a refused camera — or even a refused
  /// microphone — never bars entry. It only changes what is said.
  bool get canJoin => true;

  /// Whether anything is worth saying before joining.
  bool get isClear => _hasChecked && _readiness.isFullyReady;

  /// The single most consequential problem, or null.
  DeviceReadiness? get concern => _hasChecked ? _readiness.primaryConcern : null;

  /// Whether this platform can offer an "Open settings" action that works.
  bool get canOpenSettings => MediaPermissionService.canOpenSettings;

  /// Whether the person should be sent to settings — only when that is the
  /// only remaining fix AND the platform actually has such a place.
  bool get shouldOfferSettings {
    final c = concern;
    return c != null && c.needsSettingsTrip && canOpenSettings;
  }

  /// THE EXPLICIT ASK.
  ///
  /// Two steps, in this order, and the order is the point:
  ///
  /// 1. On platforms with a real permission system, ask for permission
  ///    *first*, as a deliberate act, so the OS prompt appears while the
  ///    person is looking at an explanation of why it is needed — not
  ///    half-way through joining a call.
  /// 2. Then actually open the devices, because a granted permission still
  ///    does not prove a working camera: it may be missing, held by another
  ///    app, or blocked by policy.
  ///
  /// Skipping step 2 would let a preflight declare readiness it has not
  /// verified, which is the failure this whole system exists to prevent.
  Future<void> check({bool requestPermission = true}) async {
    if (_checking || _disposed) return;
    _checking = true;
    _notify();

    try {
      var micState = DevicePermissionState.notRequested;
      var cameraState = DevicePermissionState.notRequested;

      if (MediaPermissionService.hasQueryablePermissions) {
        if (requestPermission) {
          final asked = await _permissions.requestBoth(
            camera: wantsCamera,
            microphone: true,
          );
          micState = asked[MediaDeviceKind.microphone] ?? micState;
          cameraState = asked[MediaDeviceKind.camera] ?? cameraState;
        } else {
          micState = await _permissions.status(MediaDeviceKind.microphone);
          if (wantsCamera) {
            cameraState = await _permissions.status(MediaDeviceKind.camera);
          }
        }
      }

      // A refusal is final on this platform — do not then call getUserMedia
      // and provoke a second, pointless failure.
      final micRefused = _isRefusal(micState);
      final cameraRefused = wantsCamera && _isRefusal(cameraState);

      if (!micRefused || !cameraRefused) {
        final probe = await _open(
          audio: !micRefused,
          video: wantsCamera && !cameraRefused,
        );
        micState = probe.mic ?? micState;
        cameraState = probe.camera ?? cameraState;
      }

      _readiness = MediaReadiness(
        microphone: DeviceReadiness(
          kind: MediaDeviceKind.microphone,
          state: micState,
        ),
        camera: DeviceReadiness(
          kind: MediaDeviceKind.camera,
          // A call that never wanted a camera reports "not asked", never
          // "refused" — it was not refused, it was not wanted.
          state: wantsCamera ? cameraState : DevicePermissionState.notRequested,
        ),
      );
      _hasChecked = true;
    } finally {
      _checking = false;
      // If we were disposed mid-flight, release anything the check opened and
      // stay silent — the listener it would notify is already gone.
      if (_disposed) {
        await releasePreview();
      } else {
        _notify();
      }
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Send the person to the only place that can undo a permanent refusal.
  Future<bool> openSettings() => _permissions.openSettings();

  /// Release the preview devices without discarding what we learned.
  ///
  /// Called when leaving the preflight for the room: the room opens its own
  /// stream, and two live captures of one camera is exactly the "orphaned
  /// device capture" §17 forbids.
  Future<void> releasePreview() async {
    final stream = _preview;
    _preview = null;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (_) {/* already gone */}
    }
    try {
      await stream.dispose();
    } catch (_) {/* already gone */}
  }

  bool _isRefusal(DevicePermissionState state) =>
      state == DevicePermissionState.denied ||
      state == DevicePermissionState.permanentlyDenied ||
      state == DevicePermissionState.restricted;

  Future<({DevicePermissionState? mic, DevicePermissionState? camera})> _open({
    required bool audio,
    required bool video,
  }) async {
    await releasePreview();
    if (!audio && !video) return (mic: null, camera: null);

    try {
      _preview = await navigator.mediaDevices.getUserMedia({
        'audio': audio,
        'video': video ? {'facingMode': 'user'} : false,
      });
      return (
        mic: audio ? DevicePermissionState.granted : null,
        camera: video ? DevicePermissionState.granted : null,
      );
    } catch (error) {
      // Both at once failed. Retry audio alone so a camera problem does not
      // get reported as a microphone problem — they need different answers.
      if (video && audio) {
        try {
          _preview = await navigator.mediaDevices
              .getUserMedia({'audio': true, 'video': false});
          return (
            mic: DevicePermissionState.granted,
            camera: classifyMediaError(error, kind: MediaDeviceKind.camera),
          );
        } catch (audioError) {
          return (
            mic: classifyMediaError(audioError,
                kind: MediaDeviceKind.microphone),
            camera: classifyMediaError(error, kind: MediaDeviceKind.camera),
          );
        }
      }
      return (
        mic: audio
            ? classifyMediaError(error, kind: MediaDeviceKind.microphone)
            : null,
        camera:
            video ? classifyMediaError(error, kind: MediaDeviceKind.camera) : null,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // Fire-and-forget is deliberate: dispose cannot await, and the devices
    // must be released whether or not a check is still in flight. A check that
    // completes afterwards releases again — releasePreview is idempotent.
    releasePreview();
    super.dispose();
  }
}
