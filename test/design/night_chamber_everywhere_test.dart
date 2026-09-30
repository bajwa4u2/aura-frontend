import 'dart:io';

import 'package:aura/core/ui/aura_chamber.dart';
import 'package:aura/core/ui/aura_surface.dart';
import 'package:aura/core/ui/aura_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// ONE LOOK, EVERYWHERE (founder, 2026-09-30: "night chamber only", "do at
/// once"). Signed-in Aura wears the Night Chamber the public front door wears.
/// The old navy grounds and indigo accent must not come back, in a token or in
/// a colour typed straight into a screen.
void main() {
  test('the surface tokens are the chamber', () {
    expect(AuraSurface.page, AuraChamber.ink);
    expect(AuraSurface.card, AuraChamber.raised);
    expect(AuraSurface.divider, AuraChamber.rule);
    expect(AuraSurface.ink, AuraChamber.text);
    expect(AuraSurface.muted, AuraChamber.muted);
    expect(AuraSurface.accent, AuraChamber.gold);
    expect(AuraSurface.onAccent, AuraChamber.ink);
  });

  test('headings speak in the serif, everything else in the sans', () {
    expect(AuraText.display.fontFamily, AuraChamber.serif);
    expect(AuraText.headline.fontFamily, AuraChamber.serif);
    expect(AuraText.title.fontFamily, AuraChamber.serif);
    expect(AuraText.body.fontFamily, AuraChamber.sans);
    expect(AuraText.label.fontFamily, AuraChamber.sans);
  });

  test('no screen types the old navy or indigo', () {
    const retired = {
      // indigo / violet accents
      '5B6CFF', '6C63FF', '8B85FF', '8B9EFF', '7A4DFF',
      // navy / slate grounds
      '0D1520', '111D2E', '152438', '1B2E44', '203454', '0F172A', '1E293B',
      '111827', '1F2937',
      '13202F', '0B1220', '091820', '152030',
      // cool text
      'E2ECF5', '7A96B5', '4B6882',
    };
    final pattern = RegExp(r'0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})\b');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in pattern.allMatches(lines[i])) {
          if (retired.contains(m.group(1)!.toUpperCase())) {
            offenders.add('${entity.path}:${i + 1} ${m.group(0)}');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Night Chamber only: use AuraSurface / AuraChamber tokens.');
  });
}
