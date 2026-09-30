import 'package:flutter/material.dart';

import 'aura_surface.dart';

/// Night Chamber has no gradients (2026-09-30): every one of these is a
/// flat token, kept so existing call sites need no change.
class AuraGradients {
  AuraGradients._();

  /// Full-page background.
  static const LinearGradient page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AuraSurface.page,
      AuraSurface.page,
    ],
  );

  /// Shell headers.
  static const LinearGradient header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AuraSurface.page,
      AuraSurface.page,
    ],
  );

  /// Accent — icons, badges, FABs.
  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AuraSurface.accent,
      AuraSurface.accent,
    ],
  );

  /// Card interior.
  static const LinearGradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AuraSurface.card,
      AuraSurface.card,
    ],
  );

  /// Hero — full-width sections.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AuraSurface.page,
      AuraSurface.page,
    ],
  );

  /// Side nav background.
  static const LinearGradient sideNav = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AuraSurface.page,
      AuraSurface.page,
    ],
  );

  /// Bottom nav background.
  static const LinearGradient bottomNav = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AuraSurface.card,
      AuraSurface.card,
    ],
  );

  /// Footer background.
  static const LinearGradient footer = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AuraSurface.page,
      AuraSurface.page,
    ],
  );
}

class AuraShadows {
  AuraShadows._();

  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x00000000),
      blurRadius: 32,
      offset: Offset(0, 12),
      spreadRadius: -4,
    ),
  ];

  static const List<BoxShadow> panel = [
    BoxShadow(
      color: Color(0x3A000000),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x28000000),
      blurRadius: 16,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
  ];
}

class AuraMotion {
  AuraMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);
}

class AuraIconSize {
  AuraIconSize._();

  static const double xs = 14;
  static const double sm = 16;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
}
