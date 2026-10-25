import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AN ORIENTATION LOCK IS A STORE FILTER, 2026-10-25.
///
/// The ring screen (IncomingCallActivity) is portrait. Play reads any
/// `android:screenOrientation` lock as a required screen feature, so build 48
/// stopped installing on 17 cars and 5 tablets with landscape-only screens.
/// Every locked orientation must be declared as not required.
void main() {
  test('every locked orientation is declared optional', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final locks = RegExp(r'android:screenOrientation="(\w+)"')
        .allMatches(manifest)
        .map((m) => m.group(1)!)
        .toSet();
    for (final lock in locks) {
      final feature = lock.contains('landscape')
          ? 'android.hardware.screen.landscape'
          : 'android.hardware.screen.portrait';
      expect(
        manifest,
        contains('<uses-feature android:name="$feature" '
            'android:required="false" />'),
        reason: 'screenOrientation="$lock" makes $feature required on Play',
      );
    }
  });
}
