import 'package:flutter/material.dart';

import 'aura_surface.dart';

/// Aura typography tokens.
/// Keep this file dependency-light: only tokens, no widgets.
class AuraText {
  AuraText._();

  // Page / section titles
  static const TextStyle title = TextStyle(
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AuraSurface.ink,
  );

  // Primary body text
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AuraSurface.ink,
  );

  // Secondary / muted body text
  static const TextStyle muted = TextStyle(
    fontSize: 14,
    height: 1.40,
    fontWeight: FontWeight.w400,
    color: AuraSurface.muted,
  );

  // Small helper text
  static const TextStyle small = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AuraSurface.muted,
  );

  // Emphasized inline text (use sparingly)
  static const TextStyle emphasis = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: AuraSurface.ink,
  );
}
