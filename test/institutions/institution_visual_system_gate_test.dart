// INSTITUTION SURFACES BELONG TO AURA'S VISUAL SYSTEM.
//
// The founder's observation was that some institution screens feel as though
// another product had been imported: functionally right, structurally right,
// and speaking a slightly different visual language. That is not something a
// screenshot review reliably catches, because each individual value looks
// deliberate. What it looked like in the source:
//
//   * Two of the three status tones had a ground in one hue and their text in
//     another. A warning chip was `coSun` amber text on #F59E0B amber; an
//     error chip was `coRose` on #EF4444.
//   * Nine occurrences of #0D9488 written out longhand, which IS `coTeal` --
//     a second definition of a colour Aura already names.
//   * Five semantic hues chosen locally: pending orange, resolved green,
//     update violet, and a SECOND resolved green in a different file. One
//     meaning, two colours, is the clearest evidence a palette has stopped
//     being one thing.
//   * Corner radii of 20 and 9, which are not Aura radii, on cards sitting
//     beside cards that are.
//
// This gate does not enforce taste and it does not forbid
// institution-specific meaning. It forbids a SECOND AUTHORITY: a colour or a
// corner defined inside institution code when Aura already defines it.
//
// Deliberately NOT covered, because they are legitimate:
//   * `Colors.transparent` / `Colors.white` / `Colors.black` for scrims,
//     overlays and ink on photography.
//   * A light teal derived from `coTeal` for legible text on a teal field:
//     Aura defines no light-teal ink, so the need is real. What matters is
//     that it derives rather than standing alone.
//   * `InsSpacing.contentMaxWidth`, which is one authority already, and which
//     is composition rather than visual language. Composition is frozen.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Aura colour token's literal value, so the gate can tell a genuinely
/// institution-specific colour from a redefinition of one Aura already names.
Map<String, String> _auraColourLiterals() {
  final src = File('lib/core/ui/aura_surface.dart').readAsStringSync();
  final out = <String, String>{};
  final re = RegExp(
    r'static const Color (\w+) = Color\((0x[0-9A-Fa-f]{8})\)',
  );
  for (final m in re.allMatches(src)) {
    out[m.group(2)!.toUpperCase()] = m.group(1)!;
  }
  return out;
}

List<File> _institutionSources() => Directory('lib/features/institutions')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  test('no institution file redefines a colour Aura already names', () {
    final aura = _auraColourLiterals();
    expect(aura, isNotEmpty, reason: 'could not read the Aura colour tokens');

    final offenders = <String>[];
    final re = RegExp(r'Color\((0x[0-9A-Fa-f]{8})\)');

    for (final f in _institutionSources()) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        final literal = m.group(1)!.toUpperCase();
        final token = aura[literal];
        if (token != null) {
          offenders.add(
            '${f.path.replaceAll(r'\', '/')}: Color($literal) is '
            'AuraSurface.$token',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'A colour Aura already names must be referenced by its token, '
          'not written out again. Two definitions of one colour is how a '
          'palette drifts:\n  ${offenders.join('\n  ')}',
    );
  });

  test('institution corners come from the Aura radius scale', () {
    final radii = RegExp(r'static const double r(\d+)')
        .allMatches(File('lib/core/ui/aura_radius.dart').readAsStringSync())
        .map((m) => int.parse(m.group(1)!))
        .toSet();
    expect(radii, isNotEmpty);

    // Small values are hairlines, indicator dots and inner clips rather than
    // the corner language of a card, and the scale does not speak about them.
    const hairline = 8;

    final offenders = <String>[];
    final re = RegExp(r'BorderRadius\.circular\((\d+)\)');

    for (final f in _institutionSources()) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        final value = int.parse(m.group(1)!);
        if (value <= hairline) continue;
        if (!radii.contains(value)) {
          offenders.add(
            '${f.path.replaceAll(r'\', '/')}: circular($value)',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'A corner that is not on the Aura scale reads as a card from '
          'another product sitting beside Aura cards:\n  '
          '${offenders.join('\n  ')}',
    );
  });

  test('status tone grounds derive from the ink they carry', () {
    // The specific defect: a chip whose ground and text were different hues.
    // Deriving both from one token is what makes that impossible, so the gate
    // asserts the derivation rather than the resulting colour.
    final src =
        File('lib/features/institutions/ui/institution_ds.dart').readAsStringSync();

    for (final token in const ['coVerdant', 'coSun', 'coRose']) {
      expect(
        src,
        contains('bg: AuraSurface.$token.withValues('),
        reason: '$token tone must ground itself in its own ink',
      );
      expect(
        src,
        contains('border: AuraSurface.$token.withValues('),
        reason: '$token tone must border itself in its own ink',
      );
    }
  });
}
