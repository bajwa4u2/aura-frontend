import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/platform/media_capabilities.dart';

/// C-20 — DO NOT OFFER WHAT THIS BUILD CANNOT DO.
///
/// Two controls were being offered for things the platform cannot perform.
/// Both failed the same way: a dead button, and either silence or an
/// invitation to retry something that can never succeed.
///
/// **Screen sharing on mobile.** `getDisplayMedia` needs a `mediaProjection`
/// foreground service on Android — `AndroidManifest.xml` declares
/// `FOREGROUND_SERVICE`, `..._MICROPHONE` and `..._CAMERA`, and NOT
/// `FOREGROUND_SERVICE_MEDIA_PROJECTION`, while `flutter_webrtc`'s own
/// manifest is empty. On iOS it needs a Broadcast Upload Extension, and `ios/`
/// holds only `Runner`, `RunnerTests` and `ShareExtension`. The call room
/// reduced the failure to a `debugPrint`; the meetings room offered "Try
/// again".
///
/// Adding the Android permission on its own would be the wrong repair, and
/// this estate already named that mistake: a declaration nobody packed is not
/// a feature. So the capability is reported honestly until the service and the
/// extension exist.
///
/// **Voice notes on Windows.** `AuraVoicePlayer` is built on `video_player`,
/// which has no Windows implementation and is absent from
/// `windows/flutter/generated_plugins.cmake`, so every voice note fails
/// `initialize()` and read "Unavailable" — blaming the recording. Recording on
/// the same platform WORKS (`record_windows` IS registered), so a Windows user
/// could send a voice note and then be told their own message was unavailable.
void main() {
  group('screen sharing', () {
    test('mobile cannot, because the prerequisites are not built', () {
      for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(screenShareSupported(isWeb: false, platform: p), isFalse,
            reason: '$p');
      }
    });

    test('web and desktop can', () {
      expect(screenShareSupported(isWeb: true, platform: null), isTrue);
      for (final p in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(screenShareSupported(isWeb: false, platform: p), isTrue,
            reason: '$p');
      }
    });
  });

  group('what the person is told', () {
    test('on mobile it does NOT invite a retry', () {
      final msg = screenShareUnavailableReason(
        isWeb: false,
        platform: TargetPlatform.android,
      );
      expect(msg.toLowerCase(), isNot(contains('try again')),
          reason: 'retrying cannot work, so asking for it is worse than '
              'saying nothing');
      expect(msg.toLowerCase(), contains('computer'),
          reason: 'it should say where sharing DOES work');
    });

    test('where sharing is possible, a retry is the right advice', () {
      final msg = screenShareUnavailableReason(
        isWeb: true,
        platform: null,
      );
      expect(msg.toLowerCase(), contains('try again'));
    });
  });

  group('voice note playback', () {
    // 2026-09-25: video_player_win gives Windows a player; the claim widened
    // exactly as the build-measured test below instructed.
    test('Windows can — video_player_win is registered', () {
      expect(
        voiceNotePlaybackSupported(
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        isTrue,
      );
    });

    test('Linux cannot — video_player has no Linux implementation', () {
      expect(
        voiceNotePlaybackSupported(
          isWeb: false,
          platform: TargetPlatform.linux,
        ),
        isFalse,
      );
    });

    test('web, mobile and macOS can', () {
      expect(voiceNotePlaybackSupported(isWeb: true, platform: null), isTrue);
      for (final p in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        expect(voiceNotePlaybackSupported(isWeb: false, platform: p), isTrue,
            reason: '$p');
      }
    });
  });

  group('the claim is measured against the build, not remembered', () {
    // If either prerequisite is ever actually added, this test fails and
    // whoever added it is told to widen the capability — which is the only way
    // these stay honest.
    test('Android still has no mediaProjection foreground service', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(
        manifest.contains('FOREGROUND_SERVICE_MEDIA_PROJECTION'),
        isFalse,
        reason: 'the permission now exists — build the service, then let '
            'screenShareSupported() return true for Android',
      );
    });

    test('Windows registers video_player, so the Windows claims may stand', () {
      final plugins =
          File('windows/flutter/generated_plugins.cmake').readAsStringSync();
      expect(
        plugins.contains('video_player_win'),
        isTrue,
        reason: 'voiceNotePlaybackSupported() and storedVideoCanDecodeInline() '
            'say Windows plays media; without the plugin that is a lie',
      );
    });
  });
}
