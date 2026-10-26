import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// THE MARK ON A DARK SURFACE (2026-10-25).
///
/// The master SVG declares its ticks twice: `stroke` for a light surface and
/// `data-on-dark-stroke` for a dark one. The headers are dark, but they drew
/// the file as it stands, so the ticks came out #2E2E2E on near-black and
/// vanished: the mark read as a plain ring, "O AURA" (founder: "is it looks
/// well to you?"). Every dark surface now swaps in the file's own on-dark
/// value. test/brand/mark_on_dark_test.dart holds both values to the file.
class AuraMarkOnDark extends ColorMapper {
  const AuraMarkOnDark();

  /// The master's `stroke` on `#ticks`: the light-surface tick colour.
  static const Color lightSurfaceTick = Color(0xFF2E2E2E);

  /// The master's `data-on-dark-stroke` on `#ticks`.
  static const Color onDarkTick = Color(0xFFD8D8D8);

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) =>
      color == lightSurfaceTick ? onDarkTick : color;
}
