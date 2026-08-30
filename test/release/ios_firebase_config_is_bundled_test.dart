import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// IOS HAS NEVER REGISTERED AN ORDINARY PUSH DEVICE.
///
/// Production evidence, 2026-08-30: the founder's account has ten UserDevice
/// rows across its whole history — ANDROID/FCM, IOS/APNS, WEB/WEB_PUSH — and
/// not one IOS/FCM row. Ordinary iOS notifications were never merely broken in
/// a build; they had never been deliverable at all.
///
/// The cause was not in any Dart or Swift source file. `GoogleService-Info.plist`
/// sat on disk in ios/Runner, correct in every detail (bundle
/// org.auraplatform.app, project aura-22b3a), and was referenced NOWHERE in
/// project.pbxproj — so Xcode never copied it into the app bundle. At runtime
/// `Firebase.initializeApp()` had no configuration to find and threw; main.dart
/// catches that and calls debugPrint, which is stripped from release builds.
/// `getToken()` then returned nothing, `_fcmPayload` returned null, and the
/// device simply never registered. Silent at every layer.
///
/// PushKit is native and touches none of this, which is exactly why calls could
/// ring on a build whose ordinary notifications could not work.
///
/// No unit test could catch that: the defect lived in the Xcode project file.
/// This is the check that would have.
void main() {
  const pbxprojPath = 'ios/Runner.xcodeproj/project.pbxproj';
  const plistPath = 'ios/Runner/GoogleService-Info.plist';

  String readProject() {
    final file = File(pbxprojPath);
    expect(file.existsSync(), isTrue, reason: 'missing $pbxprojPath');
    return file.readAsStringSync();
  }

  test('the Firebase config is a member of the Runner target', () {
    final project = readProject();

    expect(
      project.contains('GoogleService-Info.plist */ = {isa = PBXFileReference'),
      isTrue,
      reason: 'the plist needs a file reference before it can be built.',
    );
    expect(
      project.contains('GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile'),
      isTrue,
      reason: 'a file reference alone does not bundle anything — membership of '
          'a target is what copies it into the app.',
    );
  });

  test('the Firebase config is copied by the Resources build phase', () {
    final project = readProject();

    // The reference and the build file can both exist while the build file is
    // in no phase at all, which bundles exactly nothing. The phase membership
    // is the part that actually ships the file, so it is asserted separately.
    final phaseStart = project.indexOf('/* Begin PBXResourcesBuildPhase section */');
    final phaseEnd = project.indexOf('/* End PBXResourcesBuildPhase section */');
    expect(phaseStart, greaterThanOrEqualTo(0));
    expect(phaseEnd, greaterThan(phaseStart));

    final phases = project.substring(phaseStart, phaseEnd);
    expect(
      phases.contains('GoogleService-Info.plist in Resources'),
      isTrue,
      reason: 'without this the app ships with no Firebase configuration, '
          'Firebase.initializeApp() throws into a swallowed catch, and iOS '
          'never obtains an FCM token or registers an ordinary push device.',
    );
  });

  test('the config file itself is present and identifies this app', () {
    // Gitignored and provisioned by CI from FIREBASE_IOS_CONFIG_BASE64, so its
    // absence here is a local-setup condition rather than a defect. When it IS
    // present it must describe THIS app — a plist for another bundle would
    // register tokens that no Aura send could ever reach.
    final file = File(plistPath);
    if (!file.existsSync()) {
      markTestSkipped('$plistPath not provisioned locally');
      return;
    }
    final contents = file.readAsStringSync();
    expect(contents, contains('org.auraplatform.app'));
    expect(contents, contains('aura-22b3a'));
  });
}
