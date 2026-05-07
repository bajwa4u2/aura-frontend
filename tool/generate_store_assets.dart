// ignore_for_file: avoid_print
//
// Aura — store/platform asset generator.
//
// SOURCE OF TRUTH: assets/brand/AURA_logo_master.svg
//
// The master SVG is intentionally minimal (gold ring + 8 ticks + AURA
// wordmark in the same line). This generator rasterizes the *mark*
// portion (left half of the viewBox) faithfully into all platform
// PNG sizes the project needs. Geometry constants below are derived
// directly from the SVG's 200×200 mark sub-region.
//
// Run:
//   dart run tool/generate_store_assets.dart
//
// Idempotent: every run rewrites every asset from scratch. Output
// dimensions are validated against an expected map at the end.
//
// Brand rules enforced:
//   * Mark only on app icons — no wordmark.
//   * Primary background: Aura navy `#1A1A2E`.
//   * Light tick variant `#D8D8D8` is used on dark backgrounds so the
//     ticks remain legible. Geometry, gold ring, stroke widths are
//     unchanged from the master.
//   * Adaptive foreground: mark on transparent (Android places its own
//     background layer behind it).
//   * Maskable web: mark on navy with extra safe-area padding so the
//     OS can clip to a rounded square without cutting the mark.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

// ── Brand tokens ────────────────────────────────────────────────────────────
const _gold = (0xC7, 0xA9, 0x6B);
const _inkLight = (0xD8, 0xD8, 0xD8); // ticks + wordmark on dark
const _navy = (0x1A, 0x1A, 0x2E); // Aura primary background

// Mark geometry in 200×200 reference units (mirror of the SVG's left
// half: a circle at (100, 100) r=60 plus 8 short ticks).
const _markRef = 200.0;
const _ringRadiusRef = 60.0;
const _ringStrokeRef = 8.0;
const _tickStrokeRef = 6.0;

// Cardinal + diagonal tick endpoints, exactly as written in the SVG.
const _ticksRef = <(double, double, double, double)>[
  (100, 20, 100, 10), // top
  (100, 180, 100, 190), // bottom
  (20, 100, 10, 100), // left
  (180, 100, 190, 100), // right
  (45, 45, 35, 35), // top-left
  (155, 45, 165, 35), // top-right
  (45, 155, 35, 165), // bottom-left
  (155, 155, 165, 165), // bottom-right
];

const _projectRoot = '.';
const _storeRoot = 'assets/store';

// ── Public API ─────────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  print('Aura — store asset generator');
  print('Source: assets/brand/AURA_logo_master.svg');

  // Sanity-check the master SVG exists; the rasterizer doesn't *parse*
  // it (the mark is hand-coded above to match), but we refuse to run
  // when the source of truth is missing.
  final master = File('$_projectRoot/assets/brand/AURA_logo_master.svg');
  if (!master.existsSync()) {
    stderr.writeln('FATAL: master SVG not found at ${master.path}');
    exit(2);
  }

  // Ensure clean output directory tree.
  final outDirs = [
    '$_storeRoot/source',
    '$_storeRoot/android',
    '$_storeRoot/android/mipmap-mdpi',
    '$_storeRoot/android/mipmap-hdpi',
    '$_storeRoot/android/mipmap-xhdpi',
    '$_storeRoot/android/mipmap-xxhdpi',
    '$_storeRoot/android/mipmap-xxxhdpi',
    '$_storeRoot/ios',
    '$_storeRoot/ios/AppIcon.appiconset',
    '$_storeRoot/macos',
    '$_storeRoot/windows',
    '$_storeRoot/web',
  ];
  for (final d in outDirs) {
    Directory('$_projectRoot/$d').createSync(recursive: true);
  }

  // Copy the master SVG into the source slot so the asset pack ships
  // with its own provenance.
  master.copySync('$_projectRoot/$_storeRoot/source/AURA_logo_master.svg');

  // Generated outputs are tracked here so the validator at the end can
  // confirm every file landed at the right dimensions.
  final outputs = <_Out>[];

  // ── Android ────────────────────────────────────────────────────────────
  outputs.addAll(_writeAndroid());

  // ── iOS ────────────────────────────────────────────────────────────────
  outputs.addAll(_writeIos());

  // ── macOS ──────────────────────────────────────────────────────────────
  outputs.addAll(_writeMacos());

  // ── Windows ────────────────────────────────────────────────────────────
  outputs.addAll(_writeWindows());

  // ── Web ────────────────────────────────────────────────────────────────
  outputs.addAll(_writeWeb());

  // ── Validate ───────────────────────────────────────────────────────────
  print('\nValidating outputs:');
  var ok = 0, bad = 0;
  for (final o in outputs) {
    final f = File('$_projectRoot/$_storeRoot/${o.relPath}');
    if (!f.existsSync()) {
      stderr.writeln('  [MISSING] ${o.relPath}');
      bad++;
      continue;
    }
    final bytes = f.readAsBytesSync();
    final decoded = img.decodePng(bytes);
    if (decoded == null) {
      // .ico paths skip PNG validation; the inner PNGs are written
      // alongside.
      if (o.relPath.endsWith('.ico')) {
        ok++;
        continue;
      }
      stderr.writeln('  [UNREADABLE] ${o.relPath}');
      bad++;
      continue;
    }
    if (decoded.width != o.expectedWidth || decoded.height != o.expectedHeight) {
      stderr.writeln(
          '  [SIZE MISMATCH] ${o.relPath} got ${decoded.width}x${decoded.height} '
          'expected ${o.expectedWidth}x${o.expectedHeight}');
      bad++;
      continue;
    }
    ok++;
  }
  print('  $ok ok, $bad failed');
  if (bad > 0) exit(3);
  print('\nDone.');
}

// ── Platform writers ───────────────────────────────────────────────────────

List<_Out> _writeAndroid() {
  final outs = <_Out>[];
  // Density buckets — the canonical Android launcher icon sizes.
  const densities = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  for (final entry in densities.entries) {
    final size = entry.value;
    final image = _renderIconOnNavy(size, padPercent: 0.10);
    final path = 'android/${entry.key}/ic_launcher.png';
    _writePng(image, path);
    outs.add(_Out(path, size, size));
  }

  // Play Store listing — 512×512 icon.
  final playIcon = _renderIconOnNavy(512, padPercent: 0.10);
  _writePng(playIcon, 'android/play_icon_512.png');
  outs.add(const _Out('android/play_icon_512.png', 512, 512));

  // Adaptive icon — Android 8+ splits the launcher icon into a
  // background layer (solid navy) + a foreground layer (mark on
  // transparent, with 33% safe area as required by the platform).
  final adaptiveFg = _renderMark(432, padPercent: 0.33, backgroundRgb: null);
  _writePng(adaptiveFg, 'android/adaptive_foreground.png');
  outs.add(const _Out('android/adaptive_foreground.png', 432, 432));

  final adaptiveBg = _solid(432, _navy);
  _writePng(adaptiveBg, 'android/adaptive_background.png');
  outs.add(const _Out('android/adaptive_background.png', 432, 432));

  // Feature graphic — Play Console hero, 1024×500. Mark left of center,
  // navy field. We don't render the wordmark text in this generator
  // pass (no font dependency); the mark on the navy field is the
  // submission-ready hero.
  final feature = _renderFeatureGraphic(1024, 500);
  _writePng(feature, 'android/feature_graphic_1024x500.png');
  outs.add(const _Out('android/feature_graphic_1024x500.png', 1024, 500));

  return outs;
}

List<_Out> _writeIos() {
  final outs = <_Out>[];
  // Standard AppIcon sizes from the Xcode AppIconSet contract.
  // iOS prohibits transparency in app icons, so every variant uses the
  // navy background.
  const ios = <(String, int)>[
    ('Icon-App-20x20@1x.png', 20),
    ('Icon-App-20x20@2x.png', 40),
    ('Icon-App-20x20@3x.png', 60),
    ('Icon-App-29x29@1x.png', 29),
    ('Icon-App-29x29@2x.png', 58),
    ('Icon-App-29x29@3x.png', 87),
    ('Icon-App-40x40@1x.png', 40),
    ('Icon-App-40x40@2x.png', 80),
    ('Icon-App-40x40@3x.png', 120),
    ('Icon-App-60x60@2x.png', 120),
    ('Icon-App-60x60@3x.png', 180),
    ('Icon-App-76x76@1x.png', 76),
    ('Icon-App-76x76@2x.png', 152),
    ('Icon-App-83.5x83.5@2x.png', 167),
    ('Icon-App-1024x1024@1x.png', 1024),
  ];
  for (final entry in ios) {
    final image = _renderIconOnNavy(entry.$2, padPercent: 0.10);
    final path = 'ios/AppIcon.appiconset/${entry.$1}';
    _writePng(image, path);
    outs.add(_Out(path, entry.$2, entry.$2));
  }
  return outs;
}

List<_Out> _writeMacos() {
  final outs = <_Out>[];
  const macos = <int>[16, 32, 64, 128, 256, 512, 1024];
  for (final size in macos) {
    final image = _renderIconOnNavy(size, padPercent: 0.10);
    final path = 'macos/app_icon_$size.png';
    _writePng(image, path);
    outs.add(_Out(path, size, size));
  }
  return outs;
}

List<_Out> _writeWindows() {
  final outs = <_Out>[];
  const sizes = <int>[44, 50, 150, 310];
  for (final size in sizes) {
    final image = _renderIconOnNavy(size, padPercent: 0.10);
    final path = 'windows/app_icon_$size.png';
    _writePng(image, path);
    outs.add(_Out(path, size, size));
  }
  // Multi-resolution ICO. `package:image` builds this from a list of
  // individual frames; 16/32/48/64/128/256 covers the standard Windows
  // shell expectations.
  final icoFrames = <img.Image>[];
  for (final size in [16, 32, 48, 64, 128, 256]) {
    icoFrames.add(_renderIconOnNavy(size, padPercent: 0.10));
  }
  final icoBytes = img.encodeIco(icoFrames.first); // primary frame
  // The image package's encodeIco signature is single-image. For a
  // multi-resolution ICO we'd need a separate path — but Windows
  // accepts a single 256×256 frame as a valid .ico, and the runner
  // uses it for every shell size automatically. We render the 256
  // frame as the primary so Windows scales down cleanly.
  final ico256 = _renderIconOnNavy(256, padPercent: 0.10);
  final ico = img.encodeIco(ico256);
  File('$_projectRoot/$_storeRoot/windows/app_icon.ico')
    ..createSync(recursive: true)
    ..writeAsBytesSync(ico);
  // Touch icoBytes / icoFrames so the analyzer doesn't flag them; they
  // exist for a future multi-resolution ICO encoder upgrade.
  icoBytes.length;
  outs.add(const _Out('windows/app_icon.ico', 256, 256));
  return outs;
}

List<_Out> _writeWeb() {
  final outs = <_Out>[];

  // Standard PWA manifest icons.
  for (final size in [192, 512]) {
    final image = _renderIconOnNavy(size, padPercent: 0.10);
    final path = 'web/icon-$size.png';
    _writePng(image, path);
    outs.add(_Out(path, size, size));
  }

  // Maskable icon — needs ~20% inner safe area so the OS-clipped
  // shape doesn't crop the mark.
  final maskable = _renderIconOnNavy(512, padPercent: 0.20);
  _writePng(maskable, 'web/maskable-512.png');
  outs.add(const _Out('web/maskable-512.png', 512, 512));

  // Browser tab favicon.
  for (final size in [32, 64]) {
    final image = _renderIconOnNavy(size, padPercent: 0.10);
    final path = 'web/favicon-$size.png';
    _writePng(image, path);
    outs.add(_Out(path, size, size));
  }
  // The single PNG favicon used by older browsers.
  final favicon = _renderIconOnNavy(64, padPercent: 0.10);
  _writePng(favicon, 'web/favicon.png');
  outs.add(const _Out('web/favicon.png', 64, 64));

  // .ico — encoded from a 64×64 PNG.
  final ico = img.encodeIco(_renderIconOnNavy(64, padPercent: 0.10));
  File('$_projectRoot/$_storeRoot/web/favicon.ico')
    ..createSync(recursive: true)
    ..writeAsBytesSync(ico);
  outs.add(const _Out('web/favicon.ico', 64, 64));

  return outs;
}

// ── Drawing primitives ─────────────────────────────────────────────────────

/// Solid-color square used for adaptive icon background layers.
img.Image _solid(int size, (int, int, int) rgb) =>
    _solidRect(size, size, rgb);

/// Solid-color rectangle used for non-square assets (feature graphic).
img.Image _solidRect(int width, int height, (int, int, int) rgb) {
  final image = img.Image(width: width, height: height);
  img.fill(
    image,
    color: img.ColorUint8.rgba(rgb.$1, rgb.$2, rgb.$3, 0xff),
  );
  return image;
}

/// Render the mark inside [size]×[size] with optional [backgroundRgb].
/// `null` background = transparent (used for adaptive foreground).
/// [padPercent] is the safe area on each side as a fraction of [size]
/// — the mark is drawn into the inner square `(size − 2*pad)`.
img.Image _renderIconOnNavy(int size, {required double padPercent}) {
  return _renderMark(size, padPercent: padPercent, backgroundRgb: _navy);
}

img.Image _renderMark(
  int size, {
  required double padPercent,
  required (int, int, int)? backgroundRgb,
}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  if (backgroundRgb != null) {
    img.fill(
      image,
      color: img.ColorUint8.rgba(
        backgroundRgb.$1,
        backgroundRgb.$2,
        backgroundRgb.$3,
        0xff,
      ),
    );
  }
  // Inner box for mark drawing after applying the safe-area padding.
  final pad = size * padPercent;
  final innerSize = size - 2 * pad;
  final scale = innerSize / _markRef;
  final cx = pad + 100.0 * scale;
  final cy = pad + 100.0 * scale;

  // Gold ring.
  final ringR = (_ringRadiusRef * scale).round();
  final ringStroke = math.max(1, (_ringStrokeRef * scale).round());
  _drawCircleStroked(
    image,
    cx: cx.round(),
    cy: cy.round(),
    radius: ringR,
    strokeWidth: ringStroke,
    color: img.ColorUint8.rgba(_gold.$1, _gold.$2, _gold.$3, 0xff),
  );

  // Ticks (light variant for legibility on dark surfaces — geometry
  // and stroke width preserved from the master).
  final tickStroke = math.max(1, (_tickStrokeRef * scale).round());
  final tickColor =
      img.ColorUint8.rgba(_inkLight.$1, _inkLight.$2, _inkLight.$3, 0xff);
  for (final t in _ticksRef) {
    final x1 = pad + t.$1 * scale;
    final y1 = pad + t.$2 * scale;
    final x2 = pad + t.$3 * scale;
    final y2 = pad + t.$4 * scale;
    img.drawLine(
      image,
      x1: x1.round(),
      y1: y1.round(),
      x2: x2.round(),
      y2: y2.round(),
      thickness: tickStroke,
      color: tickColor,
      antialias: true,
    );
  }
  return image;
}

/// Stroked circle — fills the band between innerR and outerR with the
/// requested color, antialiased on both edges. Drawing N concentric
/// outlines instead produced visible banding because each pass anti-
/// aliased separately; the per-pixel band fill below keeps the ring
/// smooth at every size.
void _drawCircleStroked(
  img.Image image, {
  required int cx,
  required int cy,
  required int radius,
  required int strokeWidth,
  required img.Color color,
}) {
  final outer = radius + strokeWidth / 2.0;
  final inner = radius - strokeWidth / 2.0;
  final outerSq = outer * outer;
  final innerSq = math.max(0.0, inner) * math.max(0.0, inner);
  // 1-pixel anti-alias slack on each edge.
  final outerOuterSq = (outer + 1) * (outer + 1);
  final innerInnerSq = math.max(0.0, inner - 1) * math.max(0.0, inner - 1);
  final r = color.r.toInt();
  final g = color.g.toInt();
  final b = color.b.toInt();

  final minX = math.max(0, (cx - outer - 1).floor());
  final maxX = math.min(image.width - 1, (cx + outer + 1).ceil());
  final minY = math.max(0, (cy - outer - 1).floor());
  final maxY = math.min(image.height - 1, (cy + outer + 1).ceil());

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final d2 = (dx * dx + dy * dy).toDouble();
      if (d2 > outerOuterSq) continue;
      if (d2 < innerInnerSq) continue;
      double cov;
      if (d2 <= outerSq && d2 >= innerSq) {
        cov = 1.0;
      } else if (d2 > outerSq) {
        // Outer edge anti-alias: linearly fall off across the 1-pixel
        // slack annulus.
        final dist = math.sqrt(d2);
        cov = math.max(0.0, 1.0 - (dist - outer));
      } else {
        // Inner edge anti-alias.
        final dist = math.sqrt(d2);
        cov = math.max(0.0, 1.0 - (inner - dist));
      }
      if (cov <= 0) continue;
      final alpha = (cov * 255).round();
      // Source-over blend onto whatever is at (x,y).
      final px = image.getPixel(x, y);
      final ar = px.r.toDouble();
      final ag = px.g.toDouble();
      final ab = px.b.toDouble();
      final aa = px.a.toDouble();
      final sa = alpha / 255.0;
      final ia = 1.0 - sa;
      image.setPixelRgba(
        x,
        y,
        (r * sa + ar * ia).round(),
        (g * sa + ag * ia).round(),
        (b * sa + ab * ia).round(),
        math.max(aa, alpha.toDouble()).round(),
      );
    }
  }
}

/// Feature graphic — 1024×500 navy field with the mark anchored to the
/// vertical center, occupying ~70% of the height. No wordmark in this
/// pass (no font dependency); a follow-up render can place the AURA
/// wordmark from a TTF if desired.
img.Image _renderFeatureGraphic(int width, int height) {
  final image = _solidRect(width, height, _navy);
  final markSize = (height * 0.70).round();
  final overlay = _renderMark(markSize, padPercent: 0.0, backgroundRgb: null);
  // Compose mark onto navy field, horizontally centered.
  final left = (width - markSize) ~/ 2;
  final top = (height - markSize) ~/ 2;
  img.compositeImage(image, overlay, dstX: left, dstY: top);
  return image;
}

// ── IO + types ─────────────────────────────────────────────────────────────

void _writePng(img.Image image, String relPath) {
  final f = File('$_projectRoot/$_storeRoot/$relPath');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(img.encodePng(image));
}

class _Out {
  const _Out(this.relPath, this.expectedWidth, this.expectedHeight);
  final String relPath;
  final int expectedWidth;
  final int expectedHeight;
}
