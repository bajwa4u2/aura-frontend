import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A picture compared only on the reference platform.
///
/// Golden output depends on the host's font rasterization, so the committed
/// pictures are made and compared on Windows. A behaviour test that also
/// takes a picture uses this, so its behaviour still runs on Codemagic's
/// macOS builders while the pixel comparison runs where the pictures were
/// made. (Codemagic build #58, 2026-09-30, failed on exactly this.)
Future<void> expectReferenceGolden(Finder finder, String path) async {
  if (!Platform.isWindows) return;
  await expectLater(finder, matchesGoldenFile(path));
}
