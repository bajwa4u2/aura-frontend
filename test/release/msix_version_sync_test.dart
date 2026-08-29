import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE MANUAL SYNC THAT DID NOT HAPPEN.
///
/// `pubspec.yaml` carries two versions that must agree: `version:` (the
/// semantic X.Y.Z the whole product is built from) and `msix_config.
/// msix_version` (the four-part X.Y.Z.0 the Microsoft Store identifies a
/// package by). The file itself says so, and says how it is kept true: "for
/// now it's a manual sync."
///
/// It drifted. `version` moved to 1.4.0 and `msix_version` stayed at 1.3.0.0,
/// so the built package was named AuraPlatformLLC.AURAPLATFORM_1.3.0.0_X64_ —
/// the same full name as the already-published one, with different contents.
/// Partner Center refused the submission: "you have provided two packages
/// with the full name ... which have different contents."
///
/// The failure is silent everywhere else. The MSIX builds, installs and runs;
/// nothing is wrong with the artifact. It is only rejected at the Store, at
/// the end, by a person who has already done the work of preparing a release.
/// That is precisely the kind of drift a cheap test should catch, and the
/// comment in the pubspec had already identified the risk without closing it.
void main() {
  test('msix_version tracks the pubspec version, with a zero revision', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final version = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+\d+\s*$',
            multiLine: true)
        .firstMatch(pubspec);
    expect(version, isNotNull,
        reason: 'pubspec `version:` is not in the expected X.Y.Z+B form');

    final msix = RegExp(r'^\s*msix_version:\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$',
            multiLine: true)
        .firstMatch(pubspec);
    expect(msix, isNotNull,
        reason: 'msix_config.msix_version is missing or not four-part');

    final semantic =
        '${version!.group(1)}.${version.group(2)}.${version.group(3)}';
    final msixSemantic =
        '${msix!.group(1)}.${msix.group(2)}.${msix.group(3)}';

    expect(msixSemantic, semantic,
        reason: '\nmsix_version ($msixSemantic) does not match version '
            '($semantic).\n\nThe Store identifies a package by its full name, '
            'which includes this version. Leaving it behind produces a package '
            'that collides with one already published and is refused at '
            'submission — after the release is otherwise finished.\n');

    // Microsoft Store policy: the revision component must be 0.
    expect(msix.group(4), '0',
        reason: 'the fourth MSIX component must be 0 per Store policy');
  });
}
