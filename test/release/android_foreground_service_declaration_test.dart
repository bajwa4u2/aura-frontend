import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A PERMISSION IS NOT A CAPABILITY, AND PLAY ASKS ABOUT THE CAPABILITY.
///
/// `AndroidManifest.xml` once declared FOREGROUND_SERVICE,
/// FOREGROUND_SERVICE_CAMERA and FOREGROUND_SERVICE_MICROPHONE with a comment
/// claiming they keep a backgrounded call's capture alive. They did not. The
/// app starts no foreground service at all, so the permissions did nothing
/// except make Google Play demand a declaration — "what tasks require your app
/// to use the FOREGROUND_SERVICE_CAMERA permission?" — naming a task Aura does
/// not perform, with a demonstration video of behaviour that does not exist.
///
/// That is the trap this guards: the cost of an unused sensitive permission is
/// not paid at build time or at runtime. It is paid at the Store, by a person
/// who has to either answer falsely or stop and rebuild.
///
/// So the two halves must travel together, in both directions:
///
///   * declare a FOREGROUND_SERVICE_* permission → a service of that type must
///     exist to use it;
///   * declare a service with `android:foregroundServiceType` → the matching
///     permission must be declared or the OS refuses to start it.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  /// Permission names actually declared, e.g. FOREGROUND_SERVICE_CAMERA.
  final declaredPermissions = RegExp(
    r'<uses-permission\s+android:name="android\.permission\.(FOREGROUND_SERVICE[A-Z_]*)"',
  ).allMatches(manifest).map((m) => m.group(1)!).toSet();

  /// Every `android:foregroundServiceType` value on a <service> in OUR
  /// manifest. Plugins merge their own in, and those carry their own
  /// permissions — this file is only answerable for what Aura declares.
  final serviceTypes = RegExp(r'android:foregroundServiceType="([^"]+)"')
      .allMatches(manifest)
      .expand((m) => m.group(1)!.split('|'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet();

  test('no FOREGROUND_SERVICE_* permission without a service that uses it', () {
    if (declaredPermissions.isEmpty) return;

    expect(
      serviceTypes,
      isNotEmpty,
      reason: '\nThe manifest declares $declaredPermissions but contains no '
          '<service> with android:foregroundServiceType.\n\n'
          'A foreground-service permission grants nothing on its own — capture '
          'survives backgrounding only if the app actually starts a foreground '
          'service of that type. What an unused declaration DOES do is oblige '
          'a foreground-service declaration in Play Console, describing a task '
          'the app does not perform.\n\n'
          'Either add the service, or remove the permission.\n',
    );
  });

  test('no foreground service type without the permission that starts it', () {
    for (final type in serviceTypes) {
      // camera -> FOREGROUND_SERVICE_CAMERA, mediaPlayback -> ..._MEDIA_PLAYBACK
      final expected = 'FOREGROUND_SERVICE_'
          '${type.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]}').toUpperCase()}';
      expect(
        declaredPermissions,
        contains(expected),
        reason: '\nA <service> declares foregroundServiceType="$type" but '
            '$expected is not declared. Android refuses to start a typed '
            'foreground service without its matching permission, so this fails '
            'on a device rather than in a build.\n',
      );
    }
  });

  test('the base FOREGROUND_SERVICE permission travels with the typed ones',
      () {
    final typed =
        declaredPermissions.where((p) => p != 'FOREGROUND_SERVICE').toSet();
    if (typed.isEmpty) return;
    expect(
      declaredPermissions,
      contains('FOREGROUND_SERVICE'),
      reason: '\n$typed is declared without the base FOREGROUND_SERVICE '
          'permission. From Android 14 a typed permission supplements the base '
          'one; it does not replace it.\n',
    );
  });
}
