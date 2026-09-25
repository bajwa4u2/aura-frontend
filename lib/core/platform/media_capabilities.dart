/// WHAT THIS BUILD CAN ACTUALLY DO WITH MEDIA.
///
/// Two controls were being offered for things the platform cannot perform, and
/// both failed the same way: a dead button, and either silence or a message
/// inviting a retry that could never succeed.
///
/// Kept pure and in one place because these are facts about the BUILD, not
/// about the moment — they can be asserted in a test, and a reader can see the
/// whole answer at once instead of discovering it from a caught exception.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// C-20a — CAN THIS BUILD CAPTURE THE SCREEN?
///
/// The Share control was built unconditionally and the prerequisites are
/// simply absent on mobile:
///
///   * **Android** — `getDisplayMedia` needs a `mediaProjection` foreground
///     service. `AndroidManifest.xml` declares `FOREGROUND_SERVICE`,
///     `..._MICROPHONE` and `..._CAMERA`, and **not**
///     `FOREGROUND_SERVICE_MEDIA_PROJECTION`; `flutter_webrtc`'s own manifest
///     is empty, so nothing supplies it. Capture fails on Android 14+.
///   * **iOS** — ReplayKit capture requires a Broadcast Upload Extension
///     target. `ios/` contains `Runner`, `RunnerTests` and `ShareExtension`
///     only. There is no broadcast target to capture into.
///
/// Adding the Android permission alone would be the wrong repair and this
/// estate has a name for it: a declaration nobody packed is not a feature. The
/// capability is reported honestly here until the service and the extension
/// are actually built.
///
/// Web and desktop are unchanged — both really can capture.
bool screenShareSupported({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  if (isWeb ?? kIsWeb) return true;
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return false;
    default:
      return true;
  }
}

/// C-20b — CAN THIS BUILD PLAY A RECORDED VOICE NOTE?
///
/// `AuraVoicePlayer` is the single audio surface and it is built on
/// `video_player`, which ships implementations for Android, iOS, macOS and web
/// only. `windows/flutter/generated_plugins.cmake` registers nine plugins and
/// `video_player` is not among them, so `initialize()` raises
/// `MissingPluginException` and every voice note renders as a disabled button
/// reading "Unavailable" — with no reason given.
///
/// The asymmetry is the part worth stating plainly: **recording works on
/// Windows** (`record_windows` IS registered). A Windows user can capture and
/// send a voice note that neither they nor any other Windows user can play.
/// Saying so is better than a dead control, and better than pretending the
/// file is broken when the player is simply missing.
///
/// 2026-09-25 — WINDOWS HAS A PLAYER NOW. `video_player_win` (Media
/// Foundation) was added so feed video plays on Windows, and it serves this
/// surface too, so the claim widens as `media_capabilities_test` demands.
/// Linux still has none.
bool voiceNotePlaybackSupported({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  if (isWeb ?? kIsWeb) return true;
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.linux:
      return false;
    default:
      return true;
  }
}

/// Why a capture attempt failed, in words that match what is true.
///
/// The room caught every failure into one `debugPrint`, so "you cancelled the
/// picker" and "this platform can never do this" were indistinguishable — and
/// the meetings room offered "Try again" for both, which is an invitation to
/// repeat something that cannot work.
String screenShareUnavailableReason({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  if (screenShareSupported(isWeb: isWeb, platform: platform)) {
    return 'Screen sharing did not start. Try again.';
  }
  final p = platform ?? defaultTargetPlatform;
  if (p == TargetPlatform.android || p == TargetPlatform.iOS) {
    return 'Screen sharing is not available in the mobile app yet. '
        'Join from a computer to share your screen.';
  }
  return 'Screen sharing is not available on this device.';
}
