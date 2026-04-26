import 'package:flutter/material.dart';

import 'aura_surface.dart';

class AuraGradients {
  AuraGradients._();

  /// Full-page background — very subtle navy sweep.
  static const LinearGradient page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0A1220),
      AuraSurface.page,
      Color(0xFF0F1C2C),
    ],
  );

  /// Header gradient — premium navy diagonal used in shell headers.
  static const LinearGradient header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0E1828),
      Color(0xFF132030),
      Color(0xFF152438),
    ],
  );

  /// Accent — indigo to violet for icons, badges, FABs.
  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF5B6CFF),
      Color(0xFF7A4DFF),
    ],
  );

  /// Card interior — subtle navy depth gradient.
  static const LinearGradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF192C42),
      Color(0xFF122034),
    ],
  );

  /// Hero — rich navy sweep for full-width landing sections.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A1428),
      Color(0xFF0F2040),
      Color(0xFF163058),
    ],
  );

  /// Side nav background.
  static const LinearGradient sideNav = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0C1828),
      Color(0xFF0A1420),
    ],
  );

  /// Bottom nav background.
  static const LinearGradient bottomNav = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF152438),
      Color(0xFF101E30),
    ],
  );

  /// Footer background.
  static const LinearGradient footer = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0C1828),
      Color(0xFF090F1C),
    ],
  );
}

class AuraShadows {
  AuraShadows._();

  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x2A5B6CFF),
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
