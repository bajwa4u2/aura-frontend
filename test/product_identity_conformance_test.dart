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

  /// Counts the distinct angular groups of white pixels around the MARK.
  /// The canonical mark has eight; the crescent has one continuous mass.
  ///
  /// The centre is taken from the gold ring rather than from the canvas, and
  /// only pixels near the ring are counted. On an icon those are the same
  /// thing, but a poster also carries the wordmark in the same near-white ink,
  /// and measuring angles about the canvas centre lets that type merge the
  /// tick groups and collapse the count.
  int countRadialTicks(img.Image image) {
    var gx = 0.0, gy = 0.0, gn = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        if (near(p.r, p.g, p.b, gold)) {
          gx += x;
          gy += y;
          gn++;
        }
      }
    }
    if (gn == 0) return 0;
    final cx = gx / gn, cy = gy / gn;

    // Radius of the ring itself, so "near the mark" is derived from the
    // artwork rather than from a constant that would need tuning per asset.
    var ringR = 0.0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        if (near(p.r, p.g, p.b, gold)) {
          final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
          if (d > ringR) ringR = d;
        }
      }
    }
    final limit = ringR * 1.8;

    final angles = <double>[];
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        if (!near(p.r, p.g, p.b, white)) continue;
        final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
        if (d > limit) continue;
        var a = math.atan2(y - cy, x - cx) * 180 / math.pi;
        if (a < 0) a += 360;
        angles.add(a);
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

  group('the master is the only place the identity is defined', () {
    final tool = File('tool/generate_store_assets.dart');
    final masterFile = File('assets/brand/AURA_logo_master.svg');

    test('the generator PARSES the master rather than restating it', () {
      // Orchestrate's mark drifted because its generator drew a logo in code.
      // Aura's had a subtler version of the same fault: it declared the ring
      // radius, stroke widths and all eight tick coordinates as Dart constants
      // "to match" the SVG. Editing the master changed nothing downstream and
      // no test failed. Reading the file is what makes the master the master.
      expect(tool.existsSync(), isTrue);
      expect(masterFile.existsSync(), isTrue);
      final source = tool.readAsStringSync();

      expect(source, contains('_parseMaster'),
          reason: 'the generator must parse the master');
      expect(source, contains('AURA_logo_master.svg'));

      for (final restated in const [
        'const _ringRadiusRef',
        'const _ringStrokeRef',
        'const _tickStrokeRef',
        'const _ticksRef',
        'const _gold',
        'const _navy',
        'const _inkLight',
      ]) {
        expect(source, isNot(contains(restated)),
            reason: '$restated re-declares identity the master already owns');
      }
    });

    test('the master carries no font dependency', () {
      // font-family="Times New Roman" renders in a fallback face on any
      // machine without it -- a silent identity change, and not reproducible
      // off Windows at all. The wordmark is outlined instead.
      final svg = masterFile.readAsStringSync();
      expect(svg.contains('<text'), isFalse,
          reason: 'the wordmark must be outlined, not set in a live font');
      expect(svg, contains('id="wordmark"'));
      expect(svg, contains('id="ring"'));
      expect(svg, contains('id="ticks"'));
    });

    test('the master declares both surface variants of the tick colour', () {
      // The generator used to draw light ticks while the master said #2E2E2E,
      // an undeclared override that only a human reading both files would
      // catch.
      final svg = masterFile.readAsStringSync();
      expect(svg, contains('data-on-dark-stroke'),
          reason: 'the on-dark tick colour must come from the master');
      expect(svg, contains('data-surface-dark'),
          reason: 'the dark surface colour must come from the master');
    });

    test('the eight ticks in the master are what the icons carry', () {
      final svg = masterFile.readAsStringSync();
      final group = RegExp(r'<g id="ticks"[^>]*>(.*?)</g>', dotAll: true)
          .firstMatch(svg);
      expect(group, isNotNull);
      final lines = RegExp(r'<line\b').allMatches(group!.group(1)!).length;
      expect(lines, expectedTicks,
          reason: 'the master must declare exactly $expectedTicks ticks');
    });
  });
}
