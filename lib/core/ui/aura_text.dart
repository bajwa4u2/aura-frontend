import 'package:flutter/material.dart';

import 'aura_surface.dart';

/// Aura typography tokens.
/// Keep this file dependency-light: only tokens, no widgets.
class AuraText {
  AuraText._();

  // Page / section titles
  // Stronger authority, slightly larger presence
  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: AuraSurface.ink,
  );

  // Primary body text
  // Increased line height for immersive reading
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AuraSurface.ink,
  );

  // Secondary / muted body text
  // Still readable on dark background
  static const TextStyle muted = TextStyle(
    fontSize: 14,
    height: 1.55,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AuraSurface.muted,
  );

  // Small helper text
  static const TextStyle small = TextStyle(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AuraSurface.muted,
  );

  // Emphasized inline text (use sparingly)
  static const TextStyle emphasis = TextStyle(
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    color: AuraSurface.ink,
  );
}