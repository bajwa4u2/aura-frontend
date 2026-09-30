import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A PICTURE COMPARISON NEVER REACHES CI UNTAGGED.
///
/// Codemagic runs `flutter test --exclude-tags golden` on macOS, where fonts
/// rasterise differently from the Windows machine the pictures were made on.
/// An untagged `matchesGoldenFile` therefore fails the iOS release build, and
/// did: build #58 of 1.5.2, 2026-09-30. A file compares pictures only if it is
/// tagged `golden` or `visual`, or it goes through `expectReferenceGolden`.
void main() {
  test('every direct golden comparison is tagged', () {
    final offenders = <String>[];
    for (final e in Directory('test').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final src = e.readAsStringSync();
      if (!src.contains('matchesGoldenFile(')) continue;
      if (e.path.replaceAll(r'\', '/').endsWith('support/reference_golden.dart')) continue;
      if (e.path.replaceAll(r'\', '/').endsWith('doctrine/golden_tag_gate_test.dart')) continue;
      final tagged = RegExp(r"@Tags\(\s*\[[^\]]*'(golden|visual)'").hasMatch(src);
      if (!tagged) offenders.add(e.path);
    }
    expect(offenders, isEmpty,
        reason: 'Tag the file golden, or use expectReferenceGolden.');
  });
}
