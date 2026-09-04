// TRACK C — ANDROID NATIVE CALL LIFECYCLE.
//
// Registering Aura's calls with Telecom is what makes them CALLS to the
// operating system: audio focus, Bluetooth and wired routing, and concurrency
// with the dialer become the system's job. This file holds the two boundaries
// that make that safe to have.
//
// FIRST: Aura writes nothing to the call log, and holds none of Play's
// restricted Call Log permissions. System call history is whatever Android
// records for a call it is managing. Inserting rows to manufacture Recents
// entries would produce entries without producing calls.
//
// SECOND: the certified ringing experience is not replaced. These are
// self-managed calls — Android draws no incoming-call screen for them — so
// `IncomingCallPresenter` remains what a person sees, and Telecom sits
// underneath it.
//
// Nothing here can be executed: no Android device, no AVD, no adb. Track C is
// IMPLEMENTED / UNVERIFIED and never PASS.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _telecomKotlin =
    'android/app/src/main/kotlin/org/auraplatform/app/AuraTelecom.kt';
const _policyKotlin =
    'android/app/src/main/kotlin/org/auraplatform/app/CallCapabilityPolicy.kt';
const _mainActivity =
    'android/app/src/main/kotlin/org/auraplatform/app/MainActivity.kt';
const _presenter =
    'android/app/src/main/kotlin/org/auraplatform/app/IncomingCallPresenter.kt';
const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _gradle = 'android/app/build.gradle.kts';
const _dart = 'lib/core/notifications/android_telecom.dart';
const _bridge = 'lib/features/updates/incoming_call_bridge.dart';

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('$path is missing.');
  return file.readAsStringSync();
}

/// Source with comment lines removed, so a gate judges CODE.
String _codeOnly(String source) => source
    .split('\n')
    .where((line) {
      final trimmed = line.trimLeft();
      return !trimmed.startsWith('//') &&
          !trimmed.startsWith('*') &&
          !trimmed.startsWith('/*') &&
          !trimmed.startsWith('<!--');
    })
    .join('\n');

void main() {
  group('DIRECT_CALLLOG_WRITES = 0', () {
    test('no restricted Call Log permission is declared', () {
      // Play applies special restrictions to exactly these. Aura needs none of
      // them, because Aura does not read or write the call log.
      final manifest = _codeOnly(_read(_manifest));
      for (final permission in const [
        'READ_CALL_LOG',
        'WRITE_CALL_LOG',
        'PROCESS_OUTGOING_CALLS',
      ]) {
        expect(
          manifest.contains(permission),
          isFalse,
          reason: '$permission is a specially restricted permission and Aura '
              'has no use for it.',
        );
      }
    });

    test('no source anywhere touches the CallLog provider', () {
      for (final path in const [_telecomKotlin, _policyKotlin, _mainActivity]) {
        final code = _codeOnly(_read(path));
        expect(
          code.contains('CallLog'),
          isFalse,
          reason: '$path reaches for the call log. Writing rows would produce '
              'entries without producing calls — a row in a table that looks '
              'like an integration.',
        );
      }
    });

    test('MANAGE_OWN_CALLS is the only calling permission, and it is merged '
        'from the library rather than declared by hand', () {
      final manifest = _codeOnly(_read(_manifest));
      // It arrives through core-telecom's own manifest. Declaring it here as
      // well would suggest Aura wanted it for some other purpose.
      expect(manifest.contains('MANAGE_OWN_CALLS'), isFalse);
      expect(_read(_gradle).contains('core-telecom'), isTrue);
    });
  });

  group('the jurisdiction policy exists and is deliberately empty', () {
    test('no restriction is asserted without evidence', () {
      final code = _codeOnly(_read(_policyKotlin));
      // Founder ruling 2026-09-04: ANDROID_TELECOM_PLATFORM_JURISDICTION_GATE
      // = NONE. Apple issued a real storefront-specific instruction, so iOS
      // has a gate. Android has issued none, and inventing one would remove a
      // system call experience from territories nobody asked us to.
      expect(code.contains('emptyList()'), isTrue);
      expect(
        code.contains('CHN'),
        isFalse,
        reason: 'No Android rule names a territory. Copying the iOS one would '
            'be manufacturing a restriction.',
      );
    });

    test('it never substitutes a device signal for a rule', () {
      final code = _codeOnly(_read(_policyKotlin));
      for (final signal in const [
        'Locale',
        'TimeZone',
        'getSimCountryIso',
        'getNetworkCountryIso',
        'TelephonyManager',
      ]) {
        expect(
          code.contains(signal),
          isFalse,
          reason: 'Each of these describes where a handset currently IS, which '
              'is a different question from which rule binds the '
              'distribution.',
        );
      }
    });

    test('a restriction must carry the evidence that established it', () {
      // A restriction that cannot name what established it is one nobody can
      // review, revisit or remove.
      final code = _codeOnly(_read(_policyKotlin));
      expect(code.contains('val evidence: String'), isTrue);
    });

    test('there is still a switch, so a future rule has somewhere to land', () {
      final code = _codeOnly(_read(_policyKotlin));
      expect(code.contains('productEnabled'), isTrue);
      expect(code.contains('fun telecomCapability()'), isTrue);
    });

    test('every caller asks the policy before touching Telecom', () {
      final code = _codeOnly(_read(_telecomKotlin));
      expect(code.contains('CallCapabilityPolicy.telecomCapability()'), isTrue);
    });
  });

  group('the certified ring is preserved, not replaced', () {
    test('IncomingCallPresenter is still there', () {
      expect(File(_presenter).existsSync(), isTrue);
      // Still the thing that draws a ringing call. Self-managed calls get no
      // system incoming-call screen, which is exactly why this survives.
      expect(_read(_presenter).contains('fun dismiss'), isTrue);
    });

    test('Telecom does not draw or dismiss any call UI', () {
      final code = _codeOnly(_read(_telecomKotlin));
      for (final forbidden in const [
        'NotificationCompat',
        'NotificationManager',
        'setFullScreenIntent',
        'IncomingCallPresenter',
      ]) {
        expect(
          code.contains(forbidden),
          isFalse,
          reason: 'Telecom is the call lifecycle, not a second ringing '
              'surface. "$forbidden" would make it one.',
        );
      }
    });

    test('the notification path still owns the ring', () {
      final activity = _read(_mainActivity);
      expect(activity.contains('IncomingCallPresenter.dismiss'), isTrue);
      expect(activity.contains('AuraTelecom.CHANNEL'), isTrue);
    });
  });

  group('the system decides nothing on the person\'s behalf', () {
    test('a system answer is carried, never auto-joined', () {
      final code = _codeOnly(_read(_telecomKotlin));
      // Founder ruling 2026-08-14: answering must reach the same accept path a
      // foreground call gets. A Bluetooth button may not join a call by
      // itself.
      expect(code.contains('emit("onAnswer", sessionId)'), isTrue);
      expect(code.contains('join'), isFalse);
    });

    test('the Dart side routes the events and resolves none of them', () {
      final code = _codeOnly(_read(_dart));
      expect(code.contains('onAnswer'), isTrue);
      expect(code.contains('onDisconnect'), isTrue);
      expect(code.contains('onHoldChanged'), isTrue);
    });
  });

  group('one call lifecycle, reported to two systems', () {
    test('Android is reported from the SAME choke points as iOS', () {
      final bridge = _read(_bridge);
      // A second place that decides a call is over is a second place that can
      // be wrong about it.
      expect(bridge.contains('AndroidTelecom.instance.reportEnded'), isTrue);
      expect(bridge.contains('AndroidTelecom.instance.reportConnected'), isTrue);
      expect(bridge.contains('AndroidTelecom.instance.reportIncoming'), isTrue);
      expect(bridge.contains('IosCallKit.instance.reportEnded'), isTrue);
    });

    test('accepting a call reports CONNECTED, never ended', () {
      final bridge = _read(_bridge);
      final acceptedAt = bridge.indexOf('void clearAccepted(');
      expect(acceptedAt, greaterThan(-1));
      // CODE ONLY. The method's own comment says "Deliberately NOT
      // reportEnded", which is the rule this test enforces — a gate that
      // tripped on the sentence explaining its own reason would teach the next
      // person to delete the explanation.
      final accepted = _codeOnly(
        bridge.substring(acceptedAt, bridge.indexOf('\n  }', acceptedAt)),
      );
      // Reporting a call ended when it was just answered tears down the system
      // call and the audio focus with it — the failure iOS already recorded.
      expect(accepted.contains('AndroidTelecom.instance.reportConnected'), isTrue);
      expect(accepted.contains('reportEnded'), isFalse);
    });

    test('an outgoing call is reported on both stacks from one site', () {
      final screen = _read('lib/features/conversation/presentation/conversation_screen.dart');
      expect(screen.contains('AndroidTelecom.instance'), isTrue);
      expect(screen.contains('IosCallKit.instance'), isTrue);
    });

    test('the end reason is carried, so history is not a lie', () {
      final code = _codeOnly(_read(_telecomKotlin));
      // A call answered on another device must not be recorded as declined,
      // and one that expired must not be recorded as ended by the caller.
      for (final reason in const ['declined', 'expired', 'cancelled', 'failed']) {
        expect(code.contains('"$reason"'), isTrue, reason: '$reason unmapped.');
      }
      expect(code.contains('DisconnectCause.REJECTED'), isTrue);
      expect(code.contains('DisconnectCause.MISSED'), isTrue);
    });
  });

  group('it degrades instead of blocking', () {
    test('a refused registration cannot fail a call', () {
      final code = _codeOnly(_read(_telecomKotlin));
      expect(code.contains('catch (t: Throwable)'), isTrue);
      // Registration happens on the first call rather than at app start:
      // putting Aura in the system's calling-account settings for someone who
      // never places a call would be a presence they did not ask for.
      expect(code.contains('@Synchronized'), isTrue);
    });

    test('a duplicate report does not create a second system call', () {
      final code = _codeOnly(_read(_telecomKotlin));
      expect(code.contains('calls.containsKey(sessionId)'), isTrue);
    });

    test('every Dart method is a no-op off Android', () {
      final code = _codeOnly(_read(_dart));
      expect(code.contains('defaultTargetPlatform == TargetPlatform.android'),
          isTrue);
      expect(code.contains('if (!isSupported'), isTrue);
    });

    test('the pre-Telecom Android floor is respected', () {
      final code = _codeOnly(_read(_telecomKotlin));
      // Self-managed Telecom arrived in Android 8.0. Below it the capability
      // is genuinely absent, which is a platform fact rather than a policy.
      expect(code.contains('Build.VERSION_CODES.O'), isTrue);
    });
  });
}
