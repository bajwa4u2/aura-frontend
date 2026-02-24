import 'package:flutter/material.dart';

/// Aura Design System v2 (Dark Cinematic)
/// Single source of truth for spacing, radius, surfaces, and typography.
/// Screens should NOT hardcode padding/radius/borders/text styles.
/// Use AuraSpace / AuraRadius / AuraSurface / AuraText.

class AuraSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Default screen padding (locked)
  static const EdgeInsets screen = EdgeInsets.fromLTRB(md, sm, md, xl);

  /// Default card padding (locked)
  static const EdgeInsets card = EdgeInsets.all(md);
}

class AuraRadius {
  // Slightly tighter radii for architectural feel
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;

  static BorderRadius r(double v) => BorderRadius.circular(v);

  /// Cards feel structured, not playful
  static BorderRadius get card => BorderRadius.circular(lg);
}

class AuraSurface {
  /// Deep graphite base (not pure black)
  static const Color page = Color(0xFF121418);

  /// Primary content surface (lifted from background)
  static const Color panel = Color(0xFF1A1E24);

  /// Elevated surface (dialogs / overlays / emphasis panels)
  static const Color elevated = Color(0xFF222833);

  /// Subtle separation frame (barely visible edge light)
  static const Color frame = Color(0x1FFFFFFF);

  /// Primary readable foreground
  static const Color ink = Color(0xFFE8EAED);

  /// Muted text (still readable on dark)
  static const Color muted = Color(0xFF9AA3AF);

  /// Signature accent (restrained indigo energy)
  static const Color accent = Color(0xFF5B6CFF);

  /// Soft accent glow (hover / active states)
  static const Color accentSoft = Color(0x335B6CFF);
}

class AuraText {
  /// AppBar titles and major screen headings
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: 0,
    color: AuraSurface.ink,
  );

  /// Section headers inside screens
  static const TextStyle section = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0,
    color: AuraSurface.ink,
  );

  /// Default body text (comfortable reading rhythm)
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.6,
    letterSpacing: 0,
    color: AuraSurface.ink,
  );

  /// Muted helper / metadata text
  static const TextStyle muted = TextStyle(
    fontSize: 13,
    height: 1.5,
    letterSpacing: 0,
    color: AuraSurface.muted,
  );
}

/// Card styling variants.
/// Keep the options minimal so the system stays coherent.
enum AuraCardVariant {
  normal,
  panel,
}