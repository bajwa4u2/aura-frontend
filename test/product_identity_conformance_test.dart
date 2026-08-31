import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// THE SHIPPED ICON IS THE PRODUCT'S IDENTITY, SO IT IS TESTED LIKE CODE.
///
/// Aura's canonical mark is a gold ring carrying eight white radial ticks on
/// dark navy. The identity it must never be confused with is the legacy
/// crescent: a large pale mass with no gold and no ticks.
///
/// This matters because the crescent is still live on the Play listing while
/// every asset in this repository is canonical -- which is exactly the failure
/// this test exists to make loud. A drifted mark does not break a build. It
/// does not fail a lint. It ships, and it keeps shipping, until somebody looks
/// at the pixels. So this looks at the pixels.
void main() {
  const gold = [199, 169, 107];
  const white = [216, 216, 216];
  const ink = [26, 26, 46];

  const minGoldFraction = 0.005;
  const expectedTicks = 8;

  /// Icons that fill their canvas with the full mark on its ground.
  const fullMarks = <String>[
    'assets/aura_icon.png',
    'assets/store/android/play_icon_512.png',
    'assets/store/android/mipmap-xxxhdpi/ic_launcher.png',
    'assets/store/ios/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    'assets/store/macos/app_icon_1024.png',
    'assets/store/macos/app_icon_512.png',
    'assets/store/web/icon-512.png',
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
    'web/icons/Icon-512.png',
  ];

  /// The poster carries the mark small, beside the wordmark, so it holds the
  /// ring and ticks but not the icon's gold density.
  const posters = <String>[
    'assets/store/android/feature_graphic_1024x500.png',
  ];

  img.Image load(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    final decoded = img.decodePng(file.readAsBytesSync());
    expect(decoded, isNotNull, reason: '$path did not decode');
    return decoded!;
  }

  bool near(num r, num g, num b, List<int> target, [int tolerance = 60]) =>
      (r - target[0]).abs() + (g - target[1]).abs() + (b - target[2]).abs() <
      tolerance;

  /// Counts the distinct angular groups of white pixels around the centre.
  /// The canonical mark has eight; the crescent has one continuous mass.
  int countRadialTicks(img.Image image) {
    final cx = image.width / 2, cy = image.height / 2;
    final angles = <double>[];
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        if (near(p.r, p.g, p.b, white)) {
          var a = math.atan2(y - cy, x - cx) * 180 / math.pi;
          if (a < 0) a += 360;
          angles.add(a);
        }
      }
    }
    if (angles.length < 20) return 0;
    angles.sort();
    var groups = 1;
    for (var i = 1; i < angles.length; i++) {
      if (angles[i] - angles[i - 1] > 8) groups++;
    }
    // A group straddling 0/360 is one group, not two.
    if (groups > 1 && (360 - angles.last + angles.first) < 8) groups--;
    return groups;
  }

  ({double gold, double pale, double ink}) fractions(img.Image image) {
    var g = 0, pale = 0, inkCount = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final isGold = near(p.r, p.g, p.b, gold);
        if (isGold) g++;
        if (!isGold && p.r + p.g + p.b > 400) pale++;
        if (near(p.r, p.g, p.b, ink)) inkCount++;
      }
    }
    final total = image.width * image.height;
    return (gold: g / total, pale: pale / total, ink: inkCount / total);
  }

  for (final path in fullMarks) {
    test('$path carries the canonical mark', () {
      final image = load(path);
      final f = fractions(image);

      expect(f.gold, greaterThan(minGoldFraction),
          reason: 'no gold ring found in $path -- the legacy crescent carries '
              'no gold, and this is what it looks like when it comes back');
      expect(countRadialTicks(image), expectedTicks,
          reason: 'the mark does not carry eight radial ticks');
      expect(f.ink, greaterThan(0.6),
          reason: 'the ground is not the canonical dark navy');
    });
  }

  for (final path in posters) {
    test('$path carries the canonical mark', () {
      final image = load(path);
      final f = fractions(image);
      expect(f.gold, greaterThan(0.002), reason: 'no gold ring in the poster');
      expect(countRadialTicks(image), expectedTicks,
          reason: 'the poster mark does not carry eight radial ticks');
    });
  }

  test('the crescent fingerprint appears nowhere', () {
    // Stated as its own assertion rather than left implicit in the checks
    // above, because "not canonical" and "is the specific wrong mark we
    // already shipped once" are worth telling apart in a failure message.
    for (final path in [...fullMarks, ...posters]) {
      final image = load(path);
      final f = fractions(image);
      final looksLikeCrescent =
          f.gold < 0.002 && f.pale > 0.03 && countRadialTicks(image) < 4;
      expect(looksLikeCrescent, isFalse,
          reason: '$path matches the legacy crescent fingerprint');
    }
  });

  test('the generation authority reads the vector master, not a redrawn mark',
      () {
    // Orchestrate's mark drifted because its generator drew a logo in code
    // instead of resampling the master, so every asset it wrote was wrong and
    // nothing failed. Aura's generator reads the SVG; this keeps it that way.
    final tool = File('tool/generate_store_assets.dart');
    expect(tool.existsSync(), isTrue);
    expect(tool.readAsStringSync(), contains('AURA_logo_master.svg'),
        reason: 'the generator must derive assets from the vector master');
    expect(File('assets/brand/AURA_logo_master.svg').existsSync(), isTrue,
        reason: 'the vector master is the source of the identity');
  });
}
