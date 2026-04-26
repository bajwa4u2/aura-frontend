import 'package:flutter/material.dart';

import 'aura_surface.dart';

class AuraGradients {
  AuraGradients._();

  static const LinearGradient page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0B0D12),
      AuraSurface.page,
      Color(0xFF11151C),
    ],
  );

  static const LinearGradient header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF111521),
      Color(0xFF171C2B),
      Color(0xFF1A1E24),
    ],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF5B6CFF),
      Color(0xFF7A4DFF),
    ],
  );

  static const LinearGradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1B2028),
      Color(0xFF161A21),
    ],
  );
}

class AuraShadows {
  AuraShadows._();

  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x225B6CFF),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> panel = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 22,
      offset: Offset(0, 10),
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

