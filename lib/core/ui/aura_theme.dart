import 'package:flutter/material.dart';

/// Aura Design System v1 (Locked)
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
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;

  static BorderRadius r(double v) => BorderRadius.circular(v);
  static BorderRadius get card => BorderRadius.circular(xl);
}

class AuraSurface {
  /// Page background (already aligned with your app theme)
  static const Color page = Color(0xFFF7F5F2);

  /// Subtle “ink wash” panel background
  static const Color panel = Color(0xFFF2EFEA);

  /// Soft frame border (barely there)
  static const Color frame = Color(0x1A000000);

  /// Default foreground (ink)
  static const Color ink = Color(0xFF1B1B1B);

  /// Muted text
  static const Color muted = Color(0xFF6B6B6B);
}

class AuraText {
  /// AppBar titles and major screen headings
  static const TextStyle title = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 0,
    color: AuraSurface.ink,
  );

  /// Section headers inside screens
  static const TextStyle section = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0,
    color: AuraSurface.ink,
  );

  /// Default body text
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.5,
    letterSpacing: 0,
    color: AuraSurface.ink,
  );

  /// Muted helper text
  static const TextStyle muted = TextStyle(
    fontSize: 14,
    height: 1.45,
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
