import 'package:flutter/material.dart';

import 'aura_surface.dart';

/// Aura typography tokens — full scale from display to micro.
class AuraText {
  AuraText._();

  /// Display — hero moments, landing page headlines only.
  static const TextStyle display = TextStyle(
    fontSize: 40,
    height: 1.08,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AuraSurface.ink,
  );

  /// Headline — section heroes, profile names, large card titles.
  static const TextStyle headline = TextStyle(
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AuraSurface.ink,
  );

  /// Title — page/section titles (unchanged from original).
  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: AuraSurface.ink,
  );

  /// Back-compat alias.
  static TextStyle get h1 => title;

  /// Subtitle — card titles, list section labels, secondary headings.
  static const TextStyle subtitle = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AuraSurface.ink,
  );

  /// Body — primary reading text.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AuraSurface.ink,
  );

  /// Muted — secondary body text.
  static const TextStyle muted = TextStyle(
    fontSize: 14,
    height: 1.55,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AuraSurface.muted,
  );

  /// Small — captions, meta lines, timestamps.
  static const TextStyle small = TextStyle(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AuraSurface.muted,
  );

  /// Emphasis — inline strong text used sparingly.
  static const TextStyle emphasis = TextStyle(
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    color: AuraSurface.ink,
  );

  /// Label — chip text, badge labels, eyebrow text, nav labels.
  static const TextStyle label = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AuraSurface.muted,
  );

  /// Micro — timestamps, legal, very small metadata.
  static const TextStyle micro = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AuraSurface.faint,
  );
}
