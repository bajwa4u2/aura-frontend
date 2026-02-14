import 'package:flutter/material.dart';

/// Centralized surface + stroke tokens for Aura.
/// Keep this file boring and stable.
/// Everything UI should reference these instead of hard-coded colors.
class AuraSurface {
  AuraSurface._();

  /// App background (matches your Theme scaffoldBackgroundColor)
  static const Color page = Color(0xFFF7F5F2);

  /// Default card / paper surface
  static const Color card = Color(0xFFFFFFFF);

  /// Main text color (aligned with AuraText)
  static const Color ink = Color(0xFF1B1B1B);

  /// Muted text color
  static const Color muted = Color(0xFF6F6F6F);

  /// Borders, dividers, hairlines
  /// (matches your older 0x22000000 usage)
  static const Color divider = Color(0x22000000);

  /// Alias kept so older widgets don’t break.
  /// Prefer using `divider` going forward.
  static const Color cardBorder = divider;
}
