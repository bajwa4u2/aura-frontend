import 'dart:io';

import 'package:aura/core/ui/aura_mark_on_dark.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mark's tick colours come from the master file, not from this code.
void main() {
  final svg = File('assets/brand/AURA_logo_master.svg').readAsStringSync();
  final ticks = RegExp(r'<g id="ticks"[^>]*>').firstMatch(svg)!.group(0)!;

  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  test('the light-surface tick colour is the master file\'s stroke', () {
    expect(ticks, contains('stroke="${hex(AuraMarkOnDark.lightSurfaceTick)}"'));
  });

  test('the on-dark tick colour is the master file\'s data-on-dark-stroke', () {
    expect(ticks,
        contains('data-on-dark-stroke="${hex(AuraMarkOnDark.onDarkTick)}"'));
  });

  test('on a dark surface only the ticks change colour', () {
    const m = AuraMarkOnDark();
    expect(m.substitute('ticks', 'g', 'stroke', AuraMarkOnDark.lightSurfaceTick),
        AuraMarkOnDark.onDarkTick);
    const gold = Color(0xFFC7A96B);
    expect(m.substitute('ring', 'circle', 'stroke', gold), gold);
  });
}
